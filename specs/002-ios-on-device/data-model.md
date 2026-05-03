# Data Model: iOS On-Device First-Sip Detection

**Feature**: 002-ios-on-device  
**Date**: 2026-05-03

## Entities

### AnalysisResult

Structured output from the first-sip detection pipeline. Identical schema to Python 001.

| Field | Type | Validation | Description |
|-------|------|-----------|-------------|
| `first_sip_detected` | Bool | required | Primary detection decision |
| `confidence` | Double | 0.0–1.0 | Model confidence in decision |
| `reason_short` | String | required | One-sentence explanation |
| `face_visible` | Bool | required | Whether a face was detected |
| `drinking_object_visible` | Bool | required | Whether a drink container was visible |
| `mouth_contact_likely` | Bool | required | Whether lip-to-rim contact observed |
| `beer_likely` | String (enum) | "true"/"false"/"unknown" | Whether the container likely holds beer |
| `beer_fill_level` | BeerFillLevel | enum value | Estimated fill level |
| `model_name` | String | required | Model identifier used |
| `analysis_version` | String | required | Prompt/pipeline version |
| `analyzed_at` | String? | ISO 8601 | UTC timestamp of analysis |
| `source_video` | String? | — | Local file reference |
| `run_config` | [String: Any]? | — | Pipeline configuration snapshot |

### BeerFillLevel (enum)

| Value | Semantics |
|-------|-----------|
| `full` | Liquid at rim or within 1cm |
| `mostlyFull` | 75–100% filled |
| `half` | 40–60% filled |
| `mostlyEmpty` | < 25% filled |
| `empty` | No visible liquid |
| `unknown` | Cannot determine |

### ModelDownloadState (enum + associated values)

| State | Associated Value | Description |
|-------|-----------------|-------------|
| `.notDownloaded` | — | Model not present on device |
| `.downloading` | `progress: Double` | Active download (0.0–1.0) |
| `.paused` | `bytesDownloaded: Int64` | Download paused/interrupted |
| `.ready` | — | Model cached and available |
| `.error` | `message: String` | Download or validation failed |

### FrameData

| Field | Type | Description |
|-------|------|-------------|
| `frames` | [CGImage] | Extracted video frames |
| `timestamps` | [Double] | Frame timestamps in seconds |
| `sharpnessScores` | [Double] | Laplacian variance per frame |

### PipelineConfig

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `gateVotes` | Int | 3 | Number of fill-level votes |
| `gateTimeout` | TimeInterval | 45.0 | Per-vote inference timeout |
| `windowCount` | Int | 3 | Number of sliding windows |
| `windowMinSpan` | Double | 0.6 | Minimum window span (0–1) |
| `windowTimeout` | TimeInterval | 90.0 | Per-window inference timeout |
| `numCtx` | Int | 4096 | Context window size |
| `temperature` | Double | 0.1 | Sampling temperature |
| `cooldown` | TimeInterval | 2.0 | Pause between inference calls |
| `rejectLevels` | Set<BeerFillLevel> | {half, mostlyEmpty, empty} | Gate rejection thresholds |

### VideoClip

| Field | Type | Validation | Description |
|-------|------|-----------|-------------|
| `url` | URL | local file | Video file URL |
| `duration` | TimeInterval | 5.0–15.0 | Clip length in seconds |
| `codec` | AVCodecType | H.264/HEVC | Video codec |

## Relationships

```
VideoClip ──extracts──▶ FrameData
FrameData ──analyzed by──▶ SipDetector (uses PipelineConfig)
SipDetector ──produces──▶ AnalysisResult
ModelManager ──manages──▶ ModelDownloadState
```

## State Transitions

### ModelDownloadState

```
notDownloaded ──startDownload──▶ downloading
downloading ──progress──▶ downloading (updated progress)
downloading ──pause/networkLoss──▶ paused
downloading ──complete──▶ ready
downloading ──failure──▶ error
paused ──resume──▶ downloading
error ──retry──▶ downloading
```

### Analysis Pipeline Flow

```
idle ──selectVideo──▶ validating
validating ──valid──▶ extractingFrames
validating ──invalid──▶ error (too short/long/wrong codec)
extractingFrames ──done──▶ runningGate
runningGate ──rejected──▶ result (negative, early)
runningGate ──passed──▶ runningWindows
runningWindows ──positive──▶ result (early exit)
runningWindows ──allNegative──▶ result (negative)
runningWindows ──timeout──▶ error
```
