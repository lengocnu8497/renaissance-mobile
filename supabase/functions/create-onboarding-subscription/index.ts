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
  tier: 'weekly' | 'monthly' | 'yearly'
}

function resolvePriceIdForTier(tier: 'weekly' | 'monthly' | 'yearly'): string | null {
  switch (tier) {
    case 'weekly':
      return Deno.env.get('STRIPE_PRICE_WEEKLY') ?? Deno.env.get('STRIPE_PRICE_SILVER')
    case 'monthly':
      return Deno.env.get('STRIPE_PRICE_MONTHLY') ?? Deno.env.get('STRIPE_PRICE_GOLD')
    case 'yearly':
      return Deno.env.get('STRIPE_PRICE_YEARLY') ?? Deno.env.get('STRIPE_PRICE_ANNUAL')
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, tier }: CreateOnboardingSubscriptionRequest = await req.json()

    if (!email || !tier) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email, tier' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const priceId = resolvePriceIdForTier(tier)
    if (!priceId) {
      return new Response(
        JSON.stringify({ error: 'Stripe price is not configured for this tier' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch price details to return display info
    const price = await stripe.prices.retrieve(priceId)

    // Derive tier from price interval / amount so link-onboarding-subscription
    // can write the correct tier to user_profiles without needing price IDs.
    const interval = price.recurring?.interval
    const resolvedTier: string = interval === 'year'  ? 'yearly'
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
        tier: resolvedTier,
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
