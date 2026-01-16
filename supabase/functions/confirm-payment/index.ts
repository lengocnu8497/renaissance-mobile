import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import Stripe from 'https://esm.sh/stripe@14.10.0?target=deno'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY_DEV') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Authenticate user
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { confirmation_token, amount_cents, currency, metadata } = await req.json()

    if (!confirmation_token) {
      return new Response(
        JSON.stringify({ error: 'Missing confirmation_token' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!amount_cents || !currency) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters: amount_cents and currency' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('Processing payment confirmation for user:', user.id)
    console.log('Confirmation token:', confirmation_token)
    console.log('Amount:', amount_cents, 'Currency:', currency)

    // Get or create Stripe customer
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('stripe_customer_id, email')
      .eq('id', user.id)
      .single()

    let customerId = profile?.stripe_customer_id

    if (!customerId) {
      console.log('Creating new Stripe customer for user:', user.id)
      // Create new Stripe customer
      const customer = await stripe.customers.create({
        email: profile?.email || user.email,
        metadata: {
          supabase_user_id: user.id,
        },
      })
      customerId = customer.id

      // Save customer ID to profile
      await supabaseClient
        .from('profiles')
        .update({ stripe_customer_id: customerId })
        .eq('id', user.id)

      console.log('Created Stripe customer:', customerId)
    }

    // Create Payment Intent with the confirmation token
    const paymentIntent = await stripe.paymentIntents.create({
      customer: customerId,
      amount: amount_cents,
      currency: currency.toLowerCase(),
      confirm: true,
      confirmation_token: confirmation_token,
      return_url: 'renaissance://payment-complete',
      metadata: {
        user_id: user.id,
        ...metadata,
      },
    })

    console.log('Payment Intent created:', paymentIntent.id, 'Status:', paymentIntent.status)

    // Optional: Log transaction in database
    try {
      await supabaseClient
        .from('transactions')
        .insert({
          user_id: user.id,
          transaction_type: metadata?.transaction_type || 'booking',
          stripe_payment_intent_id: paymentIntent.id,
          amount_cents: paymentIntent.amount,
          currency: paymentIntent.currency,
          status: paymentIntent.status === 'succeeded' ? 'succeeded' : 'pending',
          metadata: metadata || {},
        })
    } catch (error) {
      console.error('Failed to log transaction:', error)
      // Don't fail the payment if transaction logging fails
    }

    return new Response(
      JSON.stringify({
        payment_intent_id: paymentIntent.id,
        status: paymentIntent.status,
        client_secret: paymentIntent.client_secret,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error: any) {
    console.error('Error in confirm-payment:', error)

    // Handle specific Stripe errors
    if (error.type === 'StripeCardError') {
      return new Response(
        JSON.stringify({
          error: 'Card error',
          message: error.message
        }),
        { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        error: 'Payment confirmation failed',
        message: error.message
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
