# Implementation Plan: iOS On-Device First-Sip Detection

**Branch**: `002-ios-on-device` | **Date**: 2026-05-03 | **Spec**: `specs/002-ios-on-device/spec.md`
**Input**: Feature specification from `/specs/002-ios-on-device/spec.md`

## Summary

Port the hoibe first-sip detection pipeline to run entirely on-device on iPhone using MLX Swift LM with Qwen3-VL-4B-Instruct-MLX-4bit. The app captures or selects a 5–15s video, extracts frames, runs a fill-level gate and sliding-window analysis locally, and presents a structured pass/fail result. No network access during analysis. Model downloaded once from HuggingFace (~2.5 GB).

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 16)  
**Primary Dependencies**: MLX Swift LM v3.31.3+ (SPM), AVFoundation, Accelerate, PhotosUI  
**Storage**: FileManager (model cache in app container, ~2.5 GB)  
**Testing**: XCTest + Swift Testing  
**Target Platform**: iOS 17.0+ (iPhone 15 Pro, 16 Pro, 16e — 8 GB RAM)  
**Project Type**: mobile-app (single-screen SwiftUI)  
**Performance Goals**: Full pipeline < 3 minutes per 15s clip on iPhone 15 Pro  
**Constraints**: RAM peak < 6.5 GB, offline-only analysis, no network during inference, call_timeout 90s/window 45s/gate  
**Scale/Scope**: 5 core Swift modules, 1 SwiftUI screen, bundled v3 prompts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Privacy-First | ✅ PASS | All analysis on-device, no cloud upload, offline after model download |
| II. Local Ollama Inference | ⚠️ JUSTIFIED | Uses MLX Swift LM (not Ollama) — same model class (Qwen3-VL-4B), local inference, no proprietary cloud APIs. Ollama has no iOS runtime; MLX is the equivalent local inference engine on Apple Silicon. See Complexity Tracking. |
| III. Structured Output Only | ✅ PASS | v3 prompts produce lean 3-field JSON; `AnalysisResult` schema identical to 001 |
| IV. Hybrid Architecture | ✅ PASS | Fill-level gate (rule: majority vote) separated from VLM window inference (semantic) |
| V. Async & Resource-Aware | ✅ PASS | Swift async/await, timeouts per call, cooldown between calls, thermal awareness |
| VI. Testability & Precision | ✅ PASS | Same test fixtures as 001, precision ≥ 85% target, XCTest suite |
| VII. Versionierung | ✅ PASS | v3 prompts bundled, `analysis_version` field, `model_name` field in results |

## Project Structure

### Documentation (this feature)

```text
specs/002-ios-on-device/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (Swift protocol contracts)
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
ios/
├── Hoibe.xcodeproj/
├── Hoibe/
│   ├── App/
│   │   ├── HoibeApp.swift           # @main entry point
│   │   └── ContentView.swift        # Single-screen SwiftUI UI
│   ├── Models/
│   │   ├── AnalysisResult.swift     # Codable result schema (mirrors Python)
│   │   ├── BeerFillLevel.swift      # Enum
│   │   └── ModelDownloadState.swift # Download state machine
│   ├── Services/
│   │   ├── ModelManager.swift       # HF download/cache, progress tracking
│   │   ├── FrameExtractor.swift     # AVAssetImageGenerator + sharpness ranking
│   │   ├── PromptEngine.swift       # Loads bundled v3 prompts, formats messages
│   │   └── SipDetector.swift        # Pipeline orchestrator (gate → windows → result)
│   ├── Resources/
│   │   └── Prompts/
│   │       ├── system_prompt.txt
│   │       ├── user_prompt_template.txt
│   │       └── fill_level_prompt.txt
│   └── Hoibe.entitlements           # Extended memory entitlement
├── HoibeTests/
│   ├── FrameExtractorTests.swift
│   ├── PromptEngineTests.swift
│   ├── SipDetectorTests.swift
│   ├── ResultParsingTests.swift
│   └── Fixtures/
│       └── (symlink or copy of tests/fixtures/results/*.json)
└── Package.swift (or SPM via Xcode project)
```

**Structure Decision**: Standalone iOS app in `ios/` subdirectory within the existing repo. Shares `prompts/v3/` content (bundled as app resources) and test fixture JSON files. No backend/API component — fully self-contained mobile app.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle II: MLX instead of Ollama | Ollama has no iOS runtime. MLX Swift LM is the Apple-maintained equivalent for on-device inference on Apple Silicon. Same model (Qwen3-VL-4B), same privacy guarantees. | Running Ollama on iPhone is not possible; the constitution's intent (local, no cloud) is fully preserved. |
