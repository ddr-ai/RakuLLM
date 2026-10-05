import SwiftUI

public struct MetricChipView: View {
    public let message: Message

    public init(message: Message) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Token count chip
            if message.tokensIn > 0 || message.tokensOut > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "number")
                        .font(.system(size: 9))
                    Text("\(message.tokensIn)→\(message.tokensOut)")
                        .font(RakuTheme.Font.footnote())
                    if message.isUsageEstimated {
                        Text("est")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(RakuTheme.Color.subtle)
                    }
                }
                .foregroundColor(RakuTheme.Color.muted)
            }

            // Speed (TTPS) chip
            if message.ttps > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 9))
                    Text(String(format: "%.1f t/s", message.ttps))
                        .font(RakuTheme.Font.footnote())
                }
                .foregroundColor(RakuTheme.Color.muted)
            }

            // Latency (firstTokenMs)
            if message.firstTokenMs > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "bolt")
                        .font(.system(size: 9))
                    Text(String(format: "%.0fms", message.firstTokenMs))
                        .font(RakuTheme.Font.footnote())
                }
                .foregroundColor(RakuTheme.Color.muted)
            }

            // Cost USD chip
            if message.costUSD > 0 {
                HStack(spacing: 2) {
                    Text("$")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.4f", message.costUSD))
                        .font(RakuTheme.Font.footnote())
                }
                .foregroundColor(RakuTheme.Color.ok)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RakuTheme.Color.canvas)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(RakuTheme.Color.line, lineWidth: 0.5)
        )
    }
}
