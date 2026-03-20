import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@17.4.0?target=deno&no-check'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY_DEV') || '', {
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
    const { priceIds }: { priceIds: string[] } = await req.json()

    if (!priceIds || priceIds.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: priceIds' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const results = await Promise.all(
      priceIds.map(async (priceId) => {
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
