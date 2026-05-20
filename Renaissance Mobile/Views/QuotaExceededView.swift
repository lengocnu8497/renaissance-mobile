//
//  QuotaExceededView.swift
//  Renaissance Mobile
//
//  Minimal StoreKit paywall shown when a premium feature is locked.
//

import SwiftUI

struct QuotaExceededView: View {
    let onDismiss: () -> Void
    var onMaybeLater: (() -> Void)? = nil
    let onSubscribed: () -> Void

    var body: some View {
        SubscriptionPaywallView(
            onDismiss: onDismiss,
            onMaybeLater: onMaybeLater,
            onSubscribed: onSubscribed
        )
    }
}

#Preview {
    QuotaExceededView(
        onDismiss: {},
        onSubscribed: {}
    )
}
