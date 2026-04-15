import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import {
  AppStoreSignedTransactionVerificationError,
  decodeAppStoreJWSWithoutVerification,
  fetchAuthoritativeSubscriptionLookup,
  stringifyNumericIdentifier,
  type VerifiedAppStoreTransaction,
} from '../_shared/appStoreSignedTransaction.ts'
import {
  applyVerifiedAppStoreTransaction,
  clearAppStoreSubscriptionForUser,
  recordAppStoreSubscriptionEvent,
  updateAppStoreLifecycleState,
} from '../_shared/appStoreSubscriptionPersistence.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AppStoreNotificationRequest {
  signedPayload?: string
}

interface NotificationPayload {
  notificationUUID?: string
  notificationType?: string
  subtype?: string
  version?: string
  data?: {
    appAppleId?: number
    bundleId?: string
    bundleVersion?: string
    environment?: string
    signedTransactionInfo?: string
    signedRenewalInfo?: string
    status?: number
  }
}

interface RenewalInfoPayload {
  originalTransactionId?: string | number
  productId?: string
  environment?: string
  autoRenewStatus?: number
  appAccountToken?: string
}

const inactiveNotificationTypes = new Set([
  'EXPIRED',
  'REVOKE',
  'REFUND',
  'GRACE_PERIOD_EXPIRED',
])

type NotificationLifecycleResolution =
  | { action: 'none' }
  | {
    action: 'set_status'
    subscriptionStatus: 'active' | 'canceled' | 'past_due'
    reason: string
  }
  | {
    action: 'clear'
    reason: string
  }

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const body: AppStoreNotificationRequest = await req.json()
    if (!body.signedPayload) {
      return new Response(
        JSON.stringify({ error: 'Missing signedPayload' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const decodedNotification = decodeAppStoreJWSWithoutVerification<NotificationPayload>(body.signedPayload)
    const notificationPayload = decodedNotification.payload

    if (!notificationPayload.notificationUUID || !notificationPayload.notificationType) {
      return new Response(
        JSON.stringify({ error: 'Invalid App Store notification payload' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const decodedTransactionPayload = notificationPayload.data?.signedTransactionInfo
      ? decodeAppStoreJWSWithoutVerification<{ transactionId?: string | number; originalTransactionId?: string | number }>(
        notificationPayload.data.signedTransactionInfo,
      ).payload
      : null
    const decodedRenewalPayload = notificationPayload.data?.signedRenewalInfo
      ? decodeAppStoreJWSWithoutVerification<RenewalInfoPayload>(
        notificationPayload.data.signedRenewalInfo,
      ).payload
      : null

    const authoritativeLookup = await fetchAuthoritativeSubscriptionLookup({
      signedTransactionInfo: notificationPayload.data?.signedTransactionInfo ?? null,
      signedRenewalInfo: notificationPayload.data?.signedRenewalInfo ?? null,
      transactionId: stringifyNumericIdentifier(decodedTransactionPayload?.transactionId),
      originalTransactionId:
        stringifyNumericIdentifier(decodedTransactionPayload?.originalTransactionId)
        ?? stringifyNumericIdentifier(decodedRenewalPayload?.originalTransactionId),
      hintEnvironment: normalizeNotificationEnvironment(notificationPayload.data?.environment),
    })

    const verifiedTransaction = authoritativeLookup.verifiedTransaction
    const verifiedRenewalInfo = authoritativeLookup.renewalInfo
      ? { payload: authoritativeLookup.renewalInfo }
      : null

    const userId = await resolveUserId(adminClient, verifiedTransaction, verifiedRenewalInfo?.payload ?? null)

    const { data: insertedEvent, error: notificationInsertError } = await adminClient
      .from('app_store_notification_events')
      .upsert({
        notification_uuid: notificationPayload.notificationUUID,
        notification_type: notificationPayload.notificationType,
        subtype: notificationPayload.subtype ?? null,
        notification_version: notificationPayload.version ?? null,
        signed_payload: body.signedPayload,
        signed_transaction_info: notificationPayload.data?.signedTransactionInfo ?? null,
        signed_renewal_info: notificationPayload.data?.signedRenewalInfo ?? null,
        original_transaction_id: verifiedTransaction?.originalTransactionId
          ?? stringifyNumericIdentifier(verifiedRenewalInfo?.payload.originalTransactionId)
          ?? null,
        app_account_token: parseUUIDOrNull(
          verifiedTransaction?.appAccountToken ?? verifiedRenewalInfo?.payload.appAccountToken,
        ),
        raw_payload: notificationPayload,
      }, { onConflict: 'notification_uuid' })
      .select('id')
      .single()

    if (notificationInsertError) {
      throw notificationInsertError
    }

    const lifecycleResolution = resolveNotificationLifecycle(
      notificationPayload,
      verifiedRenewalInfo?.payload ?? null,
    )
    const lifecycleReason = lifecycleResolution.action === 'none'
      ? null
      : lifecycleResolution.reason

    console.log('app_store_notification_received', {
      notificationUUID: notificationPayload.notificationUUID,
      notificationType: notificationPayload.notificationType,
      subtype: notificationPayload.subtype ?? null,
      userId,
      lifecycleAction: lifecycleResolution.action,
      lifecycleReason,
      authoritativeStatus: authoritativeLookup.status,
      originalTransactionId: verifiedTransaction?.originalTransactionId
        ?? stringifyNumericIdentifier(verifiedRenewalInfo?.payload.originalTransactionId)
        ?? null,
      productId: verifiedTransaction?.productId ?? verifiedRenewalInfo?.payload.productId ?? null,
      environment: verifiedTransaction?.environment
        ?? normalizeNotificationEnvironment(verifiedRenewalInfo?.payload.environment ?? notificationPayload.data?.environment),
    })

    if (verifiedTransaction && userId) {
      await applyVerifiedAppStoreTransaction(
        adminClient,
        userId,
        verifiedTransaction,
        'server_notification',
      )

      await recordAppStoreSubscriptionEvent(adminClient, {
        userId,
        source: 'server_notification',
        notificationEventId: insertedEvent.id,
        transactionId: verifiedTransaction.transactionId,
        originalTransactionId: verifiedTransaction.originalTransactionId,
        productId: verifiedTransaction.productId,
        subscriptionTier: verifiedTransaction.tier,
        environment: verifiedTransaction.environment,
        expirationDate: verifiedTransaction.expirationDate,
        isActive: isEntitlementActive(verifiedTransaction, authoritativeLookup.status),
        appAccountToken: parseUUIDOrNull(verifiedTransaction.appAccountToken),
        metadata: {
          notification_type: notificationPayload.notificationType,
          subtype: notificationPayload.subtype ?? null,
          lifecycle_action: lifecycleResolution.action,
          lifecycle_reason: lifecycleReason,
        },
      })

      if (lifecycleResolution.action === 'set_status') {
        await updateAppStoreLifecycleState(adminClient, userId, {
          notificationType: notificationPayload.notificationType,
          subtype: notificationPayload.subtype ?? null,
          subscriptionStatus: lifecycleResolution.subscriptionStatus,
          originalTransactionId: verifiedTransaction.originalTransactionId,
          productId: verifiedTransaction.productId,
          subscriptionTier: verifiedTransaction.tier,
          environment: verifiedTransaction.environment,
          expirationDate: verifiedTransaction.expirationDate,
          appAccountToken: verifiedTransaction.appAccountToken,
          metadata: {
            notification_event_id: insertedEvent.id,
            lifecycle_reason: lifecycleResolution.reason,
          },
        })
      } else if (lifecycleResolution.action === 'clear') {
        await clearAppStoreSubscriptionForUser(
          adminClient,
          userId,
          {
            notification_type: notificationPayload.notificationType,
            subtype: notificationPayload.subtype ?? null,
            original_transaction_id: verifiedTransaction.originalTransactionId,
            product_id: verifiedTransaction.productId,
            subscription_tier: verifiedTransaction.tier,
            environment: verifiedTransaction.environment,
            app_account_token: verifiedTransaction.appAccountToken,
            notification_event_id: insertedEvent.id,
            lifecycle_reason: lifecycleResolution.reason,
          },
        )
      }
    } else if (userId && lifecycleResolution.action === 'clear') {
      await clearAppStoreSubscriptionForUser(
        adminClient,
        userId,
        {
          notification_type: notificationPayload.notificationType,
          subtype: notificationPayload.subtype ?? null,
          original_transaction_id: stringifyNumericIdentifier(verifiedRenewalInfo?.payload.originalTransactionId) ?? '',
          product_id: verifiedRenewalInfo?.payload.productId ?? 'unknown',
          subscription_tier: null,
          environment: normalizeNotificationEnvironment(verifiedRenewalInfo?.payload.environment ?? notificationPayload.data?.environment),
          app_account_token: verifiedRenewalInfo?.payload.appAccountToken ?? null,
          notification_event_id: insertedEvent.id,
          lifecycle_reason: lifecycleResolution.reason,
        },
      )
    } else if (userId && lifecycleResolution.action === 'set_status') {
      await updateAppStoreLifecycleState(adminClient, userId, {
        notificationType: notificationPayload.notificationType,
        subtype: notificationPayload.subtype ?? null,
        subscriptionStatus: lifecycleResolution.subscriptionStatus,
        originalTransactionId: stringifyNumericIdentifier(verifiedRenewalInfo?.payload.originalTransactionId) ?? null,
        productId: verifiedRenewalInfo?.payload.productId ?? null,
        subscriptionTier: null,
        environment: normalizeNotificationEnvironment(verifiedRenewalInfo?.payload.environment ?? notificationPayload.data?.environment),
        appAccountToken: verifiedRenewalInfo?.payload.appAccountToken ?? null,
        metadata: {
          notification_event_id: insertedEvent.id,
          lifecycle_reason: lifecycleResolution.reason,
        },
      })
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('app-store-server-notifications error:', error)

    if (error instanceof AppStoreSignedTransactionVerificationError) {
      console.warn('app_store_notification_verification_failed', {
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

async function resolveUserId(
  adminClient: ReturnType<typeof createClient>,
  verifiedTransaction: VerifiedAppStoreTransaction | null,
  renewalInfo: RenewalInfoPayload | null,
): Promise<string | null> {
  const appAccountToken = parseUUIDOrNull(verifiedTransaction?.appAccountToken)
  if (appAccountToken) {
    return appAccountToken
  }

  const renewalAppAccountToken = parseUUIDOrNull(renewalInfo?.appAccountToken)
  if (renewalAppAccountToken) {
    return renewalAppAccountToken
  }

  const originalTransactionId =
    verifiedTransaction?.originalTransactionId
    ?? stringifyNumericIdentifier(renewalInfo?.originalTransactionId)

  if (!originalTransactionId) {
    return null
  }

  const { data: profile, error } = await adminClient
    .from('user_profiles')
    .select('id')
    .eq('app_store_original_transaction_id', originalTransactionId)
    .maybeSingle()

  if (error) {
    throw error
  }

  return profile?.id ?? null
}

function parseUUIDOrNull(value: string | null | undefined): string | null {
  if (!value) {
    return null
  }

  const normalized = value.trim()
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(normalized)) {
    return normalized
  }

  return null
}

function resolveNotificationLifecycle(
  notificationPayload: NotificationPayload,
  renewalInfo: RenewalInfoPayload | null,
): NotificationLifecycleResolution {
  if (notificationPayload.notificationType && inactiveNotificationTypes.has(notificationPayload.notificationType)) {
    return {
      action: 'clear',
      reason: 'terminal_notification_type',
    }
  }

  if (notificationPayload.notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
    if (renewalInfo?.autoRenewStatus === 0) {
      return {
        action: 'set_status',
        subscriptionStatus: 'canceled',
        reason: 'auto_renew_disabled',
      }
    }

    if (renewalInfo?.autoRenewStatus === 1) {
      return {
        action: 'set_status',
        subscriptionStatus: 'active',
        reason: 'auto_renew_enabled',
      }
    }
  }

  if (notificationPayload.notificationType === 'DID_FAIL_TO_RENEW') {
    if (notificationPayload.subtype === 'GRACE_PERIOD') {
      return {
        action: 'set_status',
        subscriptionStatus: 'active',
        reason: 'grace_period',
      }
    }

    return {
      action: 'set_status',
      subscriptionStatus: 'past_due',
      reason: 'failed_to_renew',
    }
  }

  if (notificationPayload.notificationType === 'DID_RENEW'
    || notificationPayload.notificationType === 'DID_RECOVER'
    || notificationPayload.notificationType === 'RENEWAL_EXTENDED') {
    return {
      action: 'set_status',
      subscriptionStatus: 'active',
      reason: 'renewal_lifecycle_update',
    }
  }

  return { action: 'none' }
}

function isEntitlementActive(
  transaction: { isCurrentlyActive: boolean },
  authoritativeStatus: number | null,
): boolean {
  if (authoritativeStatus === 3 || authoritativeStatus === 5) {
    return false
  }

  return transaction.isCurrentlyActive
}

function normalizeNotificationEnvironment(value: string | undefined): 'sandbox' | 'production' | 'xcode' | null {
  switch (value) {
  case 'Sandbox':
  case 'sandbox':
    return 'sandbox'
  case 'Production':
  case 'production':
    return 'production'
  case 'Xcode':
  case 'xcode':
    return 'xcode'
  default:
    return null
  }
}
