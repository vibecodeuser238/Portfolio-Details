import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                accountPicker

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Import Chase Positions CSV", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                previewList
            }
            .padding()
            .navigationTitle("Import")
            .toolbar {
                Button("Save Import") {
                    viewModel.commitImport()
                }
                .disabled(viewModel.importPreview.compactMap(\.holding).isEmpty)
            }
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.commaSeparatedText, .plainText, .data]) { result in
                do {
                    let url = try result.get()
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: url)
                    viewModel.previewChaseCSV(data: data)
                } catch {
                    viewModel.alertMessage = error.localizedDescription
                }
            }
        }
    }

    private var accountPicker: some View {
        Picker("Import Into", selection: Binding(
            get: { viewModel.selectedAccountID ?? viewModel.accounts[0].id },
            set: { viewModel.selectedAccountID = $0 }
        )) {
            ForEach(viewModel.accounts) { account in
                Text(account.name).tag(account.id)
            }
        }
        .pickerStyle(.menu)
    }

    private var previewList: some View {
        Group {
            if viewModel.importPreview.isEmpty {
                ContentUnavailableView("Choose a CSV", systemImage: "doc.text", description: Text("The app will preview Chase positions before saving them."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.importPreview) { row in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.holding?.displaySymbol ?? "Row \(row.rowNumber)")
                                .font(.headline)
                            Text(row.holding?.description ?? row.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(row.status.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: row.status))
                    }
                }
            }
        }
    }

    private func color(for status: ImportPreviewRow.Status) -> Color {
        switch status {
        case .ready: .green
        case .needsReview: .orange
        case .cashOrManual: .blue
        case .ignored: .secondary
        }
    }
}
