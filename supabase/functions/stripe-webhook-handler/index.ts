import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import Stripe from 'https://esm.sh/stripe@14.10.0?target=deno'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY_DEV') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET_DEV')!

serve(async (req) => {
  const signature = req.headers.get('stripe-signature')

  if (!signature) {
    return new Response(JSON.stringify({ error: 'No signature' }), { status: 400 })
  }

  try {
    const body = await req.text()
    const event = stripe.webhooks.constructEvent(body, signature, webhookSecret)

    // Use service role key for server-side operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    console.log('Processing webhook event:', event.type)

    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription
        const userId = subscription.metadata.user_id
        const tier = subscription.metadata.tier

        if (!userId) {
          console.error('No user_id in subscription metadata')
          break
        }

        // Update profile with subscription info
        await supabaseAdmin
          .from('profiles')
          .update({
            stripe_subscription_id: subscription.id,
            subscription_status: subscription.status,
            subscription_tier: tier,
            subscription_current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
          })
          .eq('id', userId)

        console.log(`Updated subscription for user ${userId}`)
        break
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription
        const userId = subscription.metadata.user_id

        if (!userId) {
          console.error('No user_id in subscription metadata')
          break
        }

        // Clear subscription info
        await supabaseAdmin
          .from('profiles')
          .update({
            stripe_subscription_id: null,
            subscription_status: 'canceled',
            subscription_tier: null,
            subscription_current_period_end: null,
          })
          .eq('id', userId)

        console.log(`Canceled subscription for user ${userId}`)
        break
      }

      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice
        const subscriptionId = invoice.subscription as string
        const customerId = invoice.customer as string

        if (!subscriptionId) break

        // Get user_id from profile
        const { data: profile } = await supabaseAdmin
          .from('profiles')
          .select('id, stripe_subscription_id')
          .eq('stripe_customer_id', customerId)
          .single()

        if (!profile || profile.stripe_subscription_id !== subscriptionId) {
          console.error('Could not find matching profile for invoice')
          break
        }

        // Create transaction record
        await supabaseAdmin.from('transactions').insert({
          user_id: profile.id,
          transaction_type: 'subscription',
          amount_cents: invoice.amount_paid,
          currency: invoice.currency,
          status: 'succeeded',
          stripe_payment_intent_id: invoice.payment_intent as string,
          stripe_subscription_id: subscriptionId,
          stripe_invoice_id: invoice.id,
          metadata: {
            billing_reason: invoice.billing_reason,
            period_start: invoice.period_start,
            period_end: invoice.period_end,
          },
        })

        console.log(`Created transaction for successful payment: ${invoice.id}`)
        break
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice
        const subscriptionId = invoice.subscription as string
        const customerId = invoice.customer as string

        if (!subscriptionId) break

        // Get user_id from profile
        const { data: profile } = await supabaseAdmin
          .from('profiles')
          .select('id, stripe_subscription_id')
          .eq('stripe_customer_id', customerId)
          .single()

        if (!profile || profile.stripe_subscription_id !== subscriptionId) {
          console.error('Could not find matching profile for failed invoice')
          break
        }

        // Update subscription status to past_due
        await supabaseAdmin
          .from('profiles')
          .update({ subscription_status: 'past_due' })
          .eq('id', profile.id)

        // Create failed transaction record
        await supabaseAdmin.from('transactions').insert({
          user_id: profile.id,
          transaction_type: 'subscription',
          amount_cents: invoice.amount_due,
          currency: invoice.currency,
          status: 'failed',
          stripe_invoice_id: invoice.id,
          stripe_subscription_id: subscriptionId,
          metadata: {
            billing_reason: invoice.billing_reason,
            attempt_count: invoice.attempt_count,
            next_payment_attempt: invoice.next_payment_attempt,
          },
        })

        console.log(`Recorded failed payment for invoice: ${invoice.id}`)
        break
      }

      default:
        console.log(`Unhandled event type: ${event.type}`)
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 })
  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400 }
    )
  }
})
