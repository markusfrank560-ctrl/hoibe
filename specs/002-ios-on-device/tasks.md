# Tasks: iOS On-Device First-Sip Detection

**Input**: Design documents from `/specs/002-ios-on-device/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Included — spec references XCTest + Swift Testing.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US4, US5)
- Exact file paths included in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Xcode project initialization, Swift Package dependencies, entitlements, bundled resources

- [x] T001 Create Xcode project `Hoibe` at `ios/Hoibe.xcodeproj` with iOS 17.0 deployment target, Swift 5.9
- [x] T002 Add SPM dependency: `ml-explore/mlx-swift-lm` v3.31.3+ in `ios/Hoibe.xcodeproj`
- [x] T003 [P] Create directory structure: `ios/Hoibe/App/`, `ios/Hoibe/Models/`, `ios/Hoibe/Services/`, `ios/Hoibe/Resources/Prompts/`
- [x] T004 [P] Create `ios/Hoibe/Hoibe.entitlements` with `com.apple.developer.kernel.increased-memory-limit = true`
- [x] T005 [P] Bundle prompt templates from `prompts/v3/` into `ios/Hoibe/Resources/Prompts/` (system_prompt.txt, user_prompt_template.txt, fill_level_prompt.txt)
- [x] T006 [P] Create `ios/HoibeTests/` directory and add test target to Xcode project
- [x] T007 [P] Symlink or copy `tests/fixtures/results/*.json` into `ios/HoibeTests/Fixtures/`
- [x] T008 Configure Xcode scheme for debug/release with signing and entitlements

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core models and enums that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T009 [P] Implement `BeerFillLevel` enum in `ios/Hoibe/Models/BeerFillLevel.swift` (full, mostlyFull, half, mostlyEmpty, empty, unknown — Codable, Equatable, Sendable)
- [x] T010 [P] Implement `AnalysisResult` struct in `ios/Hoibe/Models/AnalysisResult.swift` (Codable with snake_case CodingKeys, matching contract in `contracts/SipDetecting.swift`)
- [x] T011 [P] Implement `ModelDownloadState` enum in `ios/Hoibe/Models/ModelDownloadState.swift` (notDownloaded, downloading(progress), paused(bytesDownloaded), ready, error(message) — Equatable)
- [x] T012 [P] Implement `AnalysisState` enum in `ios/Hoibe/Models/AnalysisState.swift` (idle, validating, extractingFrames, runningGate, runningWindows, complete, error — Equatable)
- [x] T013 [P] Implement `PipelineConfig` struct in `ios/Hoibe/Models/PipelineConfig.swift` with defaults from data-model (gateVotes=3, gateTimeout=45, windowCount=3, windowMinSpan=0.6, windowTimeout=90, numCtx=4096, temperature=0.1, cooldown=2.0, rejectLevels)
- [x] T014 [P] Implement `ChatMessage` struct in `ios/Hoibe/Models/ChatMessage.swift` (role enum: system/user/assistant, text, images [Data] — Sendable)
- [x] T015 [P] Implement `FrameData` struct in `ios/Hoibe/Models/FrameData.swift` (framesJPEG: [Data], timestamps: [Double], sharpnessScores: [Double] — Sendable)

**Checkpoint**: All shared types available — user story implementation can begin

---

## Phase 3: User Story 4 - Model Download & Setup (Priority: P1) 🎯 MVP

**Goal**: Enable first-time model download (~2.5 GB) from HuggingFace with progress UI, resume support, WiFi-only default

**Independent Test**: App on fresh device shows download UI; after completion, model is cached and inference-ready

### Tests for User Story 4

- [ ] T016 [P] [US4] Unit test `ModelDownloadState` transitions in `ios/HoibeTests/ModelManagerTests.swift`
- [ ] T017 [P] [US4] Test model readiness check (cached model exists) in `ios/HoibeTests/ModelManagerTests.swift`

### Implementation for User Story 4

- [x] T018 [US4] Implement `ModelManager` class conforming to `ModelManaging` protocol in `ios/Hoibe/Services/ModelManager.swift`
- [ ] T019 [US4] Implement HuggingFace download with URLSession: resumable, `allowsCellularAccess=false` default in `ios/Hoibe/Services/ModelManager.swift`
- [x] T020 [US4] Implement progress tracking (published `state` property) for SwiftUI binding in `ios/Hoibe/Services/ModelManager.swift`
- [ ] T021 [US4] Implement model cache in `Library/Application Support/` with `isExcludedFromBackup = true` in `ios/Hoibe/Services/ModelManager.swift`
- [ ] T022 [US4] Implement pause/resume download and network-loss recovery in `ios/Hoibe/Services/ModelManager.swift`
- [x] T023 [US4] Implement `generate(messages:maxTokens:temperature:)` method wrapping MLX Swift LM inference (think=false) in `ios/Hoibe/Services/ModelManager.swift`
- [x] T024 [US4] Implement `deleteModel()` for storage management in `ios/Hoibe/Services/ModelManager.swift`

**Checkpoint**: Model can be downloaded, cached, and used for inference

---

## Phase 4: User Story 5 - Video Capture (Priority: P1)

**Goal**: User can record or pick a 5–15s video clip for analysis

**Independent Test**: Record 10s clip or pick from library; clip URL is available for pipeline

### Tests for User Story 5

- [ ] T025 [P] [US5] Unit test duration validation (reject <5s and >15s) in `ios/HoibeTests/VideoValidationTests.swift`

### Implementation for User Story 5

- [x] T026 [US5] Implement camera recording view (UIImagePickerController or AVCaptureSession) with 15s auto-stop in `ios/Hoibe/App/CameraView.swift`
- [x] T027 [US5] Implement PhotosPicker integration for library selection (PhotosUI) in `ios/Hoibe/App/VideoPickerView.swift`
- [ ] T028 [US5] Implement video duration validation (5–15s range check, user feedback on invalid) in `ios/Hoibe/Services/VideoValidator.swift`
- [ ] T029 [US5] Implement codec validation (H.264/HEVC check) in `ios/Hoibe/Services/VideoValidator.swift`

**Checkpoint**: Video input pipeline working — clips ready for frame extraction

---

## Phase 5: User Story 1 - Erster Schluck erkennen (Priority: P1) 🎯 Core

**Goal**: Detect a valid first sip from a beer clip entirely on-device, returning structured result with confidence ≥ 0.7

**Independent Test**: Video with clear drinking motion → result card shows ✅ with confidence ≥ 0.7

### Tests for User Story 1

- [ ] T030 [P] [US1] Unit test `FrameExtractor.extractFrames` returns correct count and timestamps in `ios/HoibeTests/FrameExtractorTests.swift`
- [ ] T031 [P] [US1] Unit test sharpness ranking (Laplacian variance) in `ios/HoibeTests/FrameExtractorTests.swift`
- [ ] T032 [P] [US1] Unit test `PromptEngine.buildFillLevelMessages` produces correct ChatMessage array in `ios/HoibeTests/PromptEngineTests.swift`
- [ ] T033 [P] [US1] Unit test `PromptEngine.buildSipDetectionMessages` with multiple frames in `ios/HoibeTests/PromptEngineTests.swift`
- [ ] T034 [P] [US1] Unit test `AnalysisResult` JSON decoding from fixture files in `ios/HoibeTests/ResultParsingTests.swift`
- [ ] T035 [P] [US1] Integration test `SipDetector.analyze` with mocked ModelManager in `ios/HoibeTests/SipDetectorTests.swift`

### Implementation for User Story 1

- [x] T036 [US1] Implement `FrameExtractor` conforming to `FrameExtracting` protocol in `ios/Hoibe/Services/FrameExtractor.swift`
- [x] T037 [US1] Implement AVAssetImageGenerator frame extraction with endpoint-inclusive distribution in `ios/Hoibe/Services/FrameExtractor.swift`
- [x] T038 [US1] Implement sharpness ranking via Accelerate framework (Laplacian variance) in `ios/Hoibe/Services/FrameExtractor.swift`
- [x] T039 [US1] Implement JPEG encoding with configurable quality and maxWidth downscaling in `ios/Hoibe/Services/FrameExtractor.swift`
- [x] T040 [US1] Implement `PromptEngine` conforming to `PromptBuilding` protocol in `ios/Hoibe/Services/PromptEngine.swift`
- [x] T041 [US1] Implement `buildFillLevelMessages` loading bundled `fill_level_prompt.txt` in `ios/Hoibe/Services/PromptEngine.swift`
- [x] T042 [US1] Implement `buildSipDetectionMessages` loading bundled `system_prompt.txt` + `user_prompt_template.txt` in `ios/Hoibe/Services/PromptEngine.swift`
- [x] T043 [US1] Implement `SipDetector` conforming to `SipDetecting` protocol in `ios/Hoibe/Services/SipDetector.swift`
- [x] T044 [US1] Implement fill-level gate: N votes (sharpest frame per vote), majority-vote, reject on {half, mostlyEmpty, empty} in `ios/Hoibe/Services/SipDetector.swift`
- [x] T045 [US1] Implement sliding-window analysis: 3 overlapping windows (minSpan=0.6), OR-logic, early-exit on first positive in `ios/Hoibe/Services/SipDetector.swift`
- [x] T046 [US1] Implement JSON response parsing from VLM output into `AnalysisResult` in `ios/Hoibe/Services/SipDetector.swift`
- [x] T047 [US1] Implement `AnalysisState` publishing for UI observation in `ios/Hoibe/Services/SipDetector.swift`
- [x] T048 [US1] Implement `cancel()` method with Task cancellation in `ios/Hoibe/Services/SipDetector.swift`

**Checkpoint**: Full detection pipeline produces correct positive results for valid first-sip clips

---

## Phase 6: User Story 2 - Posieren ohne Schluck ablehnen (Priority: P1)

**Goal**: Reject clips where user holds/raises glass without drinking (false positive prevention)

**Independent Test**: Clip with beer-holding but no mouth contact → result card shows ❌ with `first_sip_detected: false`

### Tests for User Story 2

- [ ] T049 [P] [US2] Test negative fixture JSON decoding (`negative_no-sip_001`) in `ios/HoibeTests/ResultParsingTests.swift`
- [ ] T050 [P] [US2] Test negative fixture JSON decoding (`negative_sip-not-first_001`) in `ios/HoibeTests/ResultParsingTests.swift`

### Implementation for User Story 2

- [x] T051 [US2] Validate gate rejects posing scenarios (fill level unchanged = likely not drinking) in `ios/Hoibe/Services/SipDetector.swift`
- [x] T052 [US2] Validate sliding-window returns negative when no mouth-contact or drinking motion detected in `ios/Hoibe/Services/SipDetector.swift`

**Checkpoint**: Pipeline correctly rejects posing/toasting without drinking — precision maintained

---

## Phase 7: User Story 3 - Ungültigen Clip erkennen (Priority: P2)

**Goal**: Return definitive negative with explanatory reason when clip lacks face or drink

**Independent Test**: Clip without visible face → result shows ❌ with confidence ≤ 0.3 and explaining reason

### Implementation for User Story 3

- [ ] T053 [US3] Implement validation step in `SipDetector` checking `face_visible` and `drinking_object_visible` fields before window analysis in `ios/Hoibe/Services/SipDetector.swift`
- [ ] T054 [US3] Implement early-exit with low-confidence negative result when prerequisites missing in `ios/Hoibe/Services/SipDetector.swift`
- [ ] T055 [US3] Implement descriptive `reason_short` generation for invalid clips (no face, no drink) in `ios/Hoibe/Services/SipDetector.swift`

**Checkpoint**: Invalid clips handled gracefully with informative feedback

---

## Phase 8: User Story 6 - On-Device Privacy (Priority: P1)

**Goal**: Zero network requests during analysis; full offline capability after model download

**Independent Test**: Enable airplane mode after model download → analysis completes successfully

### Implementation for User Story 6

- [ ] T056 [US6] Verify `ModelManager.generate` uses no network (MLX inference is fully local) — add assertion/documentation in `ios/Hoibe/Services/ModelManager.swift`
- [ ] T057 [US6] Ensure no analytics, telemetry, or crash reporting during analysis pipeline in `ios/Hoibe/App/HoibeApp.swift`
- [ ] T058 [US6] Add `NSAppTransportSecurity` exception only for HuggingFace download domain in `ios/Hoibe/Info.plist`

**Checkpoint**: Privacy guarantee verified — no outbound connections during inference

---

## Phase 9: User Story 7 - Thermal Management (Priority: P2)

**Goal**: Graceful handling of timeouts and thermal throttling without hangs or crashes

**Independent Test**: Inference exceeding timeout → analysis cleanly cancelled with error message

### Tests for User Story 7

- [ ] T059 [P] [US7] Test timeout cancellation logic (simulated slow inference) in `ios/HoibeTests/SipDetectorTests.swift`

### Implementation for User Story 7

- [x] T060 [US7] Implement per-call timeout (45s gate, 90s window) with `withTaskCancellationHandler` in `ios/Hoibe/Services/SipDetector.swift`
- [x] T061 [US7] Implement cooldown pause (2s `Task.sleep`) between inference calls in `ios/Hoibe/Services/SipDetector.swift`
- [ ] T062 [US7] Implement graceful error state on timeout (AnalysisState.error with user message) in `ios/Hoibe/Services/SipDetector.swift`
- [ ] T063 [US7] Read `ProcessInfo.thermalState` and log warning if `.serious` or `.critical` in `ios/Hoibe/Services/SipDetector.swift`

**Checkpoint**: App never hangs — timeouts and thermal states handled gracefully

---

## Phase 10: SwiftUI UI (Cross-Story)

**Goal**: Single-screen SwiftUI app tying all stories together into cohesive UX

**Independent Test**: Full user flow: launch → download → pick video → see result card

- [x] T064 [P] Create `HoibeApp.swift` entry point with `@main` in `ios/Hoibe/App/HoibeApp.swift`
- [x] T065 Implement `ContentView.swift` as single-screen coordinator in `ios/Hoibe/App/ContentView.swift`
- [x] T066 [P] Implement model download UI: progress bar, MB counter, WiFi warning, pause/resume button in `ios/Hoibe/App/ContentView.swift`
- [x] T067 [P] Implement video input UI: "Aufnehmen" and "Aus Bibliothek" buttons in `ios/Hoibe/App/ContentView.swift`
- [x] T068 Implement analysis progress UI: state-aware display (extracting frames, running gate vote X/Y, running window X/Y) in `ios/Hoibe/App/ContentView.swift`
- [x] T069 Implement result card UI: ✅/❌ icon, confidence percentage, reason_short text in `ios/Hoibe/App/ContentView.swift`
- [x] T070 Wire `ModelManager`, `SipDetector`, `FrameExtractor`, `PromptEngine` as `@StateObject`/`@EnvironmentObject` in `ios/Hoibe/App/ContentView.swift`

**Checkpoint**: Complete single-screen UI with all user flows

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Integration validation, performance verification, documentation

- [x] T071 End-to-end test on physical device: positive clip → ✅ result (iPhone 15 Pro)
- [x] T072 End-to-end test on physical device: negative clip → ❌ result (iPhone 15 Pro)
- [ ] T073 RAM measurement via Instruments: verify peak < 6.5 GB during full pipeline
- [ ] T074 Performance measurement: verify full pipeline completes < 3 minutes on iPhone 15 Pro (15s clip)
- [ ] T075 [P] Verify fixture JSON compatibility: decode all `tests/fixtures/results/*.json` with iOS `AnalysisResult`
- [ ] T076 [P] Add os_signpost markers around each inference call for Instruments timeline analysis in `ios/Hoibe/Services/SipDetector.swift`
- [ ] T077 Run quickstart.md validation (build, run, test cycle)
- [ ] T078 Verify no network traffic during analysis via Instruments Network profiler

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001–T008)
- **US4 Model Download (Phase 3)**: Depends on Foundational (T009–T015)
- **US5 Video Capture (Phase 4)**: Depends on Foundational (T009–T015)
- **US1 First Sip (Phase 5)**: Depends on US4 (ModelManager) and US5 (video input)
- **US2 Reject Posing (Phase 6)**: Depends on US1 (pipeline must produce results first)
- **US3 Invalid Clips (Phase 7)**: Depends on US1 (pipeline must be functional)
- **US6 Privacy (Phase 8)**: Depends on US4 + US1 (needs working download + inference)
- **US7 Thermal (Phase 9)**: Depends on US1 (inference pipeline must exist)
- **SwiftUI UI (Phase 10)**: Depends on US4, US5, US1 (all services must be implemented)
- **Polish (Phase 11)**: Depends on all user stories and UI complete

### User Story Dependencies

- **US4 (Model Download)**: Independent after Foundational — FIRST priority (unblocks all inference)
- **US5 (Video Capture)**: Independent after Foundational — can parallel with US4
- **US1 (First Sip)**: Depends on US4 + US5 (needs model + video input)
- **US2 (Reject Posing)**: Depends on US1 (validates negative path of existing pipeline)
- **US3 (Invalid Clips)**: Depends on US1 (adds early-exit to existing pipeline)
- **US6 (Privacy)**: Depends on US4 + US1 (verification of existing offline behavior)
- **US7 (Thermal)**: Depends on US1 (adds timeout/cooldown to existing pipeline)

### Within Each User Story

- Tests written first (where applicable)
- Models/protocols before concrete implementations
- Core logic before UI integration
- Validation before error handling

### Parallel Opportunities

- **Phase 1**: T003, T004, T005, T006, T007 all parallel
- **Phase 2**: All T009–T015 are parallel (independent model files)
- **Phase 3 + Phase 4**: US4 and US5 can proceed in parallel (independent services)
- **Phase 5**: T030–T035 tests all parallel; T036–T039 (FrameExtractor) parallel with T040–T042 (PromptEngine)
- **Phase 10**: T064, T066, T067 parallel (independent view components)

---

## Parallel Example: Phases 3 + 4 (After Foundational)

```bash
# Developer A: Model Download (US4)
T018 → T019 → T020 → T021 → T022 → T023 → T024

# Developer B: Video Capture (US5)  [parallel with Developer A]
T026 → T027 → T028 → T029
```

## Parallel Example: Phase 5 (After US4 + US5)

```bash
# Stream A: Frame Extraction
T036 → T037 → T038 → T039

# Stream B: Prompt Engine  [parallel with Stream A]
T040 → T041 → T042

# Stream C (after A + B): SipDetector orchestration
T043 → T044 → T045 → T046 → T047 → T048
```

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**Phase 1 + 2 + 3 + 4 + 5 (partial)** = Working detection on positive clips

The MVP delivers:
1. Xcode project with MLX dependency
2. Model download with progress UI
3. Video capture/selection
4. Frame extraction + inference pipeline
5. Positive first-sip detection

### Incremental Delivery

1. **Increment 1** (Phases 1–4): Model downloads, video input works → app shell functional
2. **Increment 2** (Phase 5): Core detection pipeline → app produces results
3. **Increment 3** (Phases 6–9): Negative cases, privacy, thermal → production quality
4. **Increment 4** (Phases 10–11): Polished UI, validation → release candidate
