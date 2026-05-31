import Foundation

struct PortfolioAnalytics {
    struct Allocation: Identifiable {
        var id: String { name }
        let name: String
        let value: Decimal
        let weight: Decimal
    }

    let holdings: [Holding]

    var totalValue: Decimal {
        holdings.reduce(0) { $0 + $1.marketValue }
    }

    var totalCost: Decimal {
        holdings.reduce(0) { $0 + $1.costBasis }
    }

    var unrealizedGainLoss: Decimal {
        holdings.reduce(0) { $0 + $1.unrealizedGainLoss }
    }

    var unrealizedGainLossPercent: Decimal {
        guard totalCost != 0 else { return 0 }
        return unrealizedGainLoss / totalCost
    }

    var portfolioBeta: Double? {
        let weighted = holdings.compactMap { holding -> (Double, Double)? in
            guard let beta = holding.beta, totalValue > 0 else { return nil }
            return (beta, double(holding.marketValue / totalValue))
        }
        guard !weighted.isEmpty else { return nil }
        return weighted.reduce(0) { $0 + $1.0 * $1.1 }
    }

    var topConcentration: Allocation? {
        allocation(groupedBy: { $0.displaySymbol }).first
    }

    var assetAllocation: [Allocation] {
        allocation(groupedBy: { $0.assetClass.isEmpty ? $0.securityType.rawValue : $0.assetClass })
    }

    var sectorAllocation: [Allocation] {
        allocation(groupedBy: { holding in
            holding.sector ?? (holding.assetStrategy.isEmpty ? "Unclassified" : holding.assetStrategy)
        })
    }

    var positionAllocation: [Allocation] {
        allocation(groupedBy: { $0.displaySymbol })
    }

    private func allocation(groupedBy key: (Holding) -> String) -> [Allocation] {
        let grouped = Dictionary(grouping: holdings, by: key)
        return grouped.map { name, holdings in
            let value = holdings.reduce(0) { $0 + $1.marketValue }
            let weight = totalValue == 0 ? 0 : value / totalValue
            return Allocation(name: name, value: value, weight: weight)
        }
        .sorted { $0.value > $1.value }
    }

    private func double(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}

extension Decimal {
    var currencyString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$0"
    }

    var percentString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0%"
    }
}
