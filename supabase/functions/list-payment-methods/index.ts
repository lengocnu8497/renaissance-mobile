import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
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
    // 1. Authenticate the requesting user via their JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Look up the stripe_customer_id server-side using the authenticated user.id.
    //    The client never supplies the customer ID — this prevents any spoofing.
    const { data: profile, error: profileError } = await supabaseClient
      .from('user_profiles')
      .select('stripe_customer_id')
      .eq('id', user.id)
      .single()

    if (profileError) {
      console.error('Profile fetch error:', profileError.message)
      return new Response(
        JSON.stringify({ error: 'Failed to load account data' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // No Stripe customer yet means no saved payment methods — not an error
    if (!profile?.stripe_customer_id) {
      return new Response(
        JSON.stringify({ paymentMethods: [] }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const customerId = profile.stripe_customer_id

    // 3. Fetch payment methods and customer default in parallel
    const [pmResponse, customer] = await Promise.all([
      stripe.paymentMethods.list({ customer: customerId, type: 'card' }),
      stripe.customers.retrieve(customerId),
    ])

    const defaultPmId =
      (customer as Stripe.Customer).invoice_settings?.default_payment_method as string | null

    // 4. Return only the minimal fields the UI needs.
    //    No billing address, fingerprint, or raw PM ID to limit exposure.
    const paymentMethods = pmResponse.data.map((pm) => {
      const card = pm.card!
      const expMonth = String(card.exp_month).padStart(2, '0')
      const expYear = String(card.exp_year).slice(-2)
      // Capitalise brand name: "visa" → "Visa", "mastercard" → "Mastercard"
      const brand = card.brand.charAt(0).toUpperCase() + card.brand.slice(1)

      return {
        brand,
        last4: card.last4,
        expiryDate: `${expMonth}/${expYear}`,
        isDefault: pm.id === defaultPmId,
      }
    })

    return new Response(
      JSON.stringify({ paymentMethods }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    // Log the real error server-side; send a generic message to the client
    console.error('list-payment-methods error:', error)
    return new Response(
      JSON.stringify({ error: 'An unexpected error occurred' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
