import Foundation

public struct SSEMessage: Equatable {
    public var event: String?
    public var data: String
    public var id: String?

    public init(event: String? = nil, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}

public enum SSEError: LocalizedError, Equatable {
    case frameBufferExceededCap(Int)
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .frameBufferExceededCap(let size):
            return "SSE frame buffer exceeded 1 MB limit (\(size) bytes). Request failed."
        case .invalidEncoding:
            return "Invalid UTF-8 encoding in SSE stream."
        }
    }
}

public final class SSECodec {
    public static let maxFrameSize: Int = 1024 * 1024 // 1 MB (T8)

    private var buffer = Data()
    private var currentEvent: String?
    private var currentDataLines: [String] = []
    private var currentId: String?

    public init() {}

    /// Appends incoming byte chunk and returns all complete parsed SSE messages.
    /// Throws `SSEError.frameBufferExceededCap` if the buffer or single frame exceeds 1 MB.
    public func append(chunk: Data) throws -> [SSEMessage] {
        buffer.append(chunk)

        if buffer.count > SSECodec.maxFrameSize {
            throw SSEError.frameBufferExceededCap(buffer.count)
        }

        var messages: [SSEMessage] = []

        while true {
            // Find next newline
            guard let lineBreakRange = findLineBreak(in: buffer) else {
                break
            }

            let lineData = buffer.subdata(in: 0..<lineBreakRange.lowerBound)
            buffer.removeSubrange(0..<lineBreakRange.upperBound)

            guard let line = String(data: lineData, encoding: .utf8) else {
                throw SSEError.invalidEncoding
            }

            if line.isEmpty {
                // Empty line triggers event dispatch
                if !currentDataLines.isEmpty {
                    let fullData = currentDataLines.joined(separator: "\n")
                    let msg = SSEMessage(event: currentEvent, data: fullData, id: currentId)
                    messages.append(msg)
                    currentEvent = nil
                    currentDataLines.removeAll()
                    currentId = nil
                }
            } else if line.hasPrefix(":") {
                // Comment line, ignore
                continue
            } else if line.hasPrefix("data:") {
                var value = String(line.dropFirst(5))
                if value.hasPrefix(" ") {
                    value = String(value.dropFirst(1))
                }
                currentDataLines.append(value)
            } else if line.hasPrefix("event:") {
                var value = String(line.dropFirst(6))
                if value.hasPrefix(" ") {
                    value = String(value.dropFirst(1))
                }
                currentEvent = value
            } else if line.hasPrefix("id:") {
                var value = String(line.dropFirst(3))
                if value.hasPrefix(" ") {
                    value = String(value.dropFirst(1))
                }
                currentId = value
            }
        }

        return messages
    }

    /// Flushes any pending data when stream closes
    public func finish() -> [SSEMessage] {
        var messages: [SSEMessage] = []
        if !currentDataLines.isEmpty {
            let fullData = currentDataLines.joined(separator: "\n")
            messages.append(SSEMessage(event: currentEvent, data: fullData, id: currentId))
            currentEvent = nil
            currentDataLines.removeAll()
            currentId = nil
        }
        buffer.removeAll()
        return messages
    }

    private func findLineBreak(in data: Data) -> Range<Int>? {
        for i in 0..<data.count {
            if data[i] == 0x0A { // \n
                return i..<i+1
            } else if data[i] == 0x0D { // \r
                if i + 1 < data.count && data[i + 1] == 0x0A { // \r\n
                    return i..<i+2
                }
                return i..<i+1
            }
        }
        return nil
    }
}
