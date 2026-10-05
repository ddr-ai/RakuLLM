import SwiftUI

public struct ModelSettingsSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding public var settings: ModelSettings
    public let autoChosen: ModelSettings
    public let onSave: (ModelSettings) -> Void

    public init(
        settings: Binding<ModelSettings>,
        autoChosen: ModelSettings,
        onSave: @escaping (ModelSettings) -> Void
    ) {
        self._settings = settings
        self.autoChosen = autoChosen
        self.onSave = onSave
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Context & Batch").foregroundColor(RakuTheme.Color.subtle)) {
                    HStack {
                        Text("Context Length (n_ctx)")
                        Spacer()
                        Picker("", selection: $settings.nCtx) {
                            Text("2048").tag(2048)
                            Text("4096").tag(4096)
                            Text("8192").tag(8192)
                            Text("16384").tag(16384)
                        }
                        .onChange(of: settings.nCtx) { _ in settings.isOverriddenNCtx = true }
                    }
                    if settings.isOverriddenNCtx {
                        Text("Auto: \(autoChosen.nCtx)")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.subtle)
                    }

                    HStack {
                        Text("Batch Size (n_batch)")
                        Spacer()
                        Text("\(settings.nBatch)")
                            .foregroundColor(RakuTheme.Color.fg)
                    }
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("Hardware Offload").foregroundColor(RakuTheme.Color.subtle)) {
                    HStack {
                        Text("GPU Layers (n_gpu_layers)")
                        Spacer()
                        Stepper("\(settings.nGPUlayers)", value: $settings.nGPUlayers, in: 0...99)
                            .onChange(of: settings.nGPUlayers) { _ in settings.isOverriddenNGPUlayers = true }
                    }
                    if settings.isOverriddenNGPUlayers {
                        Text("Auto: \(autoChosen.nGPUlayers)")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.subtle)
                    }

                    HStack {
                        Text("CPU Threads")
                        Spacer()
                        Stepper("\(settings.nThreads)", value: $settings.nThreads, in: 1...6)
                            .onChange(of: settings.nThreads) { _ in settings.isOverriddenNThreads = true }
                    }

                    HStack {
                        Text("Backend")
                        Spacer()
                        Picker("", selection: $settings.backend) {
                            Text("Metal").tag(InferenceBackend.metal)
                            Text("CPU").tag(InferenceBackend.cpu)
                        }
                        .onChange(of: settings.backend) { _ in settings.isOverriddenBackend = true }
                    }
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("Cache & Acceleration").foregroundColor(RakuTheme.Color.subtle)) {
                    HStack {
                        Text("KV Cache Type")
                        Spacer()
                        Picker("", selection: $settings.kvCacheType) {
                            Text("f16").tag(KVCacheType.f16)
                            Text("q8_0").tag(KVCacheType.q8_0)
                            Text("q4_0").tag(KVCacheType.q4_0)
                        }
                        .onChange(of: settings.kvCacheType) { _ in settings.isOverriddenKVCacheType = true }
                    }

                    Toggle("Memory Mapping (mmap)", isOn: $settings.useMmap)
                        .onChange(of: settings.useMmap) { _ in settings.isOverriddenUseMmap = true }

                    Toggle("Flash Attention", isOn: $settings.flashAttention)
                        .onChange(of: settings.flashAttention) { _ in settings.isOverriddenFlashAttention = true }
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section {
                    Button("Reset to Automatic Settings") {
                        settings = autoChosen
                    }
                    .foregroundColor(RakuTheme.Color.warning)
                }
                .listRowBackground(RakuTheme.Color.elevated)
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .scrollContentBackground(.hidden)
            .navigationTitle("Model Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave(settings)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(RakuTheme.Color.ok)
                }
            }
        }
    }
}
