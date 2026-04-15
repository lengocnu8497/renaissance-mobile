import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    var onDismiss: (() -> Void)? = nil
    var onSubscribed: (() -> Void)? = nil

    @State private var selectedTier: SubscriptionTier = .yearly
    @State private var statusMessage: String?
    @State private var didNotifySubscription = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBarSpacing
                    headlineSection
                    planSection
                    ctaSection
                    footerSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#7D7B74"))
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                }
                .padding(.top, 28)
                .padding(.leading, 18)
            }
        }
        .background(paywallBackground.ignoresSafeArea())
        .task { await initializeStoreKitState() }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            guard subscriptionStore.hasActiveSubscription else { return }
            guard !didNotifySubscription else { return }

            didNotifySubscription = true
            statusMessage = nil
            onSubscribed?()
        }
    }

    private var topBarSpacing: some View {
        HStack {
            Spacer()

            Button("Restore") {
                Task { await restorePurchases() }
            }
            .font(.custom("PlusJakartaSans-SemiBold", size: 15))
            .foregroundStyle(Color(hex: "#8A8C83"))
            .disabled(subscriptionStore.isPurchasing)
        }
        .padding(.top, onDismiss == nil ? 2 : 8)
        .padding(.bottom, 22)
    }

    private var headlineSection: some View {
        Text("Get full access")
            .font(.custom("Manrope", size: 34).weight(.heavy))
            .foregroundStyle(Color(hex: "#171714"))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
    }

    private var planSection: some View {
        VStack(spacing: 12) {
            ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                planCard(for: tier)
            }
        }
    }

    @ViewBuilder
    private func planCard(for tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        let metadata = planMetadata(for: tier)

        Button {
            selectedTier = tier
            statusMessage = nil
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(metadata.title)
                            .font(.custom("Outfit-Bold", size: 23))
                            .foregroundStyle(isSelected ? Color(hex: "#6F4F4E") : Color(hex: "#55624F"))

                        if tier == .yearly {
                            Text("Best Value")
                                .font(.custom("Outfit-Bold", size: 11))
                                .tracking(1.1)
                                .foregroundStyle(Color(hex: "#7E5F5D"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(hex: "#F3E8E4"))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(metadata.primaryPrice)
                            .font(.custom("Manrope", size: 33).weight(.heavy))
                            .foregroundStyle(isSelected ? Color(hex: "#6A5754") : Color(hex: "#4C5847"))

                        Text(metadata.periodLabel)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14).weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(isSelected ? Color(hex: "#9A8683") : Color(hex: "#8A8C83"))
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "#6F7D67") : Color(hex: "#C9CEC4"))
                    .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(planBackground(isSelected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: "#BF9490").opacity(0.42) : Color(hex: "#6F7D67").opacity(0.10),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color.black.opacity(isSelected ? 0.05 : 0.03), radius: isSelected ? 14 : 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var ctaSection: some View {
        VStack(spacing: 0) {
            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color(hex: "#6F4F4E"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 14)
            }

            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#6F7D67"))
                    .frame(width: 22, height: 22)
                    .background(Color(hex: "#EDF2E8"))
                    .clipShape(Circle())

                Text("No hidden pricing. Cancel anytime.")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15).weight(.bold))
                    .foregroundStyle(Color(hex: "#34322D"))
            }
            .padding(.bottom, 14)

            Button {
                Task { await purchaseSelectedTier() }
            } label: {
                if subscriptionStore.isPurchasing {
                    ProgressView()
                        .tint(Color(hex: "#FAF8F3"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    Text("Continue with \(selectedTier.ctaTitle)")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 20).weight(.bold))
                        .foregroundStyle(Color(hex: "#FAF8F3"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
            .background(Color(hex: "#465241"))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .disabled(subscriptionStore.isPurchasing || selectedProduct == nil)

            VStack(spacing: 4) {
                Text(selectedPlanSummaryLine)
                    .font(.custom("Manrope", size: 18).weight(.heavy))
                    .foregroundStyle(Color(hex: "#171714"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)

                Text(selectedPlanBillingLine)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color(hex: "#7D7B74"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.94),
                    Color(hex: "#FBF9F4").opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: "#6F7D67").opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
        .padding(.top, 16)
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                footerLink(title: "Terms of Use", url: AppConfig.termsOfUseURL)
                Text("•")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color(hex: "#A5A198"))
                footerLink(title: "Privacy Policy", url: AppConfig.privacyPolicyURL)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
        .padding(.bottom, 4)
    }

    private func footerLink(title: String, url: URL) -> some View {
        Link(destination: url) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 13).weight(.bold))
                .foregroundStyle(Color(hex: "#6F7D67"))
        }
    }

    private var paywallBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FAF7F0"),
                Color(hex: "#F6F4EE")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(Color(hex: "#F7EBE8"))
                .frame(width: 240, height: 240)
                .blur(radius: 24)
                .offset(x: 40, y: -110)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color(hex: "#EDF2E8"))
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: -50, y: 120)
        }
    }

    private func planBackground(isSelected: Bool) -> some ShapeStyle {
        LinearGradient(
            colors: isSelected
                ? [
                    Color(hex: "#F7EBE8").opacity(0.92),
                    Color(hex: "#FFF9F7").opacity(0.96)
                ]
                : [
                    Color.white.opacity(0.94),
                    Color(hex: "#F8F6F0").opacity(0.92)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectedProduct: Product? {
        subscriptionStore.product(for: selectedTier)
    }

    private var selectedPlanSummaryLine: String {
        planMetadata(for: selectedTier).summaryHeadline
    }

    private var selectedPlanBillingLine: String {
        planMetadata(for: selectedTier).billingDescription
    }

    private func planMetadata(for tier: SubscriptionTier) -> PlanMetadata {
        let product = subscriptionStore.product(for: tier)
        let displayPrice = product?.displayPrice ?? fallbackDisplayPrice(for: tier)

        switch tier {
        case .weekly:
            return PlanMetadata(
                title: "Weekly Plan",
                primaryPrice: displayPrice,
                periodLabel: "7 Days",
                summaryHeadline: "\(displayPrice) per week",
                billingDescription: "Billed every 7 days for the Weekly auto-renewing subscription."
            )
        case .monthly:
            return PlanMetadata(
                title: "Monthly Plan",
                primaryPrice: displayPrice,
                periodLabel: "Month",
                summaryHeadline: "\(displayPrice) per month",
                billingDescription: "Billed once monthly for the Monthly auto-renewing subscription."
            )
        case .yearly:
            let monthlyEquivalent = monthlyEquivalentText(for: product)
            let summaryHeadline = monthlyEquivalent.map { "\(displayPrice) per year (\($0)/month)" } ?? "\(displayPrice) per year"

            return PlanMetadata(
                title: "Annual Plan",
                primaryPrice: displayPrice,
                periodLabel: "Year",
                summaryHeadline: summaryHeadline,
                billingDescription: "Billed once yearly for the Annual auto-renewing subscription."
            )
        }
    }

    private func monthlyEquivalentText(for product: Product?) -> String? {
        guard let product else { return nil }
        guard let period = product.subscription?.subscriptionPeriod else { return nil }

        let months: Decimal
        switch period.unit {
        case .day:
            guard period.value > 0 else { return nil }
            months = Decimal(period.value) / 30
        case .week:
            guard period.value > 0 else { return nil }
            months = Decimal(period.value) / 4
        case .month:
            months = Decimal(period.value)
        case .year:
            months = Decimal(period.value * 12)
        @unknown default:
            return nil
        }

        guard months > 0 else { return nil }

        let monthlyPrice = product.price / months
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.currencyCode = product.priceFormatStyle.currencyCode

        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }

    private func fallbackDisplayPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .weekly: "$8.99"
        case .monthly: "$19.99"
        case .yearly: "$89.99"
        }
    }

    @MainActor
    private func initializeStoreKitState() async {
        await subscriptionStore.prepare()
        syncSelectedTierWithAvailableProducts()

        if let errorMessage = subscriptionStore.errorMessage, subscriptionStore.productsByTier.isEmpty {
            statusMessage = errorMessage
        }
    }

    @MainActor
    private func purchaseSelectedTier() async {
        statusMessage = nil

        let result = await subscriptionStore.purchase(selectedTier)
        switch result {
        case .success:
            await subscriptionStore.refreshEntitlementsAndSync()
        case .pending:
            statusMessage = "Your App Store purchase is pending approval."
        case .cancelled:
            statusMessage = nil
        case .failed(let message):
            statusMessage = message
        }
    }

    @MainActor
    private func restorePurchases() async {
        statusMessage = nil
        let restored = await subscriptionStore.restorePurchases()
        if restored {
            statusMessage = subscriptionStore.hasActiveSubscription
                ? "Your purchases were restored successfully."
                : "No active App Store subscription was found to restore."
        } else {
            statusMessage = subscriptionStore.errorMessage ?? "Unable to restore purchases right now."
        }
    }

    @MainActor
    private func syncSelectedTierWithAvailableProducts() {
        if let activeTier = subscriptionStore.activeTier, subscriptionStore.product(for: activeTier) != nil {
            selectedTier = activeTier
            return
        }

        if subscriptionStore.product(for: selectedTier) != nil {
            return
        }

        if let firstAvailableTier = SubscriptionTier.allCases.first(where: { subscriptionStore.product(for: $0) != nil }) {
            selectedTier = firstAvailableTier
        }
    }
}

private struct PlanMetadata {
    let title: String
    let primaryPrice: String
    let periodLabel: String
    let summaryHeadline: String
    let billingDescription: String
}

private extension SubscriptionTier {
    static let allCases: [SubscriptionTier] = [.weekly, .monthly, .yearly]

    var ctaTitle: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Annual"
        }
    }
}
