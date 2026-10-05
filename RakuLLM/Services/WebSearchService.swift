import Foundation

public struct WebSearchResult: Identifiable, Equatable {
    public var id: String { url }
    public var title: String
    public var snippet: String
    public var url: String

    public init(title: String, snippet: String, url: String) {
        self.title = title
        self.snippet = snippet
        self.url = url
    }
}

public final class WebSearchService {
    public static let shared = WebSearchService()

    public init() {}

    /// Performs live web search without requiring paid API keys
    public func search(query: String) async -> [WebSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 1. Try DuckDuckGo Instant Answer API
        if let ddgResults = await searchDuckDuckGo(query: trimmed), !ddgResults.isEmpty {
            return ddgResults
        }

        // 2. Try Wikipedia Search API as rich factual fallback
        if let wikiResults = await searchWikipedia(query: trimmed), !wikiResults.isEmpty {
            return wikiResults
        }

        return []
    }

    /// Formats search results into a clean context block for LLM prompts
    public func formatResultsForPrompt(query: String, results: [WebSearchResult]) -> String {
        guard !results.isEmpty else { return "" }
        var output = "\n[LIVE WEB SEARCH RESULTS for: \"\(query)\"]\n"
        for (i, r) in results.prefix(5).enumerated() {
            output += "\(i + 1). \(r.title)\n   \(r.snippet)\n   Source: \(r.url)\n\n"
        }
        output += "[END WEB SEARCH RESULTS - Incorporate factual information from above into your response with citations.]\n"
        return output
    }

    private func searchDuckDuckGo(query: String) async -> [WebSearchResult]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url)
        req.setValue("RakuLLM/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        var results: [WebSearchResult] = []

        // Abstract result
        if let abstract = json["AbstractText"] as? String, !abstract.isEmpty,
           let sourceURL = json["AbstractURL"] as? String,
           let heading = json["Heading"] as? String {
            results.append(WebSearchResult(title: heading, snippet: abstract, url: sourceURL))
        }

        // Related topics
        if let topics = json["RelatedTopics"] as? [[String: Any]] {
            for topic in topics.prefix(4) {
                if let text = topic["Text"] as? String,
                   let firstURL = topic["FirstURL"] as? String {
                    let title = text.components(separatedBy: " - ").first ?? "Search Result"
                    results.append(WebSearchResult(title: title, snippet: text, url: firstURL))
                }
            }
        }

        return results.isEmpty ? nil : results
    }

    private func searchWikipedia(query: String) async -> [WebSearchResult]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "https://en.wikipedia.org/w/api.php?action=opensearch&search=\(encoded)&limit=4&namespace=0&format=json"
        guard let url = URL(string: urlStr) else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(for: url),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        guard let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [Any],
              jsonArray.count >= 4,
              let titles = jsonArray[1] as? [String],
              let snippets = jsonArray[2] as? [String],
              let urls = jsonArray[3] as? [String] else {
            return nil
        }

        var results: [WebSearchResult] = []
        for i in 0..<min(titles.count, min(snippets.count, urls.count)) {
            if !snippets[i].isEmpty {
                results.append(WebSearchResult(title: titles[i], snippet: snippets[i], url: urls[i]))
            }
        }

        return results.isEmpty ? nil : results
    }
}
