import Foundation

enum AccountKind: String, CaseIterable, Identifiable, Codable {
    case taxable = "Taxable"
    case traditionalIRA = "Traditional IRA"
    case rothIRA = "Roth IRA"
    case fourOhOneK = "401(k)"
    case hsa = "HSA"
    case cash = "Cash"

    var id: String { rawValue }
}

enum SecurityType: String, CaseIterable, Identifiable, Codable {
    case stock = "Stock"
    case etf = "ETF"
    case mutualFund = "Mutual Fund"
    case moneyMarket = "Money Market"
    case cash = "Cash"
    case unknown = "Unknown"

    var id: String { rawValue }
}

struct PortfolioAccount: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var kind: AccountKind
}

struct Holding: Identifiable, Hashable, Codable {
    var id = UUID()
    var accountID: UUID
    var symbol: String
    var description: String
    var cusip: String?
    var isin: String?
    var assetClass: String
    var assetStrategy: String
    var securityType: SecurityType
    var quantity: Decimal
    var price: Decimal
    var marketValue: Decimal
    var costBasis: Decimal
    var unrealizedGainLoss: Decimal
    var dividendYield: Decimal?
    var estimatedAnnualIncome: Decimal?
    var beta: Double?
    var sector: String?
    var industry: String?
    var pricingDate: Date?
    var acquisitionDate: Date?

    var displaySymbol: String {
        symbol.isEmpty ? "Cash" : symbol
    }

    var gainLossPercent: Decimal {
        guard costBasis != 0 else { return 0 }
        return unrealizedGainLoss / costBasis
    }
}

struct FinnhubQuote: Decodable {
    let current: Double
    let change: Double
    let percentChange: Double
    let high: Double
    let low: Double
    let open: Double
    let previousClose: Double
    let timestamp: TimeInterval

    enum CodingKeys: String, CodingKey {
        case current = "c"
        case change = "d"
        case percentChange = "dp"
        case high = "h"
        case low = "l"
        case open = "o"
        case previousClose = "pc"
        case timestamp = "t"
    }
}

struct FinnhubProfile: Decodable {
    let name: String?
    let ticker: String?
    let finnhubIndustry: String?
    let exchange: String?
    let currency: String?
}

struct FinnhubMetricResponse: Decodable {
    let metric: [String: Double]
}

struct SecurityLookupResult {
    let symbol: String
    let name: String?
    let price: Decimal
    let sector: String?
    let industry: String?
    let beta: Double?
    let dividendYield: Decimal?
}

struct ImportPreviewRow: Identifiable, Hashable {
    enum Status: String {
        case ready = "Ready"
        case needsReview = "Needs Review"
        case cashOrManual = "Cash/Manual"
        case ignored = "Ignored"
    }

    var id = UUID()
    var rowNumber: Int
    var status: Status
    var holding: Holding?
    var message: String
}
