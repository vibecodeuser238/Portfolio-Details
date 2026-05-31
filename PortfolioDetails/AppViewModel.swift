import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var accounts: [PortfolioAccount] = [
        PortfolioAccount(name: "Chase Brokerage", kind: .taxable),
        PortfolioAccount(name: "Manual 401(k)", kind: .fourOhOneK)
    ]
    @Published var selectedAccountID: UUID?
    @Published var holdings: [Holding] = []
    @Published var importPreview: [ImportPreviewRow] = []
    @Published var apiKeyInput = ""
    @Published var apiKeyStatus = "Not validated"
    @Published var isLoading = false
    @Published var alertMessage: String?

    private let keychain = KeychainStore()
    private let keychainAccount = "FinnhubAPIKey"
    private let portfolioFileName = "PortfolioDetails.json"

    var selectedAccount: PortfolioAccount {
        if let selectedAccountID, let account = accounts.first(where: { $0.id == selectedAccountID }) {
            return account
        }
        return accounts[0]
    }

    var analytics: PortfolioAnalytics {
        PortfolioAnalytics(holdings: holdings)
    }

    init() {
        selectedAccountID = accounts.first?.id
        loadPortfolio()
        loadAPIKey()
    }

    func loadAPIKey() {
        do {
            apiKeyInput = try keychain.read(keychainAccount) ?? loadDevelopmentKey()
            apiKeyStatus = apiKeyInput.isEmpty ? "Not set" : "Saved locally"
        } catch {
            apiKeyStatus = "Could not read Keychain"
        }
    }

    func saveAPIKey() {
        do {
            try keychain.save(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines), account: keychainAccount)
            apiKeyStatus = "Saved locally"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func validateAPIKey() async {
        saveAPIKey()
        isLoading = true
        defer { isLoading = false }
        do {
            let client = FinnhubClient(apiKey: apiKeyInput)
            apiKeyStatus = try await client.validateKey() ? "Valid" : "Could not validate"
        } catch {
            apiKeyStatus = "Invalid"
            alertMessage = error.localizedDescription
        }
    }

    func previewChaseCSV(data: Data) {
        do {
            importPreview = try ChaseCSVImporter().preview(data: data, account: selectedAccount)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func commitImport() {
        let imported = importPreview.compactMap(\.holding)
        holdings.removeAll { $0.accountID == selectedAccount.id }
        holdings.append(contentsOf: imported)
        savePortfolio()
    }

    func addManualHolding(_ holding: Holding) {
        holdings.append(holding)
        savePortfolio()
    }

    func refreshMarketData() async {
        guard !apiKeyInput.isEmpty else {
            alertMessage = "Add a Finnhub API key first."
            return
        }
        isLoading = true
        defer { isLoading = false }
        var updated = holdings
        let client = FinnhubClient(apiKey: apiKeyInput)

        for index in updated.indices {
            let symbol = updated[index].symbol
            guard !symbol.isEmpty, updated[index].securityType != .cash else { continue }
            do {
                async let quote = client.quote(for: symbol)
                async let profile = client.profile(for: symbol)
                async let metrics = client.metrics(for: symbol)
                let result = try await (quote, profile, metrics)
                updated[index].price = Decimal(result.0.current)
                updated[index].marketValue = updated[index].quantity * updated[index].price
                updated[index].sector = result.1.finnhubIndustry
                updated[index].industry = result.1.finnhubIndustry
                updated[index].beta = result.2.metric["beta"]
            } catch {
                continue
            }
        }
        holdings = updated
        savePortfolio()
    }

    private func loadDevelopmentKey() -> String {
        guard let url = Bundle.main.url(forResource: ".env", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
            .split(separator: "\n")
            .first { $0.hasPrefix("FINNHUB_API_KEY=") }?
            .split(separator: "=", maxSplits: 1)
            .last
            .map(String.init) ?? ""
    }

    private func loadPortfolio() {
        guard let url = portfolioURL(),
              let data = try? Data(contentsOf: url),
              let portfolio = try? JSONDecoder().decode(StoredPortfolio.self, from: data) else {
            return
        }
        accounts = portfolio.accounts.isEmpty ? accounts : portfolio.accounts
        holdings = portfolio.holdings
        selectedAccountID = portfolio.selectedAccountID ?? accounts.first?.id
    }

    private func savePortfolio() {
        guard let url = portfolioURL() else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let portfolio = StoredPortfolio(accounts: accounts, holdings: holdings, selectedAccountID: selectedAccountID)
            let data = try JSONEncoder().encode(portfolio)
            try data.write(to: url, options: .atomic)
        } catch {
            alertMessage = "Could not save portfolio locally."
        }
    }

    private func portfolioURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PortfolioDetails", isDirectory: true)
            .appendingPathComponent(portfolioFileName)
    }
}

private struct StoredPortfolio: Codable {
    var accounts: [PortfolioAccount]
    var holdings: [Holding]
    var selectedAccountID: UUID?
}
