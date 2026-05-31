import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            #if os(macOS)
            macOSSettings
                .navigationTitle("Settings")
            #else
            Form {
                finnhubFormSection
                accountsFormSection
            }
            .navigationTitle("Settings")
            #endif
        }
    }

    private var finnhubFormSection: some View {
        Section("Finnhub") {
            apiKeyField
            statusRow
            validateButton
        }
    }

    private var accountsFormSection: some View {
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

    private var apiKeyField: some View {
        SecureField("API Key", text: Binding(
            get: { viewModel.apiKeyInput },
            set: { viewModel.apiKeyInput = $0 }
        ))
    }

    private var statusRow: some View {
        HStack {
            Text("Status")
            Spacer()
            Text(viewModel.apiKeyStatus)
                .foregroundStyle(statusColor)
        }
    }

    private var validateButton: some View {
        Button {
            Task { await viewModel.validateAPIKey() }
        } label: {
            Label("Validate Key", systemImage: "checkmark.shield")
        }
    }

    #if os(macOS)
    private var macOSSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(.largeTitle.weight(.semibold))
                    Text("Manage market data access and portfolio accounts.")
                        .foregroundStyle(.secondary)
                }

                settingsPanel(title: "Finnhub", systemImage: "key.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledContent("API Key") {
                            apiKeyField
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 420)
                        }

                        LabeledContent("Status") {
                            Text(viewModel.apiKeyStatus)
                                .foregroundStyle(statusColor)
                        }

                        HStack {
                            Spacer()
                            validateButton
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                settingsPanel(title: "Accounts", systemImage: "wallet.pass.fill") {
                    VStack(spacing: 0) {
                        ForEach(viewModel.accounts) { account in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(account.name)
                                        .font(.headline)
                                    Text(account.kind.rawValue)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)

                            if account.id != viewModel.accounts.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsPanel<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))

            content()
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.55))
        }
    }
    #endif

    private var statusColor: Color {
        switch viewModel.apiKeyStatus {
        case "Valid": .green
        case "Invalid": .red
        default: .secondary
        }
    }
}
