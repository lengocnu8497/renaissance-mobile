//
//  DiscountOfferView.swift
//  Renaissance Mobile
//
//  Shown after the user taps "Maybe later" on the main paywall.
//  Offers 50% off the first month via a StoreKit 2 promotional offer.
//  If declined, the user continues on the 3-questions/month free tier.
//

import SwiftUI
import StoreKit
import Supabase

struct DiscountOfferView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    let onSubscribed: () -> Void
    let onSkip: () -> Void

    @State private var statusMessage: String?
    @State private var isLoadingOffer = false
    @State private var didNotifySubscription = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    badgeSection
                    headlineSection
                    LottieView(name: "gift-box", loop: true)
                        .frame(height: 208)
                        .padding(.bottom, 8)
                    offerCard
                    ctaSection
                    skipButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 17)
                .padding(.bottom, 36)
            }

            Button(action: onSkip) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#7B6FC0"))
                    .frame(width: 42, height: 42)
            }
            .padding(.top, 12)
            .padding(.trailing, 14)
        }
        .background(background.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            guard subscriptionStore.hasActiveSubscription, !didNotifySubscription else { return }
            didNotifySubscription = true
            onSubscribed()
        }
    }

    // MARK: - Sections

    private var badgeSection: some View {
        Text("SPECIAL OFFER")
            .font(.custom("Outfit-Bold", size: 11))
            .tracking(2)
            .foregroundStyle(Color(hex: "#5B50D6"))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(hex: "#D4CCFF"))
            .clipShape(Capsule())
            .padding(.bottom, 18)
    }

    private var headlineSection: some View {
        VStack(spacing: 10) {
            Text("Wait — here's a gift\njust for you")
                .font(.custom("Manrope", size: 30).weight(.heavy))
                .foregroundStyle(Color(hex: "#2D2575"))
                .multilineTextAlignment(.center)

            Text("Get your first month at half price.\nNo commitment — cancel anytime.")
                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                .foregroundStyle(Color(hex: "#7B6FC0"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 21)
    }

    private var offerCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("50% off")
                    .font(.custom("Manrope", size: 40).weight(.heavy))
                    .foregroundStyle(Color(hex: "#6C63FF"))

                if let monthlyProduct = subscriptionStore.product(for: .monthly) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(monthlyProduct.displayPrice)
                                .strikethrough(true, color: Color(hex: "#7B6FC0").opacity(0.5))
                                .font(.custom("PlusJakartaSans-Regular", size: 16))
                                .foregroundStyle(Color(hex: "#7B6FC0").opacity(0.5))
                            Text("→")
                                .foregroundStyle(Color(hex: "#7B6FC0"))
                                .font(.system(size: 14))
                            Text(halfPrice(of: monthlyProduct))
                                .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                                .foregroundStyle(Color(hex: "#2D2575"))
                        }
                        Text("for your first month")
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundStyle(Color(hex: "#7B6FC0"))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("$9.99 your first month")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                            .foregroundStyle(Color(hex: "#2D2575"))
                        Text("then regular price")
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundStyle(Color(hex: "#7B6FC0"))
                    }
                }
            }

            Divider().background(Color(hex: "#6C63FF").opacity(0.12))

            VStack(alignment: .leading, spacing: 8) {
                offerFeatureRow("Unlimited Ask Rena this month")
                offerFeatureRow("Full recovery roadmap unlocked")
                offerFeatureRow("Photo timeline with side-by-side")
                offerFeatureRow("Cancel before month 2, owe nothing")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "#EAE7FF").opacity(0.6), Color(hex: "#F5F4FF").opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(hex: "#8B7FF0").opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 6)
        .padding(.bottom, 24)
    }

    private func offerFeatureRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "#6C63FF"))
                .frame(width: 18, height: 18)
                .background(Color(hex: "#D4CCFF"))
                .clipShape(Circle())
            Text(text)
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundStyle(Color(hex: "#34322D"))
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color(hex: "#5B50D6"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                Task { await claimOffer() }
            } label: {
                Group {
                    if subscriptionStore.isPurchasing || isLoadingOffer {
                        ProgressView()
                            .tint(Color(hex: "#FAF8F3"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else {
                        Text("Claim 50% off — first month")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 19).weight(.bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
            }
            .background(Color(hex: "#6C63FF"))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .disabled(subscriptionStore.isPurchasing || isLoadingOffer)
            .shadow(color: Color(hex: "#6C63FF").opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .padding(.bottom, 6)
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Text("No thanks, I'll stick with 3 free questions/month")
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundStyle(Color(hex: "#7B6FC0"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [Color(hex: "#FAFAFF"), Color(hex: "#F5F4FF")],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(Color(hex: "#EAE7FF"))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: 60, y: -120)
        }
    }

    // MARK: - Purchase

    @MainActor
    private func claimOffer() async {
        statusMessage = nil
        isLoadingOffer = true
        defer { isLoadingOffer = false }

        // Fetch the promo offer signature from the backend.
        let sig: PromoOfferSignature
        do {
            sig = try await fetchPromoSignature()
        } catch {
            statusMessage = "Couldn't load offer right now. Try again."
            return
        }

        let result = await subscriptionStore.purchaseWithPromoOffer(
            offerID: AppConfig.promoOfferMonthlyHalfOff,
            keyID: sig.keyID,
            nonce: sig.nonce,
            signature: sig.signature,
            timestamp: sig.timestamp
        )

        switch result {
        case .success:
            statusMessage = nil
        case .pending:
            statusMessage = "Your App Store purchase is pending approval."
        case .cancelled:
            statusMessage = nil
        case .failed(let message):
            statusMessage = message
        }
    }

    // MARK: - Backend signature fetch

    private struct PromoOfferSignature {
        let keyID: String
        let nonce: UUID
        let signature: Data
        let timestamp: Int
    }

    private func fetchPromoSignature() async throws -> PromoOfferSignature {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/functions/v1/generate-promo-signature") else {
            throw URLError(.badURL)
        }

        let session = try await supabase.auth.session
        let userID = session.user.id.uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "product_id": AppConfig.appStoreMonthlyProductId,
            "offer_id": AppConfig.promoOfferMonthlyHalfOff,
            "user_id": userID
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONDecoder().decode(PromoSignatureResponse.self, from: data)
        guard let nonce = UUID(uuidString: json.nonce),
              let sigData = Data(base64Encoded: json.signature) else {
            throw URLError(.cannotParseResponse)
        }

        return PromoOfferSignature(
            keyID: json.keyID,
            nonce: nonce,
            signature: sigData,
            timestamp: json.timestamp
        )
    }

    private struct PromoSignatureResponse: Decodable {
        let keyID: String
        let nonce: String
        let signature: String
        let timestamp: Int

        enum CodingKeys: String, CodingKey {
            case keyID = "key_id"
            case nonce
            case signature
            case timestamp
        }
    }

    // MARK: - Helpers

    private func halfPrice(of product: Product) -> String {
        let half = product.price / 2
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        return formatter.string(from: half as NSDecimalNumber) ?? "50% off"
    }
}
