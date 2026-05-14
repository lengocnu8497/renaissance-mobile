//
//  OnboardingTeaserViewModel.swift
//  Renaissance Mobile
//

import Foundation

@MainActor
@Observable
final class OnboardingTeaserViewModel {
    var content: OnboardingTeaserContent?
    var isLoading = false
    var errorMessage: String?

    private let service: OnboardingTeaserService

    init(service: OnboardingTeaserService = OnboardingTeaserService()) {
        self.service = service
    }

    func load(request: OnboardingTeaserRequest) async {
        guard content == nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            content = try await service.generate(request: request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
