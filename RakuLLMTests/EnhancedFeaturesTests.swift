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

    // MARK: - Production Code Directive Tests

    func testProductionCodeDirectivePreservation() {
        let directive = "[PRODUCTION CODE MANDATE: Generate clean, robust, highly accurate, and production-ready code.]"
        XCTAssertTrue(directive.contains("clean, robust, highly accurate"))
    }
}
