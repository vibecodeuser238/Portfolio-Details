import SwiftUI

struct HoldingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isAddingHolding = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.holdings.isEmpty {
                    ContentUnavailableView("No holdings", systemImage: "briefcase", description: Text("Import positions or add manual holdings to begin."))
                } else {
                    List {
                        ForEach(viewModel.holdings) { holding in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(holding.displaySymbol)
                                        .font(.headline)
                                    Text(holding.securityType.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(holding.marketValue.currencyString)
                                        .font(.headline)
                                }
                                Text(holding.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                HStack {
                                    Text("Qty \(NSDecimalNumber(decimal: holding.quantity).stringValue)")
                                    Text("Cost \(holding.costBasis.currencyString)")
                                    Text("G/L \(holding.unrealizedGainLoss.currencyString)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Holdings")
            .toolbar {
                Button {
                    isAddingHolding = true
                } label: {
                    Label("Add Holding", systemImage: "plus")
                }
            }
            .sheet(isPresented: $isAddingHolding) {
                ManualHoldingForm()
                    .environmentObject(viewModel)
            }
        }
    }
}

private struct ManualHoldingForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var accountID: UUID?
    @State private var securityType: SecurityType = .mutualFund
    @State private var symbol = ""
    @State private var description = ""
    @State private var assetClass = "Equity"
    @State private var assetStrategy = "Manual"
    @State private var quantity = ""
    @State private var price = ""
    @State private var costBasis = ""
    @State private var sector = ""
    @State private var industry = ""
    @State private var dividendYield: Decimal?
    @State private var beta: Double?
    @State private var lookupStatus = "Enter a ticker, then validate it to fill market data."
    @State private var isLookingUpTicker = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                securitySection
                marketDataSection
                positionSection
            }
            .navigationTitle("Manual Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                accountID = accountID ?? viewModel.accounts.first(where: { $0.kind == .fourOhOneK })?.id ?? viewModel.accounts.first?.id
            }
            .onChange(of: symbol) {
                lookupStatus = "Ticker changed. Validate it to refresh market data."
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            Picker("Account", selection: Binding(
                get: { accountID ?? viewModel.accounts.first?.id ?? UUID() },
                set: { accountID = $0 }
            )) {
                ForEach(viewModel.accounts) { account in
                    Text(account.name).tag(account.id)
                }
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Picker("Type", selection: $securityType) {
                ForEach(SecurityType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            TextField("Symbol", text: $symbol)
                .autocorrectionDisabled()
            TextField("Description", text: $description)
            TextField("Asset Class", text: $assetClass)
            TextField("Strategy", text: $assetStrategy)
        }
    }

    private var marketDataSection: some View {
        Section("Market Data") {
            Button {
                Task { await validateTicker() }
            } label: {
                if isLookingUpTicker {
                    ProgressView()
                } else {
                    Label("Validate Ticker", systemImage: "checkmark.circle")
                }
            }
            .disabled(isLookingUpTicker || normalizedSymbol.isEmpty || securityType == .cash)

            Text(lookupStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Sector", text: $sector)
            TextField("Industry", text: $industry)
        }
    }

    private var positionSection: some View {
        Section("Position") {
            TextField("Quantity", text: $quantity)
            TextField("Price", text: $price)
            TextField("Cost Basis", text: $costBasis)
        }
    }

    private var canSave: Bool {
        decimal(quantity) != nil && decimal(price) != nil && decimal(costBasis) != nil
    }

    private var normalizedSymbol: String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func validateTicker() async {
        isLookingUpTicker = true
        lookupStatus = "Validating ticker..."
        defer { isLookingUpTicker = false }

        do {
            let result = try await viewModel.lookupSecurity(symbol: symbol)
            symbol = result.symbol
            if let name = result.name, !name.isEmpty {
                description = name
            } else if description.isEmpty {
                description = result.symbol
            }
            price = result.price.plainString
            if let sector = result.sector, !sector.isEmpty {
                self.sector = sector
            }
            if let industry = result.industry, !industry.isEmpty {
                self.industry = industry
            }
            beta = result.beta
            dividendYield = result.dividendYield
            lookupStatus = "Validated. Price and sector were filled from Finnhub."
        } catch {
            lookupStatus = "Could not validate this ticker."
            viewModel.alertMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let accountID = accountID ?? viewModel.accounts.first?.id,
              let quantity = decimal(quantity),
              let price = decimal(price),
              let costBasis = decimal(costBasis) else {
            return
        }
        let marketValue = quantity * price
        let holding = Holding(
            accountID: accountID,
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            description: description.isEmpty ? symbol.uppercased() : description,
            assetClass: assetClass,
            assetStrategy: assetStrategy,
            securityType: securityType,
            quantity: quantity,
            price: price,
            marketValue: marketValue,
            costBasis: costBasis,
            unrealizedGainLoss: marketValue - costBasis,
            dividendYield: dividendYield,
            beta: beta,
            sector: sector.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            industry: industry.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        viewModel.addManualHolding(holding)
        dismiss()
    }

    private func decimal(_ value: String) -> Decimal? {
        Decimal(string: value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private extension Decimal {
    var plainString: String {
        NSDecimalNumber(decimal: self).stringValue
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
