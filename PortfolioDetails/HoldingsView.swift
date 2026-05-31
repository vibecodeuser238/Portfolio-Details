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

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Security") {
                    Picker("Type", selection: $securityType) {
                        ForEach(SecurityType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("Symbol", text: $symbol)
                    TextField("Description", text: $description)
                    TextField("Asset Class", text: $assetClass)
                    TextField("Strategy", text: $assetStrategy)
                }

                Section("Position") {
                    TextField("Quantity", text: $quantity)
                    TextField("Price", text: $price)
                    TextField("Cost Basis", text: $costBasis)
                }
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
        }
    }

    private var canSave: Bool {
        decimal(quantity) != nil && decimal(price) != nil && decimal(costBasis) != nil
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
            unrealizedGainLoss: marketValue - costBasis
        )
        viewModel.addManualHolding(holding)
        dismiss()
    }

    private func decimal(_ value: String) -> Decimal? {
        Decimal(string: value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
