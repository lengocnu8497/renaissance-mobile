import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@17.4.0?target=deno&no-check'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateOnboardingSubscriptionRequest {
  email: string
  priceId: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, priceId }: CreateOnboardingSubscriptionRequest = await req.json()

    if (!email || !priceId) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email, priceId' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch price details to return display info
    const price = await stripe.prices.retrieve(priceId)

    // Derive tier from price interval / amount so link-onboarding-subscription
    // can write the correct tier to user_profiles without needing price IDs.
    const interval = price.recurring?.interval
    const tier: string = interval === 'year'  ? 'yearly'
                       : interval === 'week'  ? 'weekly'
                       : 'monthly'

    // Get or create Stripe customer by email
    const existingCustomers = await stripe.customers.list({ email, limit: 1 })
    let customerId: string

    if (existingCustomers.data.length > 0) {
      customerId = existingCustomers.data[0].id
    } else {
      const customer = await stripe.customers.create({
        email,
        metadata: { source: 'onboarding' },
      })
      customerId = customer.id
    }

    // Create subscription
    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: priceId }],
      payment_behavior: 'default_incomplete',
      payment_settings: {
        payment_method_types: ['card'],
        save_default_payment_method: 'on_subscription',
      },
      expand: ['latest_invoice.payment_intent'],
      metadata: {
        email,
        source: 'onboarding',
        tier,
      },
    })

    const invoice = subscription.latest_invoice as Stripe.Invoice
    const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent

    return new Response(
      JSON.stringify({
        subscriptionId: subscription.id,
        clientSecret: paymentIntent.client_secret,
        customerId,
        unitAmount: price.unit_amount,
        currency: price.currency,
        interval: price.recurring?.interval || 'month',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error creating onboarding subscription:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
