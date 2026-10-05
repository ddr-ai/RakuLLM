import SwiftUI

public struct ModelListView: View {
    @ObservedObject public var downloadManager: DownloadManager
    @State private var showingSearch: Bool = false
    @State private var localModels: [ModelRecord] = []
    @State private var activeLoadedModelID: String? = nil
    @State private var selectedModelForSettings: ModelRecord? = nil
    @State private var modelSettings: [String: ModelSettings] = [:]
    @State private var autoChosenSettings: [String: ModelSettings] = [:]
    @State private var loadingModelID: String? = nil
    @State private var loadErrorMessage: String? = nil
    @State private var showingLoadErrorAlert: Bool = false

    private let specs = DeviceProfile.shared.currentSpecs()

    public init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Device Specs Summary Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(RakuTheme.Color.accent)
                        Text("Device Hardware Profile")
                            .font(RakuTheme.Font.headline())
                            .foregroundColor(RakuTheme.Color.fg)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Total RAM")
                                .font(RakuTheme.Font.footnote())
                                .foregroundColor(RakuTheme.Color.subtle)
                            Text(String(format: "%.1f GB", specs.totalRAMGigabytes))
                                .font(RakuTheme.Font.subheadline())
                                .foregroundColor(RakuTheme.Color.fg)
                        }

                        VStack(alignment: .leading) {
                            Text("Available Budget (60%)")
                                .font(RakuTheme.Font.footnote())
                                .foregroundColor(RakuTheme.Color.subtle)
                            Text(String(format: "%.1f GB", Double(specs.availableMemoryBytes) * 0.60 / (1024 * 1024 * 1024)))
                                .font(RakuTheme.Font.subheadline())
                                .foregroundColor(RakuTheme.Color.ok)
                        }

                        VStack(alignment: .leading) {
                            Text("Metal Working Set")
                                .font(RakuTheme.Font.footnote())
                                .foregroundColor(RakuTheme.Color.subtle)
                            Text(String(format: "%.1f GB", Double(specs.metalWorkingSetBytes) / (1024 * 1024 * 1024)))
                                .font(RakuTheme.Font.subheadline())
                                .foregroundColor(RakuTheme.Color.accent)
                        }
                    }
                }
                .rakuCard()
                .padding(.horizontal, 16)

                // Downloaded Models List
                List {
                    Section(header: Text("On-Device Models (GGUF)").foregroundColor(RakuTheme.Color.subtle)) {
                        if localModels.isEmpty {
                            VStack(alignment: .center, spacing: 8) {
                                Text("No local models downloaded yet.")
                                    .font(RakuTheme.Font.body())
                                    .foregroundColor(RakuTheme.Color.muted)
                                Text("Search Hugging Face below to find and download GGUF quantizations.")
                                    .font(RakuTheme.Font.footnote())
                                    .foregroundColor(RakuTheme.Color.subtle)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .listRowBackground(RakuTheme.Color.elevated)
                        } else {
                            ForEach(localModels) { model in
                                let isLoaded = activeLoadedModelID == model.id
                                let isMMProj = model.filename.lowercased().contains("mmproj")
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(model.filename)
                                            .font(RakuTheme.Font.headline())
                                            .foregroundColor(RakuTheme.Color.fg)
                                            .lineLimit(1)
                                        Spacer()
                                        if isMMProj {
                                            Text("Vision Adapter")
                                                .font(RakuTheme.Font.footnote())
                                                .foregroundColor(RakuTheme.Color.warning)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(RakuTheme.Color.warning.opacity(0.15))
                                                .cornerRadius(4)
                                        } else if isLoaded {
                                            Text("Active")
                                                .font(RakuTheme.Font.footnote())
                                                .foregroundColor(RakuTheme.Color.ok)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(RakuTheme.Color.ok.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }

                                    HStack {
                                        Text(String(format: "%.1f GB", Double(model.fileSizeBytes) / (1024 * 1024 * 1024)))
                                            .font(RakuTheme.Font.footnote())
                                            .foregroundColor(RakuTheme.Color.muted)

                                        Spacer()

                                        Button(action: {
                                            selectedModelForSettings = model
                                        }) {
                                            Image(systemName: "slider.horizontal.3")
                                                .foregroundColor(RakuTheme.Color.subtle)
                                        }

                                        Button(action: {
                                            toggleLoadModel(model)
                                        }) {
                                            if loadingModelID == model.id {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: RakuTheme.Color.bg))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 4)
                                                    .background(RakuTheme.Color.accent)
                                                    .cornerRadius(6)
                                            } else {
                                                Text(isLoaded ? "Unload" : "Load")
                                                    .font(RakuTheme.Font.footnote())
                                                    .foregroundColor(isLoaded ? RakuTheme.Color.danger : RakuTheme.Color.bg)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(isLoaded ? RakuTheme.Color.elevated : RakuTheme.Color.ok)
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .disabled(loadingModelID != nil)
                                    }
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(RakuTheme.Color.elevated)
                            }
                            .onDelete(perform: deleteModel)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // Search Hugging Face Button
                Button(action: { showingSearch = true }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Hugging Face Models")
                    }
                    .font(RakuTheme.Font.headline())
                    .foregroundColor(RakuTheme.Color.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RakuTheme.Color.accent)
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSearch) {
                ModelSearchSheet(downloadManager: downloadManager)
            }
            .sheet(item: $selectedModelForSettings) { model in
                let current = modelSettings[model.id] ?? ModelSettings(modelID: model.id)
                let auto = autoChosenSettings[model.id] ?? current
                ModelSettingsSheet(
                    settings: Binding(
                        get: { self.modelSettings[model.id] ?? current },
                        set: { self.modelSettings[model.id] = $0 }
                    ),
                    autoChosen: auto,
                    onSave: { updated in
                        self.modelSettings[model.id] = updated
                    }
                )
            }
            .alert("Model Load Failed", isPresented: $showingLoadErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(loadErrorMessage ?? "Failed to load GGUF weights into memory. Check hardware constraints or try a smaller quantization.")
            }
            .onAppear {
                refreshLocalModels()
                Task {
                    let loaded = await LlamaEngine.shared.isLoaded
                    let id = await LlamaEngine.shared.loadedModelID
                    await MainActor.run {
                        if loaded {
                            activeLoadedModelID = id
                        }
                    }
                }
            }
        }
    }

    private func refreshLocalModels() {
        let dir = downloadManager.modelsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return }

        var records: [ModelRecord] = []
        for file in files where file.pathExtension.lowercased() == "gguf" {
            let name = file.lastPathComponent
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let record = ModelRecord(
                repo: "local",
                filename: name,
                localPath: file.path,
                fileSizeBytes: Int64(size),
                downloadState: .completed
            )
            records.append(record)

            // Silent Auto-Configuration check (§8.2)
            if let meta = try? GGUFReader().parse(fileURL: file) {
                let existing = modelSettings[record.id]
                let result = AutoConfigurator.shared.resolveConfiguration(
                    metadata: meta,
                    fileSizeBytes: Int64(size),
                    existingSettings: existing,
                    specs: specs
                )
                modelSettings[record.id] = result.settings
                autoChosenSettings[record.id] = result.autoChosenSettings
            }
        }
        self.localModels = records
    }

    private func toggleLoadModel(_ model: ModelRecord) {
        if model.filename.lowercased().contains("mmproj") {
            loadErrorMessage = "'\(model.filename)' is a Multimodal Projector (vision adapter), not a standalone language model. It cannot be run on its own. Please download the main language model weights (e.g. Q4_K_P or Q4_K_M) to chat."
            showingLoadErrorAlert = true
            return
        }

        if activeLoadedModelID == model.id {
            loadingModelID = model.id
            Task {
                await LlamaEngine.shared.unloadModel()
                await MainActor.run {
                    activeLoadedModelID = nil
                    loadingModelID = nil
                }
            }
        } else if let path = model.localPath {
            let settings = modelSettings[model.id] ?? ModelSettings(modelID: model.id)
            loadingModelID = model.id
            Task {
                do {
                    try await LlamaEngine.shared.loadModel(path: path, settings: settings)
                    await MainActor.run {
                        activeLoadedModelID = model.id
                        loadingModelID = nil
                    }
                } catch {
                    await MainActor.run {
                        loadingModelID = nil
                        loadErrorMessage = error.localizedDescription
                        showingLoadErrorAlert = true
                    }
                }
            }
        }
    }

    private func deleteModel(at offsets: IndexSet) {
        for idx in offsets {
            let m = localModels[idx]
            if let path = m.localPath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        refreshLocalModels()
    }
}
