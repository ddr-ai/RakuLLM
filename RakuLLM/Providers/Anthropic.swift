import Foundation

public struct AnthropicProvider: LLMProvider {
    public let kind: ProviderKind = .anthropic

    public init() {}

    public func buildRequestBody(request: ChatRequest) throws -> Data {
        var messages: [[String: Any]] = []

        for msg in request.messages {
            // Anthropic roles: "user" and "assistant"
            let role = (msg.role == "assistant") ? "assistant" : "user"
            messages.append(["role": role, "content": msg.content])
        }

        var json: [String: Any] = [
            "model": request.model,
            "messages": messages,
            "max_tokens": request.maxOutputTokens,
            "stream": true
        ]

        if let system = request.systemPrompt, !system.isEmpty {
            json["system"] = system
        }

        if let temp = request.temperature {
            json["temperature"] = temp
        }
        if let topP = request.topP {
            json["top_p"] = topP
        }
        if let stop = request.stopSequences, !stop.isEmpty {
            json["stop_sequences"] = stop
        }

        if let tools = request.tools, !tools.isEmpty {
            var anthropicTools: [[String: Any]] = []
            for tool in tools {
                var toolObj: [String: Any] = [
                    "name": tool.name,
                    "description": tool.description
                ]
                if let schemaData = tool.inputSchemaJSON.data(using: .utf8),
                   let schemaObj = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
                    toolObj["input_schema"] = schemaObj
                }
                anthropicTools.append(toolObj)
            }
            json["tools"] = anthropicTools
        }

        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    public func stream(request: ChatRequest, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.isEmpty else {
                        throw ProviderError.missingAPIKey(.anthropic)
                    }

                    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                        throw ProviderError.invalidURL
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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
                    var currentUsage = Usage()

                    for try await byte in byteStream {
                        buffer.append(byte)
                        if byte == 0x0A {
                            let messages = try codec.append(chunk: buffer)
                            buffer.removeAll()

                            for msg in messages {
                                guard let eventType = msg.event else { continue }
                                guard let data = msg.data.data(using: .utf8) else { continue }
                                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                                switch eventType {
                                case "message_start":
                                    if let messageObj = json["message"] as? [String: Any],
                                       let usageObj = messageObj["usage"] as? [String: Any] {
                                        currentUsage.inputTokens = usageObj["input_tokens"] as? Int ?? 0
                                        currentUsage.cachedInputTokens = usageObj["cache_read_input_tokens"] as? Int ?? 0
                                        continuation.yield(.usage(currentUsage))
                                    }

                                case "content_block_delta":
                                    if let delta = json["delta"] as? [String: Any] {
                                        let deltaType = delta["type"] as? String
                                        if deltaType == "text_delta", let text = delta["text"] as? String {
                                            continuation.yield(.textDelta(text))
                                        } else if deltaType == "thinking_delta", let thinking = delta["thinking"] as? String {
                                            continuation.yield(.thinking(thinking))
                                        }
                                    }

                                case "message_delta":
                                    if let usageObj = json["usage"] as? [String: Any] {
                                        currentUsage.outputTokens = usageObj["output_tokens"] as? Int ?? 0
                                        continuation.yield(.usage(currentUsage))
                                    }

                                case "message_stop":
                                    continuation.yield(.done)

                                default:
                                    break
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
