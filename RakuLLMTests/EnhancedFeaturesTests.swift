import XCTest
@testable import RakuLLM

final class EnhancedFeaturesTests: XCTestCase {

    // MARK: - WebSearchService Tests

    func testWebSearchResultModel() {
        let result = WebSearchResult(
            title: "Swift Programming",
            snippet: "Swift is a powerful and intuitive programming language for iOS.",
            url: "https://developer.apple.com/swift/"
        )
        XCTAssertEqual(result.id, "https://developer.apple.com/swift/")
        XCTAssertEqual(result.title, "Swift Programming")
        XCTAssertEqual(result.snippet, "Swift is a powerful and intuitive programming language for iOS.")
    }

    func testFormatResultsForPromptEmpty() {
        let formatted = WebSearchService.shared.formatResultsForPrompt(query: "test", results: [])
        XCTAssertTrue(formatted.isEmpty)
    }

    func testFormatResultsForPromptWithData() {
        let results = [
            WebSearchResult(title: "Apple Developer", snippet: "Documentation and tools for developers.", url: "https://developer.apple.com"),
            WebSearchResult(title: "Swift.org", snippet: "The open source Swift language project.", url: "https://swift.org")
        ]
        let formatted = WebSearchService.shared.formatResultsForPrompt(query: "Swift", results: results)
        XCTAssertTrue(formatted.contains("[LIVE WEB SEARCH RESULTS for: \"Swift\"]"))
        XCTAssertTrue(formatted.contains("Apple Developer"))
        XCTAssertTrue(formatted.contains("https://swift.org"))
        XCTAssertTrue(formatted.contains("[END WEB SEARCH RESULTS"))
    }

    // MARK: - PublicMCPDirectory Tests

    func testPublicMCPDirectoryItemsCount() {
        let items = PublicMCPDirectory.shared.items
        XCTAssertGreaterThan(items.count, 35, "Public directory must provide a comprehensive catalog of tools")
    }

    func testPublicMCPDirectoryCategories() {
        let allCategories = ToolCategory.allCases.filter { $0 != .all }
        for category in allCategories {
            let filtered = PublicMCPDirectory.shared.search(query: "", category: category)
            XCTAssertFalse(filtered.isEmpty, "Category \(category.rawValue) should contain tools")
            XCTAssertTrue(filtered.allSatisfy { $0.category == category })
        }
    }

    func testPublicMCPDirectorySearchQuery() {
        let searchResults = PublicMCPDirectory.shared.search(query: "GitHub")
        XCTAssertFalse(searchResults.isEmpty)
        XCTAssertTrue(searchResults.contains(where: { $0.id == "github" }))

        let weatherResults = PublicMCPDirectory.shared.search(query: "Weather")
        XCTAssertFalse(weatherResults.isEmpty)
        XCTAssertTrue(weatherResults.contains(where: { $0.id == "openmeteo" }))
    }

    // MARK: - DownloadManager & Inference Tests

    func testDownloadManagerDestinationPathFlattening() {
        let dest = DownloadManager.shared.destinationURL(repo: "meta-llama/Llama-3-8B-GGUF", filename: "sub/llama-3-8b.Q4_K_M.gguf")
        XCTAssertTrue(dest.lastPathComponent.contains("meta-llama__Llama-3-8B-GGUF__sub__llama-3-8b.Q4_K_M.gguf"))
        XCTAssertFalse(dest.lastPathComponent.contains("/"))
    }

    @MainActor
    func testChatOrchestratorResetState() {
        let orchestrator = ChatOrchestrator()
        orchestrator.isGenerating = true
        orchestrator.currentStreamingText = "Partial response..."
        orchestrator.currentThinkingText = "Thinking deep thoughts..."
        orchestrator.errorText = "Some prior error"

        orchestrator.resetState()

        XCTAssertFalse(orchestrator.isGenerating)
        XCTAssertEqual(orchestrator.currentStreamingText, "")
        XCTAssertEqual(orchestrator.currentThinkingText, "")
        XCTAssertNil(orchestrator.errorText)
    }

    func testInferenceErrorDescriptions() {
        let err1 = InferenceError.modelNotFound("/models/test.gguf")
        XCTAssertTrue(err1.errorDescription?.contains("Model file not found") == true)

        let err2 = InferenceError.failedToLoadModel("GGUF magic header mismatch")
        XCTAssertTrue(err2.errorDescription?.contains("Failed to load model") == true)

        let err3 = InferenceError.contextAllocationFailed
        XCTAssertTrue(err3.errorDescription?.contains("Could not allocate inference context") == true)
    }
}

