// generate-promo-signature
//
// Generates a StoreKit 2 promotional offer signature so the client can present
// a 50%-off first-month offer without storing the private key on-device.
//
// Required Supabase secrets (set via `supabase secrets set`):
//   APPLE_PROMO_KEY_ID      — the key ID shown in App Store Connect under
//                             Subscriptions → Subscription Keys (Promotion Keys)
//   APPLE_PROMO_PRIVATE_KEY — the PEM-encoded private key downloaded from the same page
//
// App Store Connect setup:
//   1. Subscriptions → your subscription group → Monthly Plan → Promotional Offers
//   2. Create offer with ID "monthly_50_off_first_month", 50% off, 1 month, Pay up front or Pay as you go
//   3. Go to Subscriptions → Subscription Keys → create a key (or reuse one), copy key ID + download private key
//   4. Store both as Supabase secrets (see above)

import { createClient } from 'jsr:@supabase/supabase-js@2'

const BUNDLE_ID = 'com.renaesthetic.app'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    })
  }

  try {
    // Auth guard — caller must be a signed-in user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return errorResponse('Missing authorization header', 401)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return errorResponse('Unauthorized', 401)
    }

    const body = await req.json()
    const productId: string = body.product_id
    const offerId: string   = body.offer_id

    if (!productId || !offerId) {
      return errorResponse('product_id and offer_id are required', 400)
    }

    const keyId      = Deno.env.get('APPLE_PROMO_KEY_ID')
    const privateKey = Deno.env.get('APPLE_PROMO_PRIVATE_KEY')

    if (!keyId || !privateKey) {
      return errorResponse('Promo offer keys are not configured', 500)
    }

    // Build signature payload per Apple's documentation:
    // bundleId + '⁣' + keyId + '⁣' + productId + '⁣' + offerId +
    // '⁣' + appAccountToken (user UUID) + '⁣' + nonce + '⁣' + timestamp (ms)
    const nonce     = crypto.randomUUID()
    const timestamp = Date.now()
    const appAccountToken = user.id.toLowerCase()

    const payload = [
      BUNDLE_ID,
      keyId,
      productId,
      offerId,
      appAccountToken,
      nonce,
      String(timestamp),
    ].join('⁣')

    const signature = await signPayload(payload, privateKey)

    return new Response(
      JSON.stringify({
        key_id:    keyId,
        nonce,
        signature,
        timestamp,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (err) {
    console.error('generate-promo-signature error:', err)
    return errorResponse('Internal server error', 500)
  }
})

// Sign the payload using ECDSA P-256 SHA-256 (ES256).
// The Apple promo offer private key is a PKCS#8 EC key in PEM format.
async function signPayload(payload: string, pemKey: string): Promise<string> {
  const keyData = pemToDer(pemKey)

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )

  const encoded  = new TextEncoder().encode(payload)
  const sigBytes = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    encoded
  )

  return btoa(String.fromCharCode(...new Uint8Array(sigBytes)))
}

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '')
  const binary = atob(base64)
  const bytes  = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

function errorResponse(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  })
}
