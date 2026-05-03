# Quickstart: iOS On-Device Hoibe App

**Feature**: 002-ios-on-device  
**Date**: 2026-05-03

## Prerequisites

- macOS 14+ with Xcode 16+
- iPhone 15 Pro / 16 Pro / 16e (8 GB RAM) for device testing
- Apple Developer account (for extended memory entitlement)
- WiFi connection for initial model download (~2.5 GB)

## Setup

```bash
# 1. Clone repo and switch to feature branch
git checkout 002-ios-on-device

# 2. Open Xcode project
open ios/Hoibe.xcodeproj

# 3. Resolve Swift Package dependencies (automatic on first open)
# MLX Swift LM will be fetched via SPM
```

## Build & Run

1. Select target device (iPhone 15 Pro+ physical device recommended)
2. Build: `⌘B`
3. Run: `⌘R`
4. On first launch, tap "Download Model" — requires WiFi (~2.5 GB, ~5 min)
5. After download, select or record a video clip
6. Tap "Analyze" — result appears in 1–3 minutes

## Project Structure

```
ios/Hoibe/
├── App/              → SwiftUI entry point and main UI
├── Models/           → Codable structs and enums
├── Services/         → Core logic (ModelManager, FrameExtractor, PromptEngine, SipDetector)
└── Resources/Prompts → Bundled v3 prompt templates
```

## Running Tests

```bash
# From Xcode: ⌘U (all tests)
# Or via command line:
xcodebuild test -project ios/Hoibe.xcodeproj -scheme Hoibe -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Key Configuration

All pipeline parameters are in `PipelineConfig` (hardcoded defaults matching `hoibe.yaml`):

| Parameter | Value | Notes |
|-----------|-------|-------|
| Model | Qwen3-VL-4B-Instruct-MLX-4bit | ~2.5 GB |
| num_ctx | 4096 | Context window |
| temperature | 0.1 | Near-deterministic |
| Gate votes | 3 | Majority vote |
| Gate timeout | 45s | Per-vote |
| Window count | 3 | Overlapping |
| Window min_span | 0.6 | 60% of clip |
| Window timeout | 90s | Per-window |
| Prompts | v3 | Bundled in app |

## Shared Resources

The app bundles these files from the repo root:
- `prompts/v3/system_prompt.txt`
- `prompts/v3/user_prompt_template.txt`
- `prompts/v3/fill_level_prompt.txt`

Test fixture JSONs from `tests/fixtures/results/` are used for unit test validation.

## Entitlements

The app requires `com.apple.developer.kernel.increased-memory-limit` in `Hoibe.entitlements` to access >4 GB RAM for model inference.

## Debugging Tips

- Use Instruments > Memory Graph to monitor RAM during inference
- Use `os_signpost` markers around each inference call for timeline analysis
- If inference hangs: check `think=false` is being passed (prevents reasoning loop)
- If Jetsam kills: reduce `num_ctx` or check for leaked image buffers
