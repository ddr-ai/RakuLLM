import SwiftUI

public struct PersonasView: View {
    @State private var personas: [Persona] = Persona.allBuiltIns

    public init() {}

    public var body: some View {
        List {
            Section(header: Text("Personas & System Prompts").foregroundColor(RakuTheme.Color.subtle)) {
                ForEach(personas) { persona in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: persona.icon)
                                .foregroundColor(RakuTheme.Color.accent)
                            Text(persona.name)
                                .font(RakuTheme.Font.headline())
                                .foregroundColor(RakuTheme.Color.fg)
                            Spacer()
                            if persona.isBuiltIn {
                                Text("Built-in")
                                    .font(RakuTheme.Font.footnote())
                                    .foregroundColor(RakuTheme.Color.subtle)
                            }
                        }

                        Text(persona.systemPrompt)
                            .font(RakuTheme.Font.subheadline())
                            .foregroundColor(RakuTheme.Color.muted)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(RakuTheme.Color.elevated)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
        .navigationTitle("Personas")
    }
}
