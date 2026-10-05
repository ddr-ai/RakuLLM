import SwiftUI

public struct ModelSearchSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject public var downloadManager: DownloadManager
    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var models: [HubModelItem] = HubAPI.curatedStarters
    @State private var selectedRepo: HubModelItem? = nil
    @State private var repoFiles: [HubFileItem] = []
    @State private var isLoadingFiles: Bool = false

    private let specs = DeviceProfile.shared.currentSpecs()

    public init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(RakuTheme.Color.muted)
                    TextField("Search Hugging Face (e.g. Llama-3.2, Qwen2.5)", text: $query)
                        .font(RakuTheme.Font.body())
                        .foregroundColor(RakuTheme.Color.fg)
                        .onSubmit { performSearch() }
                    if !query.isEmpty {
                        Button(action: { query = ""; performSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(RakuTheme.Color.subtle)
                        }
                    }
                }
                .padding(10)
                .background(RakuTheme.Color.canvas)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(RakuTheme.Color.line))
                .padding(12)

                if selectedRepo == nil {
                    // Models List
                    List(models) { item in
                        Button(action: { selectModel(item) }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.id)
                                    .font(RakuTheme.Font.headline())
                                    .foregroundColor(RakuTheme.Color.fg)

                                HStack(spacing: 12) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.down.circle")
                                        Text("\(item.downloads)")
                                    }
                                    HStack(spacing: 3) {
                                        Image(systemName: "heart")
                                        Text("\(item.likes)")
                                    }
                                    if let author = item.author {
                                        Text("by \(author)")
                                    }
                                }
                                .font(RakuTheme.Font.footnote())
                                .foregroundColor(RakuTheme.Color.muted)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(RakuTheme.Color.elevated)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else if let repo = selectedRepo {
                    // Files in Selected Repo
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { selectedRepo = nil }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back to search")
                            }
                            .font(RakuTheme.Font.subheadline())
                            .foregroundColor(RakuTheme.Color.accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Text(repo.id)
                            .font(RakuTheme.Font.headline())
                            .foregroundColor(RakuTheme.Color.fg)
                            .padding(.horizontal, 16)

                        if isLoadingFiles {
                            ProgressView("Loading quantizations...")
                                .foregroundColor(RakuTheme.Color.muted)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            let primaryFiles = repoFiles.filter { !$0.isMultimodalProjector }
                            let projectorFiles = repoFiles.filter { $0.isMultimodalProjector }

                            List {
                                if !primaryFiles.isEmpty {
                                    Section(header: Text("Language Models (Standalone LLM Weights)").foregroundColor(RakuTheme.Color.subtle)) {
                                        ForEach(primaryFiles) { file in
                                            fileRow(file: file, repo: repo)
                                        }
                                    }
                                }

                                if !projectorFiles.isEmpty {
                                    Section(header: Text("Vision Projectors (mmproj - Requires Main Model)").foregroundColor(RakuTheme.Color.subtle)) {
                                        ForEach(projectorFiles) { file in
                                            fileRow(file: file, repo: repo)
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .navigationTitle("Hugging Face Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(RakuTheme.Color.fg)
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(file: HubFileItem, repo: HubModelItem) -> some View {
        let assessment = FitCalculator.shared.assessFit(
            fileSizeBytes: file.size,
            availableMemoryBytes: specs.availableMemoryBytes
        )
        let modelID = "\(repo.id)::\(file.path)"
        let downloadRecord = downloadManager.activeDownloads[modelID]

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(file.path)
                    .font(RakuTheme.Font.subheadline())
                    .foregroundColor(RakuTheme.Color.fg)
                    .lineLimit(1)
                Spacer()
                if file.isMultimodalProjector {
                    Text("Vision Adapter")
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(RakuTheme.Color.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RakuTheme.Color.warning.opacity(0.15))
                        .cornerRadius(4)
                } else {
                    FitBadgeView(fitLevel: assessment.fitLevel, referenceContext: assessment.referenceContext)
                }
            }

            if file.isMultimodalProjector {
                Text("⚠️ Multimodal projector only. Requires main model (e.g. Q4_K_P) above to chat.")
                    .font(RakuTheme.Font.footnote())
                    .foregroundColor(RakuTheme.Color.warning)
            }

            HStack {
                Text(String(format: "%.1f GB", Double(file.size) / (1024 * 1024 * 1024)))
                    .font(RakuTheme.Font.footnote())
                    .foregroundColor(RakuTheme.Color.muted)

                Spacer()

                if let rec = downloadRecord {
                    if rec.state == .downloading {
                        ProgressView(value: rec.progress)
                            .frame(width: 80)
                        Button(action: { downloadManager.pauseDownload(modelID: modelID) }) {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(RakuTheme.Color.warning)
                        }
                    } else if rec.state == .paused {
                        Button(action: { downloadManager.startDownload(repo: repo.id, filename: file.path) }) {
                            Text("Resume")
                                .font(RakuTheme.Font.footnote())
                                .foregroundColor(RakuTheme.Color.accent)
                        }
                    } else if rec.state == .completed {
                        Text("Downloaded")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.ok)
                    }
                } else {
                    Button(action: {
                        downloadManager.startDownload(repo: repo.id, filename: file.path)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                            Text("Download")
                        }
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(RakuTheme.Color.bg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(assessment.fitLevel == .tooLarge ? RakuTheme.Color.subtle : RakuTheme.Color.ok)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(RakuTheme.Color.elevated)
    }

    private func performSearch() {
        Task {
            isSearching = true
            let results = (try? await HubAPI.shared.searchModels(query: query)) ?? []
            self.models = results.isEmpty ? HubAPI.curatedStarters : results
            isSearching = false
        }
    }

    private func selectModel(_ item: HubModelItem) {
        selectedRepo = item
        isLoadingFiles = true
        Task {
            let files = (try? await HubAPI.shared.listFiles(repo: item.id)) ?? []
            self.repoFiles = files
            self.isLoadingFiles = false
        }
    }
}
