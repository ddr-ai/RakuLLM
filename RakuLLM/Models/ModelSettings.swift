import Foundation

public enum InferenceBackend: String, Codable, CaseIterable {
    case metal = "metal"
    case cpu = "cpu"
}

public enum KVCacheType: String, Codable, CaseIterable {
    case f16 = "f16"
    case q8_0 = "q8_0"
    case q4_0 = "q4_0"
}

public struct ModelSettings: Codable, Identifiable, Equatable {
    public var id: String { modelID }
    public var modelID: String
    public var nCtx: Int
    public var nBatch: Int
    public var nGPUlayers: Int
    public var nThreads: Int
    public var kvCacheType: KVCacheType
    public var useMmap: Bool
    public var flashAttention: Bool
    public var backend: InferenceBackend

    // Per-field override tracking (only set when user manually overrides)
    public var isOverriddenNCtx: Bool
    public var isOverriddenNBatch: Bool
    public var isOverriddenNGPUlayers: Bool
    public var isOverriddenNThreads: Bool
    public var isOverriddenKVCacheType: Bool
    public var isOverriddenUseMmap: Bool
    public var isOverriddenFlashAttention: Bool
    public var isOverriddenBackend: Bool

    public init(
        modelID: String,
        nCtx: Int = 4096,
        nBatch: Int = 256,
        nGPUlayers: Int = 99,
        nThreads: Int = 4,
        kvCacheType: KVCacheType = .f16,
        useMmap: Bool = true,
        flashAttention: Bool = true,
        backend: InferenceBackend = .metal,
        isOverriddenNCtx: Bool = false,
        isOverriddenNBatch: Bool = false,
        isOverriddenNGPUlayers: Bool = false,
        isOverriddenNThreads: Bool = false,
        isOverriddenKVCacheType: Bool = false,
        isOverriddenUseMmap: Bool = false,
        isOverriddenFlashAttention: Bool = false,
        isOverriddenBackend: Bool = false
    ) {
        self.modelID = modelID
        self.nCtx = nCtx
        self.nBatch = nBatch
        self.nGPUlayers = nGPUlayers
        self.nThreads = nThreads
        self.kvCacheType = kvCacheType
        self.useMmap = useMmap
        self.flashAttention = flashAttention
        self.backend = backend
        self.isOverriddenNCtx = isOverriddenNCtx
        self.isOverriddenNBatch = isOverriddenNBatch
        self.isOverriddenNGPUlayers = isOverriddenNGPUlayers
        self.isOverriddenNThreads = isOverriddenNThreads
        self.isOverriddenKVCacheType = isOverriddenKVCacheType
        self.isOverriddenUseMmap = isOverriddenUseMmap
        self.isOverriddenFlashAttention = isOverriddenFlashAttention
        self.isOverriddenBackend = isOverriddenBackend
    }
}
