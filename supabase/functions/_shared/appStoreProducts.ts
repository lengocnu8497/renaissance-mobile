export type AppStoreSubscriptionTier = 'weekly' | 'monthly' | 'yearly'

const productIdByTier: Record<AppStoreSubscriptionTier, string> = {
  weekly: Deno.env.get('APP_STORE_PRODUCT_ID_WEEKLY') ?? 'com.renaissance.premium.weekly',
  monthly: Deno.env.get('APP_STORE_PRODUCT_ID_MONTHLY') ?? 'com.renaissance.premium.monthly',
  yearly: Deno.env.get('APP_STORE_PRODUCT_ID_YEARLY') ?? 'com.renaissance.premium.yearly',
}

const tierByProductId = new Map<string, AppStoreSubscriptionTier>(
  Object.entries(productIdByTier).map(([tier, productId]) => [productId, tier as AppStoreSubscriptionTier])
)

export function tierForAppStoreProductId(productId: string): AppStoreSubscriptionTier | null {
  return tierByProductId.get(productId) ?? null
}
