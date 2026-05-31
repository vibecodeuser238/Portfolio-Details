import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryGrid
                    allocationSection("Asset Class", allocations: viewModel.analytics.assetAllocation)
                    allocationSection("Sector / Strategy", allocations: viewModel.analytics.sectorAllocation)
                    allocationSection("Top Positions", allocations: Array(viewModel.analytics.positionAllocation.prefix(8)))
                }
                .padding()
            }
            .navigationTitle("Portfolio")
            .toolbar {
                Button {
                    Task { await viewModel.refreshMarketData() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading || viewModel.holdings.isEmpty)
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            MetricTile(title: "Total Value", value: viewModel.analytics.totalValue.currencyString)
            MetricTile(title: "Unrealized G/L", value: viewModel.analytics.unrealizedGainLoss.currencyString, detail: viewModel.analytics.unrealizedGainLossPercent.percentString)
            MetricTile(title: "Portfolio Beta", value: viewModel.analytics.portfolioBeta.map { String(format: "%.2f", $0) } ?? "N/A")
            MetricTile(title: "Top Position", value: viewModel.analytics.topConcentration?.name ?? "N/A", detail: viewModel.analytics.topConcentration?.weight.percentString)
        }
    }

    private func allocationSection(_ title: String, allocations: [PortfolioAnalytics.Allocation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            if allocations.isEmpty {
                ContentUnavailableView("No holdings yet", systemImage: "tray", description: Text("Import a Chase positions CSV to populate this view."))
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(allocations) { item in
                    SectorMark(
                        angle: .value("Value", NSDecimalNumber(decimal: item.value).doubleValue),
                        innerRadius: .ratio(0.55)
                    )
                    .foregroundStyle(by: .value("Name", item.name))
                }
                .frame(height: 220)

                VStack(spacing: 8) {
                    ForEach(allocations.prefix(6)) { item in
                        HStack {
                            Text(item.name)
                                .lineLimit(1)
                            Spacer()
                            Text(item.value.currencyString)
                                .foregroundStyle(.secondary)
                            Text(item.weight.percentString)
                                .frame(width: 64, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}
