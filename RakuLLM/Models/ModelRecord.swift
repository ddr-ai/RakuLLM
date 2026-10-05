import Foundation

public struct ModelRecord: Codable, Identifiable, Equatable {
    public var id: String // "repo::filename"
    public var repo: String
    public var filename: String
    public var localPath: String?
    public var fileSizeBytes: Int64
    public var quantLabel: String
    public var archLabel: String
    public var parameterCount: String?
    public var contextLength: Int?
    public var chatTemplatePresent: Bool
    public var supportsTools: Bool
    public var downloadState: DownloadState
    public var progress: Double
    public var sha256: String?
    public var lastUsedAt: Date?

    public init(
        repo: String,
        filename: String,
        localPath: String? = nil,
        fileSizeBytes: Int64 = 0,
        quantLabel: String = "",
        archLabel: String = "",
        parameterCount: String? = nil,
        contextLength: Int? = nil,
        chatTemplatePresent: Bool = false,
        supportsTools: Bool = false,
        downloadState: DownloadState = .notDownloaded,
        progress: Double = 0.0,
        sha256: String? = nil,
        lastUsedAt: Date? = nil
    ) {
        self.id = "\(repo)::\(filename)"
        self.repo = repo
        self.filename = filename
        self.localPath = localPath
        self.fileSizeBytes = fileSizeBytes
        self.quantLabel = quantLabel
        self.archLabel = archLabel
        self.parameterCount = parameterCount
        self.contextLength = contextLength
        self.chatTemplatePresent = chatTemplatePresent
        self.supportsTools = supportsTools
        self.downloadState = downloadState
        self.progress = progress
        self.sha256 = sha256
        self.lastUsedAt = lastUsedAt
    }
}
