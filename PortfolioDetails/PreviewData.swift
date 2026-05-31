import Foundation

enum PreviewData {
    @MainActor
    static var viewModel: AppViewModel {
        let model = AppViewModel()
        let account = model.accounts[0]
        model.holdings = [
            Holding(accountID: account.id, symbol: "VOO", description: "Vanguard S&P 500 ETF", assetClass: "Equity", assetStrategy: "US Large Cap", securityType: .etf, quantity: 12, price: 501, marketValue: 6012, costBasis: 5200, unrealizedGainLoss: 812, dividendYield: 0.013, estimatedAnnualIncome: 78, beta: 1.0, sector: "Broad Market"),
            Holding(accountID: account.id, symbol: "JPST", description: "JPMorgan Ultra-Short Income ETF", assetClass: "Fixed Income", assetStrategy: "Investment Grade Diversified", securityType: .etf, quantity: 150, price: 50.6, marketValue: 7590, costBasis: 7610, unrealizedGainLoss: -20, dividendYield: 0.041, estimatedAnnualIncome: 311, beta: 0.1, sector: "Fixed Income"),
            Holding(accountID: account.id, symbol: "", description: "Cash", assetClass: "Cash & Money Market Funds", assetStrategy: "Money Market Funds", securityType: .cash, quantity: 1, price: 3200, marketValue: 3200, costBasis: 3200, unrealizedGainLoss: 0, dividendYield: nil, estimatedAnnualIncome: nil, beta: nil, sector: "Cash")
        ]
        return model
    }
}
