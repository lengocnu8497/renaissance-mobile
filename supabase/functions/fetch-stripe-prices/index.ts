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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { tiers }: { tiers: Array<'weekly' | 'monthly' | 'yearly'> } = await req.json()

    if (!tiers || tiers.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: tiers' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const priceIdForTier = (tier: 'weekly' | 'monthly' | 'yearly') => {
      switch (tier) {
        case 'weekly':
          return Deno.env.get('STRIPE_PRICE_WEEKLY') ?? Deno.env.get('STRIPE_PRICE_SILVER')
        case 'monthly':
          return Deno.env.get('STRIPE_PRICE_MONTHLY') ?? Deno.env.get('STRIPE_PRICE_GOLD')
        case 'yearly':
          return Deno.env.get('STRIPE_PRICE_YEARLY') ?? Deno.env.get('STRIPE_PRICE_ANNUAL')
      }
    }

    const results = await Promise.all(
      tiers.map(async (tier) => {
        const priceId = priceIdForTier(tier)
        if (!priceId) {
          throw new Error(`Stripe price not configured for tier: ${tier}`)
        }

        const price = await stripe.prices.retrieve(priceId)
        const dollars = (price.unit_amount ?? 0) / 100
        const interval = price.recurring?.interval
        const intervalCount = price.recurring?.interval_count ?? 1

        let displayPrice: string
        if (interval) {
          const intervalLabel = intervalCount > 1
            ? `${intervalCount} ${interval}s`
            : interval
          displayPrice = `$${dollars.toFixed(2)} / ${intervalLabel}`
        } else {
          displayPrice = `$${dollars.toFixed(2)}`
        }

        return {
          tier,
          priceId,
          unitAmount: price.unit_amount ?? 0,
          currency: price.currency,
          interval: interval ?? null,
          intervalCount,
          displayPrice,
        }
      })
    )

    return new Response(
      JSON.stringify(results),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error fetching Stripe prices:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
