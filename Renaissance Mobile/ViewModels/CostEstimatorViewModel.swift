//
//  CostEstimatorViewModel.swift
//  Renaissance Mobile
//

import Foundation
import Observation

@Observable
class CostEstimatorViewModel {

    // MARK: - State

    var selectedPricingId: String? {
        didSet { recalculate() }
    }

    var region: PricingRegion = .nationalAverage {
        didSet { recalculate() }
    }

    var sessionCount: Int = 1 {
        didSet { recalculate() }
    }

    var showResult = false

    // Computed result
    private(set) var result: CostEstimateResult?

    // MARK: - Selected Pricing

    var selectedPricing: ProcedurePricing? {
        guard let id = selectedPricingId else { return nil }
        return ProcedurePricingData.pricing(for: id)
    }

    // MARK: - Init

    init(zipCode: String? = nil) {
        if let zip = zipCode, !zip.isEmpty {
            region = PricingRegion.infer(fromZip: zip)
        }
    }

    // MARK: - Select Procedure

    func selectProcedure(_ pricing: ProcedurePricing) {
        selectedPricingId = pricing.id
        sessionCount = pricing.typicalSessions
    }

    // MARK: - Calculate

    private func recalculate() {
        guard let pricing = selectedPricing else {
            result = nil
            return
        }

        let m = region.multiplier
        let sessions = max(1, sessionCount)

        result = CostEstimateResult(
            procedure: pricing,
            region: region,
            sessionCount: sessions,
            lowTotal:  Int(Double(pricing.lowPrice  * sessions) * m),
            avgTotal:  Int(Double(pricing.avgPrice  * sessions) * m),
            highTotal: Int(Double(pricing.highPrice * sessions) * m)
        )
    }

    func calculate() {
        recalculate()
        if result != nil {
            showResult = true
        }
    }

    // MARK: - Helpers

    var canCalculate: Bool {
        selectedPricingId != nil
    }

    func formattedPrice(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Result Model

struct CostEstimateResult {
    let procedure: ProcedurePricing
    let region: PricingRegion
    let sessionCount: Int
    let lowTotal: Int
    let avgTotal: Int
    let highTotal: Int

    var rangeText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        let low  = formatter.string(from: NSNumber(value: lowTotal))  ?? "$\(lowTotal)"
        let high = formatter.string(from: NSNumber(value: highTotal)) ?? "$\(highTotal)"
        return "\(low) – \(high)"
    }

    var avgText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: avgTotal)) ?? "$\(avgTotal)"
    }
}
