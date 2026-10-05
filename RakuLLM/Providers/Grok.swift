import Foundation

public final class GrokProvider: OpenAIProvider {
    override public var kind: ProviderKind { .grok }

    public init() {
        super.init(endpointURL: "https://api.x.ai/v1/chat/completions")
    }
}
