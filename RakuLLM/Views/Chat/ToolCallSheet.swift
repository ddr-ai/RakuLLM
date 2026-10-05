import SwiftUI

public struct ToolCallSheet: View {
    public let serverName: String
    public let toolName: String
    public let argumentsJSON: String
    public let isDestructive: Bool
    public let onApprove: (Bool) -> Void // Bool: remember choice
    public let onDeny: () -> Void

    @State private var rememberChoice: Bool = false

    public init(
        serverName: String,
        toolName: String,
        argumentsJSON: String,
        isDestructive: Bool = false,
        onApprove: @escaping (Bool) -> Void,
        onDeny: @escaping () -> Void
    ) {
        self.serverName = serverName
        self.toolName = toolName
        self.argumentsJSON = argumentsJSON
        self.isDestructive = isDestructive
        self.onApprove = onApprove
        self.onDeny = onDeny
    }

    public var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if isDestructive {
                    StatusBannerView(
                        icon: "exclamationmark.triangle.fill",
                        message: "This tool performs a destructive action. Review the arguments carefully.",
                        color: RakuTheme.Color.danger
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("MCP SERVER")
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(RakuTheme.Color.subtle)
                    Text(serverName)
                        .font(RakuTheme.Font.headline())
                        .foregroundColor(RakuTheme.Color.fg)
                }
                .rakuCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("TOOL NAME")
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(RakuTheme.Color.subtle)
                    Text(toolName)
                        .font(RakuTheme.Font.headline())
                        .foregroundColor(RakuTheme.Color.accent)
                }
                .rakuCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("EXACT ARGUMENTS")
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(RakuTheme.Color.subtle)
                    ScrollView {
                        Text(argumentsJSON)
                            .font(RakuTheme.Font.code(size: 13))
                            .foregroundColor(RakuTheme.Color.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                }
                .rakuCard()

                Toggle("Remember decision for this tool", isOn: $rememberChoice)
                    .font(RakuTheme.Font.body())
                    .foregroundColor(RakuTheme.Color.fg)
                    .tint(RakuTheme.Color.ok)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: onDeny) {
                        Text("Deny")
                            .font(RakuTheme.Font.headline())
                            .foregroundColor(RakuTheme.Color.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RakuTheme.Color.elevated)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(RakuTheme.Color.line))
                    }

                    Button(action: { onApprove(rememberChoice) }) {
                        Text("Approve & Run")
                            .font(RakuTheme.Font.headline())
                            .foregroundColor(RakuTheme.Color.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isDestructive ? RakuTheme.Color.danger : RakuTheme.Color.ok)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(16)
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .navigationTitle("Tool Call Approval")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
