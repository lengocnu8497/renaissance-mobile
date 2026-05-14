import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    var onDismiss: (() -> Void)? = nil
    var onSubscribed: (() -> Void)? = nil
    var showsPurchaseCTA: Bool = true
    var showsRestoreButton: Bool = true

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
                        .foregroundColor(Color(hex: "#7B6FC0"))
                        .frame(width: 42, height: 42)
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
        Color.clear.frame(height: onDismiss == nil ? 2 : 52)
    }

    private var headlineSection: some View {
        Text("Get full access to your personalized guide")
            .font(.custom("Manrope", size: 30).weight(.heavy))
            .foregroundStyle(Color(hex: "#2D2575"))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
    }

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow("Your full personalized roadmap, week by week")
            featureRow("Unlimited Ask Rena — answers in seconds, not days")
            featureRow("Photo timeline tracking with side-by-side comparison")
            featureRow("Consultation prep tailored to your goals and history")
            featureRow("Procedure deep-dives with realistic recovery expectations")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 18)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("✓")
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundStyle(Color(hex: "#6F7D67"))
                .frame(width: 16, alignment: .leading)
            Text(text)
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundStyle(Color(hex: "#34322D"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func trustRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#6C63FF"))
                .frame(width: 20, height: 20)
                .background(Color(hex: "#D4CCFF"))
                .clipShape(Circle())
            Text(text)
                .font(.custom("PlusJakartaSans-SemiBold", size: 14).weight(.bold))
                .foregroundStyle(Color(hex: "#1E1B4B"))
        }
    }

    private var planSection: some View {
        VStack(spacing: 4) {
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
                    HStack(spacing: 8) {
                        Text(metadata.title)
                            .font(.custom("Outfit-Bold", size: 23))
                            .foregroundStyle(isSelected ? Color(hex: "#2D2575") : Color(hex: "#5B50D6"))

                        if tier == .yearly {
                            Text("Best Value")
                                .font(.custom("Outfit-Bold", size: 11))
                                .tracking(1.1)
                                .foregroundStyle(Color(hex: "#5B50D6"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(hex: "#D4CCFF"))
                                .clipShape(Capsule())

                            if let savings = annualSavingsLabel {
                                Text(savings)
                                    .font(.custom("Outfit-Bold", size: 11))
                                    .tracking(1.1)
                                    .foregroundStyle(Color(hex: "#3D8A4E"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color(hex: "#D4EDDA"))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let trialLabel = metadata.trialLabel {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(trialLabel)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                                .foregroundStyle(isSelected ? Color(hex: "#2D2575") : Color(hex: "#5B50D6"))
                            if let monthlyLine = metadata.trialMonthlyLine {
                                HStack(spacing: 5) {
                                    if let strikeLabel = metadata.trialMonthlyStrikeLabel {
                                        Text(strikeLabel)
                                            .strikethrough(true, color: Color(hex: "#7B6FC0").opacity(0.6))
                                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                                            .foregroundStyle(Color(hex: "#7B6FC0").opacity(0.6))
                                    }
                                    Text(monthlyLine)
                                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                                        .foregroundStyle(Color(hex: "#7B6FC0"))
                                }
                            }
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(metadata.primaryPrice)
                                .font(.custom("Manrope", size: 33).weight(.heavy))
                                .foregroundStyle(isSelected ? Color(hex: "#2D2575") : Color(hex: "#5B50D6"))

                            Text(metadata.periodLabel)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14).weight(.bold))
                                .tracking(1.0)
                                .foregroundStyle(Color(hex: "#7B6FC0"))
                        }
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "#6C63FF") : Color(hex: "#D4CCFF"))
                    .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(planBackground(isSelected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: "#8B7FF0").opacity(0.42) : Color(hex: "#6C63FF").opacity(0.10),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color.black.opacity(isSelected ? 0.05 : 0.03), radius: isSelected ? 14 : 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var annualProductHasFreeTrial: Bool {
        subscriptionStore.product(for: .yearly)?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private var annualSavingsLabel: String? {
        guard let annual = subscriptionStore.product(for: .yearly),
              let monthly = subscriptionStore.product(for: .monthly) else { return "Save 50%" }
        let annualPrice  = (annual.price  as NSDecimalNumber).doubleValue
        let monthlyPrice = (monthly.price as NSDecimalNumber).doubleValue
        let monthlyAnnualized = monthlyPrice * 12
        guard monthlyAnnualized > 0 else { return nil }
        let percent = Int(((monthlyAnnualized - annualPrice) / monthlyAnnualized * 100).rounded())
        guard percent > 0 else { return nil }
        return "Save \(percent)%"
    }

    private var ctaButtonText: String {
        if selectedTier == .yearly && annualProductHasFreeTrial {
            return "Enjoy a free week of Rena on us"
        }
        if selectedTier == .monthly {
            return "Start my recovery plan"
        }
        return "Continue with \(selectedTier.ctaTitle)"
    }

    private var ctaSection: some View {
        VStack(spacing: 0) {
            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color(hex: "#5B50D6"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 14)
            }

            VStack(alignment: .leading, spacing: 8) {
                trustRow(annualProductHasFreeTrial && selectedTier == .yearly
                    ? "7-day free trial · cancel anytime"
                    : "Cancel anytime")
                trustRow("No hidden pricing · your data stays yours")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)

            if showsPurchaseCTA {
                Button {
                    Task { await purchaseSelectedTier() }
                } label: {
                    if subscriptionStore.isPurchasing {
                        ProgressView()
                            .tint(Color(hex: "#FAF8F3"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else {
                        Text(ctaButtonText)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 20).weight(.bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
                .background(Color(hex: "#6C63FF"))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .disabled(subscriptionStore.isPurchasing || selectedProduct == nil)
            }

            VStack(spacing: 4) {
                Text(selectedPlanSummaryLine)
                    .font(.custom("Manrope", size: 18).weight(.heavy))
                    .foregroundStyle(Color(hex: "#2D2575"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)

                Text(selectedPlanBillingLine)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color(hex: "#7B6FC0"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.94),
                    Color(hex: "#F5F4FF").opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: "#6C63FF").opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
        .padding(.top, 16)
    }

    private var footerSection: some View {
        VStack(spacing: 0) {
            if let onDismiss {
                Button(action: onDismiss) {
                    Text(selectedTier == .monthly ? "Remind me later" : "Maybe later")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                        .foregroundStyle(Color(hex: "#7B6FC0"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.top, 4)
            }

            HStack(spacing: 10) {
                footerLink(title: "Terms of Use", url: AppConfig.termsOfUseURL)
                Text("•")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color(hex: "#7B6FC0"))
                footerLink(title: "Privacy Policy", url: AppConfig.privacyPolicyURL)
                if showsRestoreButton {
                    Text("•")
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundStyle(Color(hex: "#7B6FC0"))
                    Button("Restore") {
                        Task { await restorePurchases() }
                    }
                    .font(.custom("PlusJakartaSans-SemiBold", size: 13).weight(.bold))
                    .foregroundStyle(Color(hex: "#6C63FF"))
                    .disabled(subscriptionStore.isPurchasing)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, onDismiss != nil ? 4 : 14)
        }
        .padding(.bottom, 4)
    }

    private func footerLink(title: String, url: URL) -> some View {
        Link(destination: url) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 13).weight(.bold))
                .foregroundStyle(Color(hex: "#6C63FF"))
        }
    }

    private var paywallBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FAFAFF"),
                Color(hex: "#F5F4FF")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(Color(hex: "#EAE7FF"))
                .frame(width: 240, height: 240)
                .blur(radius: 24)
                .offset(x: 40, y: -110)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color(hex: "#D4CCFF"))
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: -50, y: 120)
        }
    }

    private func planBackground(isSelected: Bool) -> some ShapeStyle {
        LinearGradient(
            colors: isSelected
                ? [
                    Color(hex: "#EAE7FF").opacity(0.92),
                    Color(hex: "#F5F4FF").opacity(0.96)
                ]
                : [
                    Color.white.opacity(0.94),
                    Color(hex: "#FAFAFF").opacity(0.92)
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

            if annualProductHasFreeTrial {
                let monthlyLine = monthlyEquivalent.map { "\($0)/month" }
                let monthlyStrike = subscriptionStore.product(for: .monthly)?.displayPrice
                let summaryHeadline = monthlyEquivalent.map {
                    "7 days free, then \(displayPrice)/year · \($0)/month"
                } ?? "7 days free, then \(displayPrice)/year"
                return PlanMetadata(
                    title: "Annual Plan",
                    primaryPrice: displayPrice,
                    periodLabel: "Year",
                    summaryHeadline: summaryHeadline,
                    billingDescription: "\(displayPrice) billed once yearly. Auto-renewing.",
                    trialLabel: "7 days free, then \(displayPrice)/yr",
                    trialMonthlyLine: monthlyLine,
                    trialMonthlyStrikeLabel: monthlyStrike.map { "\($0)/mo" }
                )
            } else {
                let summaryHeadline = monthlyEquivalent.map {
                    "\(displayPrice) per year (\($0)/month)"
                } ?? "\(displayPrice) per year"
                return PlanMetadata(
                    title: "Annual Plan",
                    primaryPrice: displayPrice,
                    periodLabel: "Year",
                    summaryHeadline: summaryHeadline,
                    billingDescription: "Billed once yearly for the Annual auto-renewing subscription."
                )
            }
        default:
            return PlanMetadata(
                title: tier.displayName,
                primaryPrice: displayPrice,
                periodLabel: "",
                summaryHeadline: "\(displayPrice)",
                billingDescription: "Auto-renewing subscription."
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
        case .monthly: "$19.99"
        case .yearly: "$89.99"
        default: ""
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
            statusMessage = nil
            guard !didNotifySubscription else { return }
            didNotifySubscription = true
            onSubscribed?()
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
            let restoreError = subscriptionStore.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
            if isDismissibleRestoreMessage(restoreError) {
                statusMessage = nil
            } else {
                statusMessage = restoreError ?? "Unable to restore purchases right now."
            }
        }
    }

    private func isDismissibleRestoreMessage(_ message: String?) -> Bool {
        guard let message, !message.isEmpty else { return true }

        let normalized = message.lowercased()
        return normalized.contains("cancel")
            || normalized.contains("canceled")
            || normalized.contains("cancelled")
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
    var trialLabel: String? = nil
    var trialMonthlyLine: String? = nil
    var trialMonthlyStrikeLabel: String? = nil
}

private extension SubscriptionTier {
    static let allCases: [SubscriptionTier] = [.yearly, .monthly]

    var ctaTitle: String {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Annual"
        default: rawValue.capitalized
        }
    }
}
