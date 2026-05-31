import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Finnhub") {
                    SecureField("API Key", text: Binding(
                        get: { viewModel.apiKeyInput },
                        set: { viewModel.apiKeyInput = $0 }
                    ))
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(viewModel.apiKeyStatus)
                            .foregroundStyle(statusColor)
                    }
                    Button {
                        Task { await viewModel.validateAPIKey() }
                    } label: {
                        Label("Validate Key", systemImage: "checkmark.shield")
                    }
                }

                Section("Accounts") {
                    ForEach(viewModel.accounts) { account in
                        HStack {
                            Text(account.name)
                            Spacer()
                            Text(account.kind.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var statusColor: Color {
        switch viewModel.apiKeyStatus {
        case "Valid": .green
        case "Invalid": .red
        default: .secondary
        }
    }
}
