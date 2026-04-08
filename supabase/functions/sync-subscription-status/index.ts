import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SyncSubscriptionRequest {
  isActive: boolean
  tier?: 'weekly' | 'monthly' | 'yearly'
  status?: 'active' | 'canceled' | 'past_due'
  productId?: string
  transactionId?: string
  originalTransactionId?: string
  expirationDate?: string
  environment?: 'sandbox' | 'production' | 'xcode'
  signedTransactionInfo?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization') ?? '' },
        },
      }
    )

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const token = req.headers.get('Authorization')?.replace('Bearer ', '')
    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const { data: { user }, error: authError } = await authClient.auth.getUser(token)
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized', details: authError?.message }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const body: SyncSubscriptionRequest = await req.json()
    const { data: currentProfile, error: profileFetchError } = await adminClient
      .from('user_profiles')
      .select('subscription_provider')
      .eq('id', user.id)
      .single()

    if (profileFetchError) {
      throw profileFetchError
    }

    if (body.isActive) {
      if (!body.tier || !body.productId || !body.transactionId || !body.originalTransactionId) {
        return new Response(
          JSON.stringify({ error: 'Missing required fields for active subscription sync' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
      }

      const profileUpdate = {
        billing_plan: body.tier,
        subscription_status: body.status ?? 'active',
        subscription_tier: body.tier,
        subscription_current_period_end: body.expirationDate ?? null,
        subscription_provider: 'app_store',
        subscription_id: body.originalTransactionId,
        app_store_product_id: body.productId,
        app_store_original_transaction_id: body.originalTransactionId,
        app_store_environment: body.environment ?? null,
      }

      const { error: updateError } = await adminClient
        .from('user_profiles')
        .update(profileUpdate)
        .eq('id', user.id)

      if (updateError) {
        throw updateError
      }

      const transactionRecord = {
        id: body.transactionId,
        user_id: user.id,
        transaction_type: 'subscription',
        amount_cents: 0,
        currency: 'USD',
        status: 'succeeded',
        payment_provider: 'app_store',
        subscription_id: body.originalTransactionId,
        store_transaction_id: body.transactionId,
        original_transaction_id: body.originalTransactionId,
        metadata: {
          product_id: body.productId,
          app_store_environment: body.environment ?? null,
          signed_transaction_info: body.signedTransactionInfo ?? null,
        },
      }

      const { error: transactionError } = await adminClient
        .from('transactions')
        .upsert(transactionRecord, { onConflict: 'id' })

      if (transactionError) {
        throw transactionError
      }
    } else if (currentProfile?.subscription_provider === 'app_store') {
      const { error: clearError } = await adminClient
        .from('user_profiles')
        .update({
          billing_plan: 'free',
          subscription_status: 'canceled',
          subscription_tier: null,
          subscription_current_period_end: null,
          subscription_provider: 'app_store',
          subscription_id: null,
          app_store_product_id: null,
          app_store_original_transaction_id: null,
          app_store_environment: null,
        })
        .eq('id', user.id)

      if (clearError) {
        throw clearError
      }
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('sync-subscription-status error:', error)

    return new Response(
      JSON.stringify({ error: error.message ?? 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
