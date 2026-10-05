import Foundation
import Combine

public final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = DownloadManager()

    @Published public var activeDownloads: [String: DownloadRecord] = [:]
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var session: URLSession!

    override public init() {
        super.init()
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        ensureModelsDirectory()
    }

    public var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Models", isDirectory: true)
        return dir
    }

    public func ensureModelsDirectory() {
        var dir = modelsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? dir.setResourceValues(resourceValues)
    }

    public func destinationURL(repo: String, filename: String) -> URL {
        let safeRepo = repo.replacingOccurrences(of: "/", with: "__")
        let safeFile = filename.replacingOccurrences(of: "/", with: "__")
        return modelsDirectory.appendingPathComponent("\(safeRepo)__\(safeFile)")
    }

    public func partURL(repo: String, filename: String) -> URL {
        let safeRepo = repo.replacingOccurrences(of: "/", with: "__")
        let safeFile = filename.replacingOccurrences(of: "/", with: "__")
        return modelsDirectory.appendingPathComponent("\(safeRepo)__\(safeFile).part")
    }

    public func resumeDataURL(repo: String, filename: String) -> URL {
        let safeRepo = repo.replacingOccurrences(of: "/", with: "__")
        let safeFile = filename.replacingOccurrences(of: "/", with: "__")
        return modelsDirectory.appendingPathComponent("\(safeRepo)__\(safeFile).resume")
    }

    public func startDownload(repo: String, filename: String, token: String? = nil) {
        let modelID = "\(repo)::\(filename)"
        let dest = destinationURL(repo: repo, filename: filename)
        ensureModelsDirectory()

        let effectiveToken = token ?? KeychainHelper.load(key: "io.github.ddr-ai.rakullm.hfToken")

        // Safely construct remote download URL
        let remoteURLString: String
        if let encodedRepo = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let encodedFile = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            remoteURLString = "https://huggingface.co/\(encodedRepo)/resolve/main/\(encodedFile)"
        } else {
            remoteURLString = "https://huggingface.co/\(repo)/resolve/main/\(filename)"
        }

        guard let remoteURL = URL(string: remoteURLString) else { return }

        var record = DownloadRecord(
            modelID: modelID,
            repo: repo,
            filename: filename,
            remoteURL: remoteURLString,
            state: .downloading,
            destinationPath: dest.path
        )
        activeDownloads[modelID] = record

        // Check for resume data
        let resumeURL = resumeDataURL(repo: repo, filename: filename)
        if let resumeData = try? Data(contentsOf: resumeURL) {
            let task = session.downloadTask(withResumeData: resumeData)
            task.taskDescription = modelID
            downloadTasks[modelID] = task
            task.resume()
            try? FileManager.default.removeItem(at: resumeURL)
            return
        }

        var req = URLRequest(url: remoteURL)
        if let t = effectiveToken, !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        let task = session.downloadTask(with: req)
        task.taskDescription = modelID
        downloadTasks[modelID] = task
        task.resume()
    }

    public func pauseDownload(modelID: String) {
        guard let task = downloadTasks[modelID] else { return }
        task.cancel { [weak self] resumeData in
            guard let self = self, let data = resumeData, var record = self.activeDownloads[modelID] else { return }
            let resumeURL = self.resumeDataURL(repo: record.repo, filename: record.filename)
            try? data.write(to: resumeURL)
            record.state = .paused
            record.resumeDataPath = resumeURL.path
            DispatchQueue.main.async {
                self.activeDownloads[modelID] = record
            }
        }
        downloadTasks.removeValue(forKey: modelID)
    }

    public func cancelDownload(modelID: String) {
        if let task = downloadTasks[modelID] {
            task.cancel()
            downloadTasks.removeValue(forKey: modelID)
        }
        if let record = activeDownloads[modelID] {
            let part = partURL(repo: record.repo, filename: record.filename)
            let resume = resumeDataURL(repo: record.repo, filename: record.filename)
            try? FileManager.default.removeItem(at: part)
            try? FileManager.default.removeItem(at: resume)
        }
        activeDownloads.removeValue(forKey: modelID)
    }

    // MARK: - URLSessionDownloadDelegate

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let modelID = downloadTask.taskDescription, var record = activeDownloads[modelID] else { return }
        record.bytesWritten = totalBytesWritten
        record.totalBytes = totalBytesExpectedToWrite
        if totalBytesExpectedToWrite > 0 {
            record.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
        activeDownloads[modelID] = record
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let modelID = downloadTask.taskDescription, var record = activeDownloads[modelID] else { return }
        let dest = destinationURL(repo: record.repo, filename: record.filename)
        let part = partURL(repo: record.repo, filename: record.filename)

        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.removeItem(at: part)

        // 1. Verify HTTP Response Status
        if let httpResponse = downloadTask.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            try? FileManager.default.removeItem(at: location)
            let errMsg: String
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                errMsg = "HTTP \(httpResponse.statusCode) (Unauthorized). This repository requires an access token. Add your Hugging Face token in Settings."
            } else {
                errMsg = "Hugging Face returned HTTP \(httpResponse.statusCode). Download failed."
            }
            record.state = .failed
            record.errorDescription = errMsg
            activeDownloads[modelID] = record
            downloadTasks.removeValue(forKey: modelID)
            return
        }

        // 2. Validate GGUF Magic Header (ASCII "GGUF" = 0x47, 0x47, 0x55, 0x46)
        if let fileHandle = try? FileHandle(forReadingFrom: location) {
            let magicData = try? fileHandle.read(upToCount: 4)
            try? fileHandle.close()
            let expectedMagic = Data([0x47, 0x47, 0x55, 0x46])
            if magicData != expectedMagic {
                try? FileManager.default.removeItem(at: location)
                record.state = .failed
                record.errorDescription = "File is not a valid GGUF model (magic header mismatch). Gated or corrupted file."
                activeDownloads[modelID] = record
                downloadTasks.removeValue(forKey: modelID)
                return
            }
        }

        // 3. Move verified GGUF weights to final destination
        ensureModelsDirectory()
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var finalDest = dest
            try? finalDest.setResourceValues(resourceValues)

            record.state = .completed
            record.progress = 1.0
            record.destinationPath = dest.path
            activeDownloads[modelID] = record
        } catch {
            record.state = .failed
            record.errorDescription = error.localizedDescription
            activeDownloads[modelID] = record
        }
        downloadTasks.removeValue(forKey: modelID)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let modelID = task.taskDescription else { return }
        if let err = error as NSError?, err.code != NSURLErrorCancelled {
            if var record = activeDownloads[modelID] {
                record.state = .failed
                record.errorDescription = err.localizedDescription
                activeDownloads[modelID] = record
            }
        }
        downloadTasks.removeValue(forKey: modelID)
    }
}
