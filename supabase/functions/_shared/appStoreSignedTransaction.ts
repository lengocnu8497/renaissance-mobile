import { importPKCS8, SignJWT } from 'npm:jose'
import { tierForAppStoreProductId, type AppStoreSubscriptionTier } from './appStoreProducts.ts'

const expectedBundleId =
  Deno.env.get('APP_STORE_BUNDLE_ID') ?? 'renaesthetic.com.Renaissance-Mobile'
const appStoreServerApiIssuerId = Deno.env.get('APP_STORE_SERVER_API_ISSUER_ID') ?? ''
const appStoreServerApiKeyId = Deno.env.get('APP_STORE_SERVER_API_KEY_ID') ?? ''
const appStoreServerApiPrivateKey = Deno.env.get('APP_STORE_SERVER_API_PRIVATE_KEY') ?? ''

type AppStoreEnvironment = 'Sandbox' | 'Production' | 'Xcode'
type AppleApiEnvironment = 'production' | 'sandbox'

export interface DecodedTransactionPayload {
  bundleId?: string
  productId?: string
  transactionId?: string | number
  originalTransactionId?: string | number
  expiresDate?: number
  revocationDate?: number
  environment?: AppStoreEnvironment | string
  appAccountToken?: string
  type?: string
}

export interface DecodedRenewalInfoPayload {
  originalTransactionId?: string | number
  productId?: string
  environment?: string
  autoRenewStatus?: number
  appAccountToken?: string
}

interface JWSHeader {
  alg?: string
  x5c?: string[]
}

export interface DecodedAppStoreJWSPayload<T> {
  signedPayload: string
  header: JWSHeader
  payload: T
}

export interface VerifiedAppStoreTransaction {
  signedTransactionInfo: string
  productId: string
  tier: AppStoreSubscriptionTier
  transactionId: string
  originalTransactionId: string
  expirationDate: string | null
  environment: 'sandbox' | 'production' | 'xcode' | null
  appAccountToken: string | null
  isCurrentlyActive: boolean
}

export interface AuthoritativeSubscriptionLookup {
  verifiedTransaction: VerifiedAppStoreTransaction
  renewalInfo: DecodedRenewalInfoPayload | null
  environment: AppleApiEnvironment
  status: number | null
}

interface TransactionInfoResponse {
  signedTransactionInfo?: string
}

interface SubscriptionStatusResponse {
  data?: Array<{
    lastTransactions?: Array<{
      status?: number
      originalTransactionId?: string
      signedTransactionInfo?: string
      signedRenewalInfo?: string
    }>
  }>
}

export class AppStoreSignedTransactionVerificationError extends Error {}

let cachedAppleBearerToken: { value: string; expiresAt: number } | null = null

export function decodeAppStoreJWSWithoutVerification<T>(
  signedPayload: string,
): DecodedAppStoreJWSPayload<T> {
  const segments = signedPayload.split('.')
  if (segments.length !== 3) {
    throw new AppStoreSignedTransactionVerificationError('App Store signed payload must be a compact JWS')
  }

  return {
    signedPayload,
    header: decodeSegment<JWSHeader>(segments[0]),
    payload: decodeSegment<T>(segments[1]),
  }
}

export function parseVerifiedTransactionPayload(
  payload: DecodedTransactionPayload,
  signedTransactionInfo: string,
  expectedUserId?: string,
): VerifiedAppStoreTransaction {
  if (payload.bundleId !== expectedBundleId) {
    throw new AppStoreSignedTransactionVerificationError('Signed transaction bundle ID does not match this app')
  }

  if (!payload.productId) {
    throw new AppStoreSignedTransactionVerificationError('Signed transaction is missing a product ID')
  }

  const tier = tierForAppStoreProductId(payload.productId)
  if (!tier) {
    throw new AppStoreSignedTransactionVerificationError('Signed transaction product ID is not recognized')
  }

  const transactionId = stringifyNumericIdentifier(payload.transactionId)
  const originalTransactionId = stringifyNumericIdentifier(payload.originalTransactionId)

  if (!transactionId || !originalTransactionId) {
    throw new AppStoreSignedTransactionVerificationError('Signed transaction is missing transaction identifiers')
  }

  if (payload.type && payload.type !== 'Auto-Renewable Subscription') {
    throw new AppStoreSignedTransactionVerificationError('Signed transaction is not an auto-renewable subscription')
  }

  if (expectedUserId && payload.appAccountToken && payload.appAccountToken !== expectedUserId) {
    throw new AppStoreSignedTransactionVerificationError('Signed transaction app account token does not match the authenticated user')
  }

  const expirationDate = payload.expiresDate ? new Date(payload.expiresDate).toISOString() : null
  const expirationTime = payload.expiresDate ?? null
  const revocationTime = payload.revocationDate ?? null
  const now = Date.now()

  const isCurrentlyActive =
    revocationTime == null &&
    expirationTime != null &&
    expirationTime > now

  return {
    signedTransactionInfo,
    productId: payload.productId,
    tier,
    transactionId,
    originalTransactionId,
    expirationDate,
    environment: normalizeEnvironment(payload.environment),
    appAccountToken: payload.appAccountToken ?? null,
    isCurrentlyActive,
  }
}

export function decodeAndParseSignedTransaction(
  signedTransactionInfo: string,
  expectedUserId?: string,
): VerifiedAppStoreTransaction {
  const { payload } = decodeAppStoreJWSWithoutVerification<DecodedTransactionPayload>(signedTransactionInfo)
  return parseVerifiedTransactionPayload(payload, signedTransactionInfo, expectedUserId)
}

export function decodeSignedTransactionPayload(
  signedTransactionInfo: string,
): DecodedTransactionPayload {
  return decodeAppStoreJWSWithoutVerification<DecodedTransactionPayload>(signedTransactionInfo).payload
}

export function decodeSignedRenewalInfoPayload(
  signedRenewalInfo: string,
): DecodedRenewalInfoPayload {
  return decodeAppStoreJWSWithoutVerification<DecodedRenewalInfoPayload>(signedRenewalInfo).payload
}

export function stringifyNumericIdentifier(value: string | number | undefined): string | null {
  if (typeof value === 'string' && value.length > 0) {
    return value
  }

  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(Math.trunc(value))
  }

  return null
}

export function normalizeEnvironment(value: string | undefined): 'sandbox' | 'production' | 'xcode' | null {
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

export async function fetchAuthoritativeSubscriptionLookup(
  input: {
    transactionId?: string | null
    originalTransactionId?: string | null
    signedTransactionInfo?: string | null
    signedRenewalInfo?: string | null
    expectedUserId?: string
    hintEnvironment?: 'sandbox' | 'production' | 'xcode' | null
  },
): Promise<AuthoritativeSubscriptionLookup> {
  ensureAppStoreServerApiConfigured()

  const unverifiedTransactionPayload = input.signedTransactionInfo
    ? decodeSignedTransactionPayload(input.signedTransactionInfo)
    : null
  const unverifiedRenewalPayload = input.signedRenewalInfo
    ? decodeSignedRenewalInfoPayload(input.signedRenewalInfo)
    : null

  const transactionId =
    input.transactionId
    ?? stringifyNumericIdentifier(unverifiedTransactionPayload?.transactionId)
    ?? null
  const originalTransactionId =
    input.originalTransactionId
    ?? stringifyNumericIdentifier(unverifiedTransactionPayload?.originalTransactionId)
    ?? stringifyNumericIdentifier(unverifiedRenewalPayload?.originalTransactionId)
    ?? null
  const hintEnvironment =
    input.hintEnvironment
    ?? normalizeEnvironment(unverifiedTransactionPayload?.environment)
    ?? normalizeEnvironment(unverifiedRenewalPayload?.environment)

  if (!transactionId && !originalTransactionId) {
    throw new AppStoreSignedTransactionVerificationError('Unable to resolve an App Store transaction identifier for verification')
  }

  const environments = environmentsToTry(hintEnvironment)
  const failures: string[] = []

  for (const environment of environments) {
    try {
      const result = await lookupSubscriptionInEnvironment({
        environment,
        transactionId,
        originalTransactionId,
        expectedUserId: input.expectedUserId,
      })

      if (result) {
        return result
      }
    } catch (error) {
      failures.push(`${environment}: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  throw new AppStoreSignedTransactionVerificationError(
    failures.length > 0
      ? `App Store lookup failed across environments (${failures.join('; ')})`
      : 'App Store lookup did not return a verified subscription state',
  )
}

function ensureAppStoreServerApiConfigured(): void {
  if (!appStoreServerApiIssuerId || !appStoreServerApiKeyId || !appStoreServerApiPrivateKey) {
    throw new AppStoreSignedTransactionVerificationError(
      'App Store Server API credentials are not configured on the server',
    )
  }
}

async function lookupSubscriptionInEnvironment(
  input: {
    environment: AppleApiEnvironment
    transactionId: string | null
    originalTransactionId: string | null
    expectedUserId?: string
  },
): Promise<AuthoritativeSubscriptionLookup | null> {
  let transactionCandidate:
    | { verifiedTransaction: VerifiedAppStoreTransaction; renewalInfo: DecodedRenewalInfoPayload | null; status: number | null }
    | null = null

  if (input.transactionId) {
    const transactionResponse = await fetchAppleJson<TransactionInfoResponse>(
      input.environment,
      `/inApps/v1/transactions/${encodeURIComponent(input.transactionId)}`,
    )

    if (transactionResponse.signedTransactionInfo) {
      const verifiedTransaction = decodeAndParseSignedTransaction(
        transactionResponse.signedTransactionInfo,
        input.expectedUserId,
      )

      transactionCandidate = {
        verifiedTransaction,
        renewalInfo: null,
        status: null,
      }
    }
  }

  if (input.originalTransactionId) {
    const subscriptionResponse = await fetchAppleJson<SubscriptionStatusResponse>(
      input.environment,
      `/inApps/v1/subscriptions/${encodeURIComponent(input.originalTransactionId)}`,
    )

    const candidate = selectBestSubscriptionStatus(
      subscriptionResponse,
      input.originalTransactionId,
      input.expectedUserId,
    )

    if (candidate) {
      return {
        verifiedTransaction: candidate.verifiedTransaction,
        renewalInfo: candidate.renewalInfo,
        environment: input.environment,
        status: candidate.status,
      }
    }
  }

  if (transactionCandidate) {
    return {
      ...transactionCandidate,
      environment: input.environment,
    }
  }

  return null
}

function selectBestSubscriptionStatus(
  response: SubscriptionStatusResponse,
  originalTransactionId: string,
  expectedUserId?: string,
): {
  verifiedTransaction: VerifiedAppStoreTransaction
  renewalInfo: DecodedRenewalInfoPayload | null
  status: number | null
} | null {
  const candidates = (response.data ?? [])
    .flatMap((item) => item.lastTransactions ?? [])
    .map((item) => {
      if (!item.signedTransactionInfo) {
        return null
      }

      const verifiedTransaction = decodeAndParseSignedTransaction(
        item.signedTransactionInfo,
        expectedUserId,
      )

      if (verifiedTransaction.originalTransactionId !== originalTransactionId) {
        return null
      }

      return {
        verifiedTransaction,
        renewalInfo: item.signedRenewalInfo ? decodeSignedRenewalInfoPayload(item.signedRenewalInfo) : null,
        status: item.status ?? null,
      }
    })
    .filter((value): value is {
      verifiedTransaction: VerifiedAppStoreTransaction
      renewalInfo: DecodedRenewalInfoPayload | null
      status: number | null
    } => value !== null)
    .sort((left, right) => compareSubscriptionCandidates(left, right))

  return candidates[0] ?? null
}

function compareSubscriptionCandidates(
  left: { verifiedTransaction: VerifiedAppStoreTransaction; status: number | null },
  right: { verifiedTransaction: VerifiedAppStoreTransaction; status: number | null },
): number {
  const statusScore = (value: number | null): number => {
    switch (value) {
    case 1:
      return 5
    case 4:
      return 4
    case 3:
      return 3
    case 2:
      return 2
    case 5:
      return 1
    default:
      return 0
    }
  }

  const leftStatusScore = statusScore(left.status)
  const rightStatusScore = statusScore(right.status)
  if (leftStatusScore !== rightStatusScore) {
    return rightStatusScore - leftStatusScore
  }

  const leftExpiry = left.verifiedTransaction.expirationDate ? Date.parse(left.verifiedTransaction.expirationDate) : 0
  const rightExpiry = right.verifiedTransaction.expirationDate ? Date.parse(right.verifiedTransaction.expirationDate) : 0
  return rightExpiry - leftExpiry
}

async function fetchAppleJson<T>(
  environment: AppleApiEnvironment,
  path: string,
): Promise<T> {
  const token = await getAppStoreServerBearerToken()
  const response = await fetch(`${baseUrlForEnvironment(environment)}${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
    },
  })

  if (!response.ok) {
    const text = await response.text()
    throw new AppStoreSignedTransactionVerificationError(
      `Apple API ${response.status} for ${path}: ${text || 'empty response'}`,
    )
  }

  return await response.json() as T
}

async function getAppStoreServerBearerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedAppleBearerToken && cachedAppleBearerToken.expiresAt - 60 > now) {
    return cachedAppleBearerToken.value
  }

  const normalizedPrivateKey = normalizePrivateKey(appStoreServerApiPrivateKey)
  const key = await importPKCS8(normalizedPrivateKey, 'ES256')
  const expiresAt = now + 300
  const token = await new SignJWT({ bid: expectedBundleId })
    .setProtectedHeader({ alg: 'ES256', kid: appStoreServerApiKeyId, typ: 'JWT' })
    .setIssuer(appStoreServerApiIssuerId)
    .setAudience('appstoreconnect-v1')
    .setIssuedAt(now)
    .setExpirationTime(expiresAt)
    .sign(key)

  cachedAppleBearerToken = { value: token, expiresAt }
  return token
}

function normalizePrivateKey(value: string): string {
  const withNewlines = value.includes('\\n')
    ? value.replace(/\\n/g, '\n')
    : value
  const trimmed = withNewlines.trim()

  if (trimmed.includes('BEGIN PRIVATE KEY')) {
    return trimmed
  }

  const wrapped = trimmed.match(/.{1,64}/g)?.join('\n') ?? trimmed
  return `-----BEGIN PRIVATE KEY-----\n${wrapped}\n-----END PRIVATE KEY-----`
}

function baseUrlForEnvironment(environment: AppleApiEnvironment): string {
  return environment === 'sandbox'
    ? 'https://api.storekit-sandbox.itunes.apple.com'
    : 'https://api.storekit.itunes.apple.com'
}

function environmentsToTry(
  hintEnvironment: 'sandbox' | 'production' | 'xcode' | null,
): AppleApiEnvironment[] {
  switch (hintEnvironment) {
  case 'sandbox':
  case 'xcode':
    return ['sandbox', 'production']
  case 'production':
    return ['production', 'sandbox']
  default:
    return ['production', 'sandbox']
  }
}

function decodeSegment<T>(segment: string): T {
  const normalized = segment
    .replace(/-/g, '+')
    .replace(/_/g, '/')
    .padEnd(Math.ceil(segment.length / 4) * 4, '=')

  try {
    const json = atob(normalized)
    return JSON.parse(json) as T
  } catch {
    throw new AppStoreSignedTransactionVerificationError('Signed transaction JWS could not be decoded')
  }
}
