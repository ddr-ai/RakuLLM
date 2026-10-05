import Foundation

public struct HubModelItem: Identifiable, Codable, Equatable {
    public var id: String // repo id, e.g. "bartowski/Llama-3.2-1B-Instruct-GGUF"
    public var author: String?
    public var downloads: Int
    public var likes: Int
    public var lastModified: String?
    public var tags: [String]

    public init(
        id: String,
        author: String? = nil,
        downloads: Int = 0,
        likes: Int = 0,
        lastModified: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.author = author
        self.downloads = downloads
        self.likes = likes
        self.lastModified = lastModified
        self.tags = tags
    }
}

public struct HubFileItem: Identifiable, Codable, Equatable {
    public var id: String { path }
    public var path: String
    public var size: Int64
    public var lfs: Bool?

    public init(path: String, size: Int64, lfs: Bool? = nil) {
        self.path = path
        self.size = size
        self.lfs = lfs
    }
}

public final class HubAPI {
    public static let shared = HubAPI()

    public init() {}

    public static let curatedStarters: [HubModelItem] = [
        HubModelItem(
            id: "bartowski/Llama-3.2-1B-Instruct-GGUF",
            author: "bartowski",
            downloads: 154000,
            likes: 620,
            tags: ["gguf", "llama-3.2", "text-generation"]
        ),
        HubModelItem(
            id: "bartowski/Qwen2.5-1.5B-Instruct-GGUF",
            author: "bartowski",
            downloads: 120000,
            likes: 540,
            tags: ["gguf", "qwen2.5", "text-generation"]
        ),
        HubModelItem(
            id: "bartowski/SmolLM2-1.7B-Instruct-GGUF",
            author: "bartowski",
            downloads: 85000,
            likes: 380,
            tags: ["gguf", "smollm2", "text-generation"]
        ),
        HubModelItem(
            id: "bartowski/gemma-2-2b-it-GGUF",
            author: "bartowski",
            downloads: 98000,
            likes: 410,
            tags: ["gguf", "gemma-2", "text-generation"]
        )
    ]

    public func searchModels(
        query: String,
        token: String? = nil
    ) async throws -> [HubModelItem] {
        var components = URLComponents(string: "https://huggingface.co/api/models")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "filter", value: "gguf"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "full", value: "true")
        ]
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: query))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        if let t = token, !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return HubAPI.curatedStarters
        }

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return HubAPI.curatedStarters
        }

        return jsonArray.compactMap { item -> HubModelItem? in
            guard let id = item["id"] as? String else { return nil }
            let author = item["author"] as? String
            let downloads = item["downloads"] as? Int ?? 0
            let likes = item["likes"] as? Int ?? 0
            let lastModified = item["lastModified"] as? String
            let tags = item["tags"] as? [String] ?? []
            return HubModelItem(id: id, author: author, downloads: downloads, likes: likes, lastModified: lastModified, tags: tags)
        }
    }

    public func listFiles(
        repo: String,
        token: String? = nil
    ) async throws -> [HubFileItem] {
        let urlString = "https://huggingface.co/api/models/\(repo)/tree/main?recursive=1"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        if let t = token, !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { item -> HubFileItem? in
            guard let path = item["path"] as? String, path.hasSuffix(".gguf") else { return nil }
            let size = item["size"] as? Int64 ?? 0
            let lfs = item["lfs"] as? Bool
            return HubFileItem(path: path, size: size, lfs: lfs)
        }
    }
}
