import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import type { VerifiedAppStoreTransaction } from './appStoreSignedTransaction.ts'
import { tierForAppStoreProductId } from './appStoreProducts.ts'

type AppStoreProfileStatus = 'active' | 'canceled' | 'past_due'
type AppStoreEnvironment = 'sandbox' | 'production' | 'xcode' | null
type AppStoreSubscriptionTier = 'weekly' | 'monthly' | 'yearly'

interface AppStoreLifecycleUpdate {
  notificationType: string
  subtype?: string | null
  subscriptionStatus: AppStoreProfileStatus
  originalTransactionId?: string | null
  productId?: string | null
  subscriptionTier?: string | null
  environment?: string | null
  expirationDate?: string | null
  appAccountToken?: string | null
  metadata?: Record<string, unknown>
}

interface AppStoreSubscriptionEventInput {
  userId: string | null
  source: 'client_sync' | 'server_notification'
  notificationEventId?: string | null
  transactionId: string
  originalTransactionId: string
  productId: string
  subscriptionTier: string | null | undefined
  environment?: string | null
  expirationDate?: string | null
  isActive: boolean
  appAccountToken?: string | null
  metadata?: Record<string, unknown>
}

export async function applyVerifiedAppStoreTransaction(
  adminClient: SupabaseClient,
  userId: string,
  verifiedTransaction: VerifiedAppStoreTransaction,
  source: 'client_sync' | 'server_notification',
): Promise<void> {
  const profileUpdate = {
    billing_plan: verifiedTransaction.tier,
    subscription_status: verifiedTransaction.isCurrentlyActive ? 'active' : 'canceled',
    subscription_tier: verifiedTransaction.tier,
    subscription_current_period_end: verifiedTransaction.expirationDate,
    subscription_provider: 'app_store',
    subscription_id: verifiedTransaction.originalTransactionId,
    app_store_product_id: verifiedTransaction.productId,
    app_store_original_transaction_id: verifiedTransaction.originalTransactionId,
    app_store_environment: verifiedTransaction.environment,
  }

  const { error: updateError } = await adminClient
    .from('user_profiles')
    .update(profileUpdate)
    .eq('id', userId)

  if (updateError) {
    throw updateError
  }

  const transactionRecord = {
    id: verifiedTransaction.transactionId,
    user_id: userId,
    transaction_type: 'subscription',
    amount_cents: 0,
    currency: 'USD',
    status: 'succeeded',
    payment_provider: 'app_store',
    subscription_id: verifiedTransaction.originalTransactionId,
    store_transaction_id: verifiedTransaction.transactionId,
    original_transaction_id: verifiedTransaction.originalTransactionId,
    metadata: {
      product_id: verifiedTransaction.productId,
      app_store_environment: verifiedTransaction.environment,
      signed_transaction_info: verifiedTransaction.signedTransactionInfo,
      verification_source: source,
      app_account_token: verifiedTransaction.appAccountToken,
    },
  }

  const { error: transactionError } = await adminClient
    .from('transactions')
    .upsert(transactionRecord, { onConflict: 'id' })

  if (transactionError) {
    throw transactionError
  }
}

export async function updateAppStoreLifecycleState(
  adminClient: SupabaseClient,
  userId: string,
  update: AppStoreLifecycleUpdate,
): Promise<void> {
  const { data: currentProfile, error: profileError } = await adminClient
    .from('user_profiles')
    .select(`
      subscription_tier,
      app_store_product_id,
      app_store_original_transaction_id,
      app_store_environment,
      subscription_current_period_end
    `)
    .eq('id', userId)
    .maybeSingle()

  if (profileError) {
    throw profileError
  }

  const resolvedTier = normalizeTier(update.subscriptionTier ?? currentProfile?.subscription_tier)
    ?? tierForAppStoreProductId(
      normalizeString(update.productId ?? currentProfile?.app_store_product_id, '')
    )
  const resolvedProductId = normalizeString(
    update.productId ?? currentProfile?.app_store_product_id,
    'unknown'
  )
  const resolvedOriginalTransactionId = normalizeString(
    update.originalTransactionId ?? currentProfile?.app_store_original_transaction_id,
    ''
  )
  const resolvedEnvironment = normalizeEnvironment(
    update.environment ?? currentProfile?.app_store_environment
  )
  const resolvedExpirationDate =
    update.expirationDate !== undefined
      ? update.expirationDate
      : currentProfile?.subscription_current_period_end ?? null

  const profileUpdate = {
    billing_plan: resolvedTier ?? 'free',
    subscription_status: update.subscriptionStatus,
    subscription_tier: resolvedTier,
    subscription_current_period_end: resolvedExpirationDate,
    subscription_provider: 'app_store',
    subscription_id: resolvedOriginalTransactionId || null,
    app_store_product_id: resolvedProductId === 'unknown' ? null : resolvedProductId,
    app_store_original_transaction_id: resolvedOriginalTransactionId || null,
    app_store_environment: resolvedEnvironment,
  }

  const { error: updateError } = await adminClient
    .from('user_profiles')
    .update(profileUpdate)
    .eq('id', userId)

  if (updateError) {
    throw updateError
  }

  await recordAppStoreSubscriptionEvent(adminClient, {
    userId,
    source: 'server_notification',
    transactionId: `notification-${crypto.randomUUID()}`,
    originalTransactionId: resolvedOriginalTransactionId || `unknown-${crypto.randomUUID()}`,
    productId: resolvedProductId,
    subscriptionTier: resolvedTier,
    environment: resolvedEnvironment,
    expirationDate: resolvedExpirationDate,
    isActive: update.subscriptionStatus === 'active' || update.subscriptionStatus === 'canceled',
    appAccountToken: update.appAccountToken ?? null,
    metadata: {
      notification_type: update.notificationType,
      subtype: update.subtype ?? null,
      lifecycle_status: update.subscriptionStatus,
      ...update.metadata,
    },
  })
}

export async function clearAppStoreSubscriptionForUser(
  adminClient: SupabaseClient,
  userId: string,
  metadata: Record<string, unknown> = {},
): Promise<void> {
  const { data: currentProfile, error: profileError } = await adminClient
    .from('user_profiles')
    .select('subscription_tier, app_store_product_id, app_store_original_transaction_id, app_store_environment')
    .eq('id', userId)
    .maybeSingle()

  if (profileError) {
    throw profileError
  }

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
    .eq('id', userId)
    .eq('subscription_provider', 'app_store')

  if (clearError) {
    throw clearError
  }

  await recordAppStoreSubscriptionEvent(adminClient, {
    userId,
    source: 'server_notification',
    transactionId: `clear-${crypto.randomUUID()}`,
    originalTransactionId: String(
      metadata.original_transaction_id
        ?? currentProfile?.app_store_original_transaction_id
        ?? ''
    ),
    productId: String(
      metadata.product_id
        ?? currentProfile?.app_store_product_id
        ?? 'unknown'
    ),
    subscriptionTier: metadata.subscription_tier ?? currentProfile?.subscription_tier,
    environment: normalizeEnvironment(
      metadata.environment
        ?? currentProfile?.app_store_environment
    ),
    expirationDate: null,
    isActive: false,
    appAccountToken: normalizeUUID(metadata.app_account_token),
    metadata,
  })
}

export async function recordAppStoreSubscriptionEvent(
  adminClient: SupabaseClient,
  input: AppStoreSubscriptionEventInput,
): Promise<void> {
  const subscriptionTier = normalizeTier(input.subscriptionTier)
  if (!subscriptionTier) {
    throw new Error('App Store subscription event is missing a recognized subscription tier')
  }

  const { error: eventError } = await adminClient
    .from('app_store_subscription_events')
    .upsert({
      user_id: input.userId,
      source: input.source,
      notification_event_id: input.notificationEventId ?? null,
      transaction_id: input.transactionId,
      original_transaction_id: input.originalTransactionId,
      product_id: input.productId,
      subscription_tier: subscriptionTier,
      environment: normalizeEnvironment(input.environment),
      expiration_date: input.expirationDate ?? null,
      is_active: input.isActive,
      app_account_token: normalizeUUID(input.appAccountToken),
      metadata: input.metadata ?? {},
    }, { onConflict: 'transaction_id,source' })

  if (eventError) {
    throw eventError
  }
}

function normalizeTier(value: unknown): AppStoreSubscriptionTier | null {
  switch (value) {
  case 'weekly':
    return 'weekly'
  case 'monthly':
    return 'monthly'
  case 'yearly':
    return 'yearly'
  default:
    return null
  }
}

function normalizeEnvironment(value: unknown): AppStoreEnvironment {
  switch (value) {
  case 'sandbox':
  case 'production':
  case 'xcode':
    return value
  default:
    return null
  }
}

function normalizeUUID(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null
  }

  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value
    : null
}

function normalizeString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : fallback
}
