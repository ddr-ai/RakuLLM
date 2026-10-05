import XCTest
@testable import RakuLLM

final class GGUFReaderTests: XCTestCase {
    func testParseSyntheticGGUFHeader() throws {
        var data = Data()

        func append<T>(_ val: T) {
            var v = val
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        func appendString(_ str: String) {
            append(UInt64(str.utf8.count))
            data.append(str.data(using: .utf8)!)
        }

        // 1. Magic "GGUF" (0x46554747)
        append(UInt32(0x46554747))

        // 2. Version 3
        append(UInt32(3))

        // 3. Tensor count (10), Metadata count (3)
        append(UInt64(10))
        append(UInt64(3))

        // KV 1: "general.architecture" -> string "llama"
        appendString("general.architecture")
        append(UInt32(8)) // type 8 = string
        appendString("llama")

        // KV 2: "llama.context_length" -> uint64 8192
        appendString("llama.context_length")
        append(UInt32(10)) // type 10 = uint64
        append(UInt64(8192))

        // KV 3: "llama.block_count" -> uint64 32
        appendString("llama.block_count")
        append(UInt32(10))
        append(UInt64(32))

        let reader = GGUFReader()
        let metadata = try reader.parse(data: data)

        XCTAssertEqual(metadata.architecture, "llama")
        XCTAssertEqual(metadata.contextLength, 8192)
        XCTAssertEqual(metadata.blockCount, 32)
    }

    func testInvalidMagicThrowsError() {
        var data = Data()
        var badMagic: UInt32 = 0x12345678
        withUnsafeBytes(of: &badMagic) { data.append(contentsOf: $0) }

        let reader = GGUFReader()
        XCTAssertThrowsError(try reader.parse(data: data)) { error in
            XCTAssertEqual(error as? GGUFError, .invalidMagic)
        }
    }
}
