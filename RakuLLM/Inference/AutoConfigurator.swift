import Foundation

public struct AutoConfigResult: Equatable {
    public var settings: ModelSettings
    public var autoChosenSettings: ModelSettings
    public var isUsable: Bool
    public var refusalReason: String?

    public init(
        settings: ModelSettings,
        autoChosenSettings: ModelSettings,
        isUsable: Bool = true,
        refusalReason: String? = nil
    ) {
        self.settings = settings
        self.autoChosenSettings = autoChosenSettings
        self.isUsable = isUsable
        self.refusalReason = refusalReason
    }
}

public final class AutoConfigurator {
    public static let shared = AutoConfigurator()

    public init() {}

    /// Runs silent automatic configuration check on every load, never overwriting manual overrides.
    public func resolveConfiguration(
        metadata: GGUFMetadata,
        fileSizeBytes: Int64,
        existingSettings: ModelSettings?,
        specs: DeviceSpecs = DeviceProfile.shared.currentSpecs()
    ) -> AutoConfigResult {
        let modelID = existingSettings?.modelID ?? "model"

        // 3. Budget: usable = available * 0.60
        let usableRAM = UInt64(Double(specs.availableMemoryBytes) * 0.60)
        let weightsBytes = UInt64(max(0, fileSizeBytes))

        if weightsBytes > usableRAM {
            let sizeMB = weightsBytes / (1024 * 1024)
            let availMB = usableRAM / (1024 * 1024)
            let reason = "Model weights (\(sizeMB) MB) exceed 60% of available memory (\(availMB) MB). Please select a smaller quantization (e.g. Q4_K_M or Q3_K_S) that fits."
            let fallbackSettings = ModelSettings(modelID: modelID)
            return AutoConfigResult(
                settings: existingSettings ?? fallbackSettings,
                autoChosenSettings: fallbackSettings,
                isUsable: false,
                refusalReason: reason
            )
        }

        // 4. Context & KV arithmetic
        let trainedContext = metadata.contextLength > 0 ? metadata.contextLength : 4096
        let nLayers = max(1, metadata.blockCount)
        let nKVHeads = max(1, metadata.headCountKV > 0 ? metadata.headCountKV : metadata.headCount)
        let headDim = metadata.embeddingLength > 0 && metadata.headCount > 0 ? (metadata.embeddingLength / metadata.headCount) : 128

        // Snap candidate context to 2048 / 4096 / 8192 / 16384
        let contextCandidates = [16384, 8192, 4096, 2048]
        var chosenCtx = 2048
        var chosenKVType: KVCacheType = .f16

        for candidate in contextCandidates {
            if candidate <= trainedContext {
                // 5. KV type: f16 at 8192 or below, q8_0 above
                let kvType: KVCacheType = candidate > 8192 ? .q8_0 : .f16
                let bytesPerElement: Double = kvType == .f16 ? 2.0 : 1.0
                // KV bytes = n_ctx * n_layers * n_kv_heads * head_dim * 2 * bytesPerElement
                let kvBytes = Double(candidate * nLayers * nKVHeads * headDim * 2) * bytesPerElement

                if weightsBytes + UInt64(kvBytes) <= usableRAM {
                    chosenCtx = candidate
                    chosenKVType = kvType
                    break
                }
            }
        }

        // 6. Offload layers to GPU
        let gpuBudget = specs.metalWorkingSetBytes
        let overhead: UInt64 = 256 * 1024 * 1024 // 256 MB overhead
        var chosenGPULayers = 0

        if specs.hasMetalDevice && gpuBudget > overhead {
            let usableGPUMem = gpuBudget - overhead
            let bytesPerLayer = UInt64(max(1, weightsBytes / UInt64(nLayers)))
            if weightsBytes <= usableGPUMem {
                chosenGPULayers = 99 // Offload all
            } else {
                chosenGPULayers = Int(usableGPUMem / bytesPerLayer)
            }
        }

        // 7. Threads: activeProcessorCount clamped to 1...6
        let chosenThreads = min(6, max(1, specs.cpuCores))

        // 8. Batch: 256
        let chosenBatch = 256
        let chosenMmap = true
        let chosenFlashAttn = true

        // 9. Backend: .metal if Metal exists, else .cpu
        let chosenBackend: InferenceBackend = specs.hasMetalDevice ? .metal : .cpu

        let autoSettings = ModelSettings(
            modelID: modelID,
            nCtx: chosenCtx,
            nBatch: chosenBatch,
            nGPUlayers: chosenGPULayers,
            nThreads: chosenThreads,
            kvCacheType: chosenKVType,
            useMmap: chosenMmap,
            flashAttention: chosenFlashAttn,
            backend: chosenBackend
        )

        // Merge with existing manual overrides (never overwrite an override)
        var finalSettings = autoSettings
        if let existing = existingSettings {
            finalSettings.nCtx = existing.isOverriddenNCtx ? existing.nCtx : autoSettings.nCtx
            finalSettings.nBatch = existing.isOverriddenNBatch ? existing.nBatch : autoSettings.nBatch
            finalSettings.nGPUlayers = existing.isOverriddenNGPUlayers ? existing.nGPUlayers : autoSettings.nGPUlayers
            finalSettings.nThreads = existing.isOverriddenNThreads ? existing.nThreads : autoSettings.nThreads
            finalSettings.kvCacheType = existing.isOverriddenKVCacheType ? existing.kvCacheType : autoSettings.kvCacheType
            finalSettings.useMmap = existing.isOverriddenUseMmap ? existing.useMmap : autoSettings.useMmap
            finalSettings.flashAttention = existing.isOverriddenFlashAttention ? existing.flashAttention : autoSettings.flashAttention
            finalSettings.backend = existing.isOverriddenBackend ? existing.backend : autoSettings.backend

            finalSettings.isOverriddenNCtx = existing.isOverriddenNCtx
            finalSettings.isOverriddenNBatch = existing.isOverriddenNBatch
            finalSettings.isOverriddenNGPUlayers = existing.isOverriddenNGPUlayers
            finalSettings.isOverriddenNThreads = existing.isOverriddenNThreads
            finalSettings.isOverriddenKVCacheType = existing.isOverriddenKVCacheType
            finalSettings.isOverriddenUseMmap = existing.isOverriddenUseMmap
            finalSettings.isOverriddenFlashAttention = existing.isOverriddenFlashAttention
            finalSettings.isOverriddenBackend = existing.isOverriddenBackend
        }

        return AutoConfigResult(
            settings: finalSettings,
            autoChosenSettings: autoSettings,
            isUsable: true,
            refusalReason: nil
        )
    }
}
