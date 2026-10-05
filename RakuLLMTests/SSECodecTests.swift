import XCTest
@testable import RakuLLM

final class SSECodecTests: XCTestCase {
    func testSingleLineData() throws {
        let codec = SSECodec()
        let payload = "data: hello world\n\n".data(using: .utf8)!
        let messages = try codec.append(chunk: payload)

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].data, "hello world")
        XCTAssertNil(messages[0].event)
    }

    func testMultiLineDataConcatenation() throws {
        let codec = SSECodec()
        let payload = "data: line 1\ndata: line 2\ndata: line 3\n\n".data(using: .utf8)!
        let messages = try codec.append(chunk: payload)

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].data, "line 1\nline 2\nline 3")
    }

    func testSplitFramesAcrossChunks() throws {
        let codec = SSECodec()
        let chunk1 = "event: message\ndata: par".data(using: .utf8)!
        let chunk2 = "tial payload\n\n".data(using: .utf8)!

        let m1 = try codec.append(chunk: chunk1)
        XCTAssertEqual(m1.count, 0)

        let m2 = try codec.append(chunk: chunk2)
        XCTAssertEqual(m2.count, 1)
        XCTAssertEqual(m2[0].event, "message")
        XCTAssertEqual(m2[0].data, "partial payload")
    }

    func testCommentsIgnored() throws {
        let codec = SSECodec()
        let payload = ": this is a comment\ndata: actual data\n\n".data(using: .utf8)!
        let messages = try codec.append(chunk: payload)

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].data, "actual data")
    }

    func testT8FrameBufferCapExceeded() {
        let codec = SSECodec()
        // Create chunk larger than 1 MB without newline
        let oversizedData = Data(repeating: 0x41, count: 1024 * 1024 + 10)

        XCTAssertThrowsError(try codec.append(chunk: oversizedData)) { error in
            guard let sseErr = error as? SSEError else {
                XCTFail("Expected SSEError but got \(error)")
                return
            }
            if case .frameBufferExceededCap(let size) = sseErr {
                XCTAssertGreaterThan(size, 1024 * 1024)
            } else {
                XCTFail("Expected .frameBufferExceededCap but got \(sseErr)")
            }
        }
    }
}
