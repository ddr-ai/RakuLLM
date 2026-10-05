import Foundation

public struct GeminiProvider: LLMProvider {
    public let kind: ProviderKind = .gemini

    public init() {}

    public func buildRequestBody(request: ChatRequest) throws -> Data {
        var contents: [[String: Any]] = []

        for msg in request.messages {
            let role = msg.role == "assistant" ? "model" : "user"
            contents.append([
                "role": role,
                "parts": [["text": msg.content]]
            ])
        }

        var json: [String: Any] = ["contents": contents]

        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            json["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }

        var generationConfig: [String: Any] = [
            "maxOutputTokens": request.maxOutputTokens
        ]
        if let temp = request.temperature {
            generationConfig["temperature"] = temp
        }
        if let topP = request.topP {
            generationConfig["topP"] = topP
        }
        if let stop = request.stopSequences, !stop.isEmpty {
            generationConfig["stopSequences"] = stop
        }
        json["generationConfig"] = generationConfig

        if let tools = request.tools, !tools.isEmpty {
            var functionDeclarations: [[String: Any]] = []
            for tool in tools {
                var decl: [String: Any] = [
                    "name": tool.name,
                    "description": tool.description
                ]
                if let schemaData = tool.inputSchemaJSON.data(using: .utf8),
                   let schemaObj = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
                    decl["parameters"] = schemaObj
                }
                functionDeclarations.append(decl)
            }
            json["tools"] = [["functionDeclarations": functionDeclarations]]
        }

        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    public func stream(request: ChatRequest, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.isEmpty else {
                        throw ProviderError.missingAPIKey(.gemini)
                    }

                    let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(request.model):streamGenerateContent?alt=sse"
                    guard let url = URL(string: urlString) else {
                        throw ProviderError.invalidURL
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try buildRequestBody(request: request)

                    let (byteStream, response) = try await URLSession.shared.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ProviderError.httpError(statusCode: -1, responseBody: "Not HTTP response")
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorBody = ""
                        for try await byte in byteStream {
                            if errorBody.count < 4096 {
                                errorBody.append(Character(UnicodeScalar(byte)))
                            }
                        }
                        throw ProviderError.httpError(statusCode: httpResponse.statusCode, responseBody: errorBody)
                    }

                    let codec = SSECodec()
                    var buffer = Data()

                    for try await byte in byteStream {
                        buffer.append(byte)
                        if byte == 0x0A { // Process line by line
                            let messages = try codec.append(chunk: buffer)
                            buffer.removeAll()

                            for msg in messages {
                                guard let data = msg.data.data(using: .utf8) else { continue }
                                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                                if let candidates = json["candidates"] as? [[String: Any]],
                                   let firstCandidate = candidates.first,
                                   let content = firstCandidate["content"] as? [String: Any],
                                   let parts = content["parts"] as? [[String: Any]] {
                                    for part in parts {
                                        if let text = part["text"] as? String {
                                            continuation.yield(.textDelta(text))
                                        }
                                        if let thought = part["thought"] as? String {
                                            continuation.yield(.thinking(thought))
                                        }
                                    }
                                }

                                if let usageMeta = json["usageMetadata"] as? [String: Any] {
                                    let prompt = usageMeta["promptTokenCount"] as? Int ?? 0
                                    let candidatesCount = usageMeta["candidatesTokenCount"] as? Int ?? 0
                                    let cached = usageMeta["cachedContentTokenCount"] as? Int ?? 0
                                    continuation.yield(.usage(Usage(
                                        inputTokens: prompt,
                                        outputTokens: candidatesCount,
                                        cachedInputTokens: cached,
                                        reasoningTokens: 0
                                    )))
                                }
                            }
                        }
                    }

                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
