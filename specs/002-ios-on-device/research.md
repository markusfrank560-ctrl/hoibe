# Research: iOS On-Device First-Sip Detection

**Feature**: 002-ios-on-device  
**Date**: 2026-05-03

## Research Tasks

### R1: MLX Swift LM Compatibility with Qwen3-VL-4B

**Decision**: Use `ml-explore/mlx-swift-lm` v3.31.3+ with `Qwen3-VL-4B-Instruct-MLX-4bit` from HuggingFace.

**Rationale**: 
- MLX Swift LM is Apple's official Swift package for running MLX models natively on Apple Silicon
- Supports vision-language models with image input (multi-modal)
- 4-bit quantization reduces model from ~8 GB (FP16) to ~2.5 GB — fits in 8 GB RAM budget
- `num_ctx=4096` keeps KV cache around 0.5–1 GB (acceptable within budget)
- `think=false` disables extended reasoning to avoid infinite loops and reduce latency

**Alternatives considered**:
- llama.cpp (iOS): Mature but no native Swift API, requires C++ bridging, less optimized for Apple Silicon
- CoreML conversion: Would require custom conversion pipeline; Qwen3-VL not officially supported by coremltools for vision
- Ollama on-device: No iOS runtime exists; Ollama is macOS/Linux only

### R2: Frame Extraction on iOS

**Decision**: Use `AVAssetImageGenerator` with `generateCGImagesAsynchronously` for frame extraction. Sharpness ranking via Accelerate framework (Laplacian variance equivalent).

**Rationale**:
- AVAssetImageGenerator is the standard iOS API for extracting frames at specific timestamps
- Supports H.264/HEVC natively without additional codecs
- `requestedTimeToleranceBefore/After` controls frame accuracy
- Accelerate framework provides vDSP operations for computing variance efficiently (no OpenCV dependency)

**Alternatives considered**:
- VideoToolbox: Lower-level, more complex, no significant benefit for our use case
- OpenCV via CocoaPod: Adds 50+ MB to binary, overkill for frame extraction + Laplacian
- vImage: Could work for convolution but less ergonomic than custom Accelerate approach

### R3: Memory Management for 8 GB Devices

**Decision**: Use `com.apple.developer.kernel.increased-memory-limit` entitlement + careful lifecycle management.

**Rationale**:
- Standard iOS apps limited to ~3–4 GB before Jetsam kills them
- Extended memory entitlement raises this to ~6 GB on 8 GB devices
- Budget: 2.5 GB (model) + 1 GB (KV cache) + 0.3 GB (images) + 2.5 GB (OS+app) = ~6.3 GB
- Must release image buffers immediately after encoding into model input
- KV cache cleared between gate and window stages (model unload/reload cycle not needed on MLX — just clear context)

**Alternatives considered**:
- Streaming model loading: MLX loads weights lazily, but full model must be resident for inference
- Smaller model (2B): Insufficient accuracy for first-sip detection nuance
- On-demand paging: Not available at application level on iOS

### R4: Model Download & Caching Strategy

**Decision**: Use HuggingFace Hub Swift client (or direct HTTPS + URLSession) with resumable download, WiFi-preference UI, and permanent caching in app container.

**Rationale**:
- HuggingFace hosts the MLX-4bit model weights as individual shards
- `URLSessionDownloadTask` supports background transfer and resume
- App container (`Library/Caches/` or `Library/Application Support/`) persists across launches
- `isExcludedFromBackup = true` prevents iCloud backup of 2.5 GB model files
- WiFi-only default via `allowsCellularAccess = false` on URLSessionConfiguration

**Alternatives considered**:
- Bundle model in IPA: 2.5 GB would exceed App Store size limits and waste bandwidth for non-ML updates
- On-demand resources (ODR): Limited to 2 GB per tag, complex Apple review process
- CloudKit: Adds Apple account dependency, violates privacy-first principle

### R5: Prompt Compatibility Between Ollama and MLX

**Decision**: v3 prompts work identically on MLX Swift LM. The chat template formatting differs but content is the same.

**Rationale**:
- v3 prompts are plain text instructions + JSON schema — model-agnostic
- MLX Swift LM applies the model's built-in chat template (same as Ollama does)
- `think=false` prevents Qwen3's `<think>` reasoning mode (same param as Ollama's `think` option)
- `temperature=0.1` is directly supported by MLX generation config
- 3-field lean response format reduces token count — faster inference within timeout

**Alternatives considered**:
- Custom chat template: Unnecessary; MLX uses the model's tokenizer config which includes the correct template
- Different prompt versions for iOS: Maintenance burden, divergence risk

### R6: Thermal Management & Timeout Strategy

**Decision**: Per-call timeouts (45s gate, 90s window) with Swift `Task` cancellation. Cooldown between inference calls (2s pause). No explicit thermal API — rely on timeouts to prevent runaway.

**Rationale**:
- iOS has no public thermal throttling API for ML workloads
- `ProcessInfo.thermalState` is read-only, too coarse for per-call decisions
- Swift structured concurrency (`withTaskCancellationHandler` + `Task.sleep`) provides clean timeout semantics
- 2s cooldown between calls allows thermal recovery and KV cache cleanup
- Total worst case: 3 gate votes × 45s + 3 windows × 90s = 135s + 270s = ~6.75 min (but early-exit makes typical case < 3 min)

**Alternatives considered**:
- Adaptive timeout based on thermal state: Too unpredictable, complicates testing
- Background processing (BGTaskScheduler): Overkill for interactive use case, user expects immediate feedback
- Metal Performance Shaders direct: MLX already uses Metal under the hood

### R7: Extended Memory Entitlement Apple Review

**Decision**: Apply for `com.apple.developer.kernel.increased-memory-limit` entitlement. Low rejection risk for ML workloads.

**Rationale**:
- Apple explicitly documents this entitlement for "apps that require more memory for core functionality"
- ML inference with large models is a canonical use case
- No App Store rejection reports for legitimate ML apps using this entitlement
- Alternative (crash on 8 GB devices) is unacceptable

**Alternatives considered**:
- Targeting only 12+ GB devices (iPhone 16 Pro Max): Excludes iPhone 15 Pro and 16e — too narrow
- Model quantization below 4-bit (2-bit): Unacceptable accuracy loss
