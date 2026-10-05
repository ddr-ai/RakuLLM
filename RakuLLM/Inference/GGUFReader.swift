import Foundation

public struct GGUFMetadata: Equatable {
    public var architecture: String = ""
    public var fileType: UInt32 = 0
    public var contextLength: Int = 4096
    public var embeddingLength: Int = 4096
    public var blockCount: Int = 32
    public var headCount: Int = 32
    public var headCountKV: Int = 32
    public var ropeDimensionCount: Int = 128
    public var chatTemplate: String? = nil
    public var rawValues: [String: String] = [:]

    public init() {}
}

public enum GGUFError: LocalizedError, Equatable {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case unexpectedEOF
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .invalidMagic: return "Not a valid GGUF file (magic header mismatch)."
        case .unsupportedVersion(let v): return "Unsupported GGUF version: \(v)."
        case .unexpectedEOF: return "Unexpected end of file while parsing GGUF header."
        case .invalidEncoding: return "Invalid string encoding in GGUF metadata."
        }
    }
}

public final class GGUFReader {
    public init() {}

    public func parse(fileURL: URL) throws -> GGUFMetadata {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let headerData = try handle.read(upToCount: 2 * 1024 * 1024) ?? Data()
        return try parse(data: headerData)
    }

    public func parse(data: Data) throws -> GGUFMetadata {
        var offset = 0

        func read<T>(_ type: T.Type) throws -> T {
            let size = MemoryLayout<T>.size
            guard offset + size <= data.count else {
                throw GGUFError.unexpectedEOF
            }
            let value = data.subdata(in: offset..<offset + size).withUnsafeBytes { $0.load(as: T.self) }
            offset += size
            return value
        }

        func readString() throws -> String {
            let len64 = try read(UInt64.self)
            let len = Int(len64)
            guard offset + len <= data.count else {
                throw GGUFError.unexpectedEOF
            }
            let strData = data.subdata(in: offset..<offset + len)
            offset += len
            guard let str = String(data: strData, encoding: .utf8) else {
                throw GGUFError.invalidEncoding
            }
            return str
        }

        // 1. Magic
        let magic = try read(UInt32.self)
        guard magic == 0x46554747 else { // "GGUF" in little endian
            throw GGUFError.invalidMagic
        }

        // 2. Version
        let version = try read(UInt32.self)
        guard version >= 2 && version <= 3 else {
            throw GGUFError.unsupportedVersion(version)
        }

        // 3. Tensor count & metadata kv count
        _ = try read(UInt64.self) // tensor_count
        let kvCount = try read(UInt64.self)

        var meta = GGUFMetadata()

        func skipValue(type: UInt32) throws {
            switch type {
            case 0, 1, 7: offset += 1 // uint8, int8, bool
            case 2, 3: offset += 2    // uint16, int16
            case 4, 5, 6: offset += 4 // uint32, int32, float32
            case 10, 11, 12: offset += 8 // uint64, int64, float64
            case 8: // string
                let len = Int(try read(UInt64.self))
                offset += len
            case 9: // array
                let elemType = try read(UInt32.self)
                let elemCount = Int(try read(UInt64.self))
                for _ in 0..<elemCount {
                    try skipValue(type: elemType)
                }
            default:
                break
            }
        }

        for _ in 0..<kvCount {
            if offset >= data.count { break }
            let key = try readString()
            let valType = try read(UInt32.self)

            if valType == 8 { // string
                let valStr = try readString()
                meta.rawValues[key] = valStr
                if key == "general.architecture" {
                    meta.architecture = valStr
                } else if key == "tokenizer.chat_template" {
                    meta.chatTemplate = valStr
                }
            } else if valType == 4 || valType == 5 { // uint32 / int32
                let valInt = Int(try read(UInt32.self))
                meta.rawValues[key] = String(valInt)
                if key == "general.file_type" {
                    meta.fileType = UInt32(valInt)
                }
            } else if valType == 10 || valType == 11 { // uint64 / int64
                let valInt64 = Int(try read(UInt64.self))
                meta.rawValues[key] = String(valInt64)
                if key.hasSuffix(".context_length") {
                    meta.contextLength = valInt64
                } else if key.hasSuffix(".embedding_length") {
                    meta.embeddingLength = valInt64
                } else if key.hasSuffix(".block_count") {
                    meta.blockCount = valInt64
                } else if key.hasSuffix(".attention.head_count") {
                    meta.headCount = valInt64
                } else if key.hasSuffix(".attention.head_count_kv") {
                    meta.headCountKV = valInt64
                } else if key.hasSuffix(".rope.dimension_count") {
                    meta.ropeDimensionCount = valInt64
                }
            } else {
                try skipValue(type: valType)
            }
        }

        return meta
    }
}
