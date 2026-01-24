import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import Stripe from 'https://esm.sh/stripe@17.4.0?target=deno&no-check'

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
    const event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret)

    // Use service role key for server-side operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

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
          .from('user_profiles')
          .update({
            stripe_subscription_id: subscription.id,
            subscription_status: subscription.status,
            subscription_tier: tier,
            billing_plan: tier, // Update billing_plan to match subscription tier
            subscription_current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
          })
          .eq('id', userId)

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
          .from('user_profiles')
          .update({
            stripe_subscription_id: null,
            subscription_status: 'canceled',
            subscription_tier: null,
            billing_plan: 'free', // Reset billing plan to free when subscription is canceled
            subscription_current_period_end: null,
          })
          .eq('id', userId)

        break
      }

      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice
        const subscriptionId = invoice.subscription as string
        const customerId = invoice.customer as string

        if (!subscriptionId) break

        // Get user_id from profile
        const { data: profile } = await supabaseAdmin
          .from('user_profiles')
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

        break
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice
        const subscriptionId = invoice.subscription as string
        const customerId = invoice.customer as string

        if (!subscriptionId) break

        // Get user_id from profile
        const { data: profile } = await supabaseAdmin
          .from('user_profiles')
          .select('id, stripe_subscription_id')
          .eq('stripe_customer_id', customerId)
          .single()

        if (!profile || profile.stripe_subscription_id !== subscriptionId) {
          console.error('Could not find matching profile for failed invoice')
          break
        }

        // Update subscription status to past_due
        await supabaseAdmin
          .from('user_profiles')
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

        break
      }

      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent
        const customerId = paymentIntent.customer as string
        const userId = paymentIntent.metadata?.user_id

        // Get user_id from metadata or lookup by customer
        let profileId = userId
        if (!profileId && customerId) {
          const { data: profile } = await supabaseAdmin
            .from('user_profiles')
            .select('id')
            .eq('stripe_customer_id', customerId)
            .single()
          profileId = profile?.id
        }

        if (!profileId) {
          console.error('Could not find user for payment intent:', paymentIntent.id)
          break
        }

        // Create transaction record
        await supabaseAdmin.from('transactions').insert({
          user_id: profileId,
          transaction_type: paymentIntent.metadata?.transaction_type || 'payment',
          amount_cents: paymentIntent.amount,
          currency: paymentIntent.currency,
          status: 'succeeded',
          stripe_payment_intent_id: paymentIntent.id,
          stripe_subscription_id: paymentIntent.metadata?.subscription_id || null,
          metadata: {
            payment_method: paymentIntent.payment_method,
            description: paymentIntent.description,
          },
        })

        break
      }

      case 'payment_intent.payment_failed': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent
        const customerId = paymentIntent.customer as string
        const userId = paymentIntent.metadata?.user_id

        // Get user_id from metadata or lookup by customer
        let profileId = userId
        if (!profileId && customerId) {
          const { data: profile } = await supabaseAdmin
            .from('user_profiles')
            .select('id')
            .eq('stripe_customer_id', customerId)
            .single()
          profileId = profile?.id
        }

        if (!profileId) {
          console.error('Could not find user for failed payment intent:', paymentIntent.id)
          break
        }

        // If this is tied to a subscription, update status to past_due
        if (paymentIntent.metadata?.subscription_id) {
          await supabaseAdmin
            .from('user_profiles')
            .update({ subscription_status: 'past_due' })
            .eq('id', profileId)
        }

        // Create failed transaction record
        await supabaseAdmin.from('transactions').insert({
          user_id: profileId,
          transaction_type: paymentIntent.metadata?.transaction_type || 'payment',
          amount_cents: paymentIntent.amount,
          currency: paymentIntent.currency,
          status: 'failed',
          stripe_payment_intent_id: paymentIntent.id,
          metadata: {
            error_message: paymentIntent.last_payment_error?.message,
            error_code: paymentIntent.last_payment_error?.code,
          },
        })

        break
      }
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
