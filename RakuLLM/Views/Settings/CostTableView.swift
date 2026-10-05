import SwiftUI

public struct CostTableView: View {
    @ObservedObject public var costTable: CostTable

    public init(costTable: CostTable = CostTable.shared) {
        self.costTable = costTable
    }

    public var body: some View {
        List {
            Section(
                header: Text("Pricing Map (USD per Million Tokens)").foregroundColor(RakuTheme.Color.subtle),
                footer: Text("Effective date: \(costTable.effectiveDate). Prices can be customized when provider rates update.").foregroundColor(RakuTheme.Color.subtle)
            ) {
                ForEach(costTable.pricingMap.keys.sorted(), id: \.self) { model in
                    let pricing = costTable.pricingMap[model]!
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model)
                            .font(RakuTheme.Font.headline())
                            .foregroundColor(RakuTheme.Color.fg)

                        HStack(spacing: 12) {
                            Text("Input: $\(String(format: "%.2f", pricing.promptPerMillion))/M")
                            Text("Output: $\(String(format: "%.2f", pricing.completionPerMillion))/M")
                            if pricing.cachedPromptPerMillion > 0 {
                                Text("Cached: $\(String(format: "%.3f", pricing.cachedPromptPerMillion))/M")
                            }
                        }
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(RakuTheme.Color.muted)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(RakuTheme.Color.elevated)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
        .navigationTitle("Token Cost Rates")
    }
}
