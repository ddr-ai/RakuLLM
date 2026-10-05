import Foundation

public class OpenAIProvider: LLMProvider {
    public var kind: ProviderKind { .openai }
    public let endpointURL: String

    public init(endpointURL: String = "https://api.openai.com/v1/chat/completions") {
        self.endpointURL = endpointURL
    }

    public func buildRequestBody(request: ChatRequest) throws -> Data {
        var messages: [[String: Any]] = []

        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }

        for msg in request.messages {
            messages.append(["role": msg.role, "content": msg.content])
        }

        var json: [String: Any] = [
            "model": request.model,
            "messages": messages,
            "stream": true,
            "stream_options": ["include_usage": true],
            "max_tokens": request.maxOutputTokens
        ]

        if let temp = request.temperature {
            json["temperature"] = temp
        }
        if let topP = request.topP {
            json["top_p"] = topP
        }
        if let stop = request.stopSequences, !stop.isEmpty {
            json["stop"] = stop
        }

        if let tools = request.tools, !tools.isEmpty {
            var openAITools: [[String: Any]] = []
            for tool in tools {
                var funcObj: [String: Any] = [
                    "name": tool.name,
                    "description": tool.description
                ]
                if let schemaData = tool.inputSchemaJSON.data(using: .utf8),
                   let schemaObj = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
                    funcObj["parameters"] = schemaObj
                }
                openAITools.append(["type": "function", "function": funcObj])
            }
            json["tools"] = openAITools
        }

        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    public func stream(request: ChatRequest, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.isEmpty else {
                        throw ProviderError.missingAPIKey(self.kind)
                    }

                    guard let url = URL(string: self.endpointURL) else {
                        throw ProviderError.invalidURL
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try self.buildRequestBody(request: request)

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
                        if byte == 0x0A {
                            let messages = try codec.append(chunk: buffer)
                            buffer.removeAll()

                            for msg in messages {
                                let trimmed = msg.data.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed == "[DONE]" {
                                    continuation.yield(.done)
                                    continue
                                }

                                guard let data = trimmed.data(using: .utf8) else { continue }
                                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                                if let choices = json["choices"] as? [[String: Any]],
                                   let firstChoice = choices.first,
                                   let delta = firstChoice["delta"] as? [String: Any] {
                                    if let content = delta["content"] as? String {
                                        continuation.yield(.textDelta(content))
                                    }
                                    if let reasoning = delta["reasoning_content"] as? String {
                                        continuation.yield(.thinking(reasoning))
                                    }
                                    if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                                        for tc in toolCalls {
                                            if let function = tc["function"] as? [String: Any],
                                               let name = function["name"] as? String,
                                               let args = function["arguments"] as? String {
                                                let callId = tc["id"] as? String ?? UUID().uuidString
                                                continuation.yield(.toolCall(name: name, argumentsJSON: args, callID: callId))
                                            }
                                        }
                                    }
                                }

                                if let usageObj = json["usage"] as? [String: Any] {
                                    let prompt = usageObj["prompt_tokens"] as? Int ?? 0
                                    let completion = usageObj["completion_tokens"] as? Int ?? 0
                                    var cached = 0
                                    var reasoning = 0
                                    if let promptDetails = usageObj["prompt_tokens_details"] as? [String: Any] {
                                        cached = promptDetails["cached_tokens"] as? Int ?? 0
                                    }
                                    if let compDetails = usageObj["completion_tokens_details"] as? [String: Any] {
                                        reasoning = compDetails["reasoning_tokens"] as? Int ?? 0
                                    }
                                    continuation.yield(.usage(Usage(
                                        inputTokens: prompt,
                                        outputTokens: completion,
                                        cachedInputTokens: cached,
                                        reasoningTokens: reasoning
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
