import Foundation

public enum DownloadState: String, Codable {
    case notDownloaded = "notDownloaded"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
}

public struct DownloadRecord: Codable, Identifiable {
    public var id: String { modelID }
    public var modelID: String
    public var repo: String
    public var filename: String
    public var remoteURL: String
    public var state: DownloadState
    public var progress: Double
    public var bytesWritten: Int64
    public var totalBytes: Int64
    public var resumeDataPath: String?
    public var destinationPath: String
    public var errorDescription: String?

    public init(
        modelID: String,
        repo: String,
        filename: String,
        remoteURL: String,
        state: DownloadState = .notDownloaded,
        progress: Double = 0.0,
        bytesWritten: Int64 = 0,
        totalBytes: Int64 = 0,
        resumeDataPath: String? = nil,
        destinationPath: String,
        errorDescription: String? = nil
    ) {
        self.modelID = modelID
        self.repo = repo
        self.filename = filename
        self.remoteURL = remoteURL
        self.state = state
        self.progress = progress
        self.bytesWritten = bytesWritten
        self.totalBytes = totalBytes
        self.resumeDataPath = resumeDataPath
        self.destinationPath = destinationPath
        self.errorDescription = errorDescription
    }
}
