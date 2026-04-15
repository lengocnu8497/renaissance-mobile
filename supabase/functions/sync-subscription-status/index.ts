import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import {
  AppStoreSignedTransactionVerificationError,
  decodeSignedTransactionPayload,
  fetchAuthoritativeSubscriptionLookup,
  normalizeEnvironment,
  stringifyNumericIdentifier,
} from './appStoreAuthoritativeLookup.ts'
import { applyVerifiedAppStoreTransaction } from '../_shared/appStoreSubscriptionPersistence.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SyncSubscriptionRequest {
  isActive: boolean
  productId?: string
  transactionId?: string
  originalTransactionId?: string
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
      if (!body.signedTransactionInfo) {
        return new Response(
          JSON.stringify({ error: 'Missing signed transaction info for active subscription sync' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
      }

      const decodedPayload = decodeSignedTransactionPayload(body.signedTransactionInfo)
      const authoritativeLookup = await fetchAuthoritativeSubscriptionLookup({
        transactionId: body.transactionId
          ?? stringifyNumericIdentifier(decodedPayload.transactionId)
          ?? null,
        originalTransactionId: body.originalTransactionId
          ?? stringifyNumericIdentifier(decodedPayload.originalTransactionId)
          ?? null,
        signedTransactionInfo: body.signedTransactionInfo,
        expectedUserId: user.id,
        hintEnvironment: normalizeEnvironment(decodedPayload.environment),
      })

      const verifiedTransaction = authoritativeLookup.verifiedTransaction
      if (!verifiedTransaction.isCurrentlyActive) {
        throw new AppStoreSignedTransactionVerificationError('Authoritative App Store lookup returned an inactive subscription')
      }

      console.log('app_store_sync_verified', {
        userId: user.id,
        productId: verifiedTransaction.productId,
        tier: verifiedTransaction.tier,
        originalTransactionId: verifiedTransaction.originalTransactionId,
        transactionId: verifiedTransaction.transactionId,
        environment: verifiedTransaction.environment,
        isCurrentlyActive: verifiedTransaction.isCurrentlyActive,
        authoritativeStatus: authoritativeLookup.status,
      })

      await applyVerifiedAppStoreTransaction(
        adminClient,
        user.id,
        verifiedTransaction,
        'client_sync',
      )
    } else if (currentProfile?.subscription_provider === 'app_store') {
      console.warn(
        'Ignoring client-originated inactive App Store sync request until server-side lifecycle verification is authoritative',
        { userId: user.id }
      )
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('sync-subscription-status error:', error)

    if (error instanceof AppStoreSignedTransactionVerificationError) {
      console.warn('app_store_sync_verification_failed', {
        message: error.message,
      })
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
