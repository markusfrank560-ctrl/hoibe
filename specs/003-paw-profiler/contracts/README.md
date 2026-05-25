# Contracts: PawProfiler

Protocol contracts defining the interfaces between PawProfiler components. These are design-time contracts — actual implementation will be Swift source files.

## Shared Contracts (from VLMPipeline package)

These protocols are **reused from 002** via the `VLMPipeline` Swift Package:

- [`FrameExtracting`](../../002-ios-on-device/contracts/FrameExtracting.swift) — Video frame extraction with sharpness ranking
- [`ModelManaging`](../../002-ios-on-device/contracts/ModelManaging.swift) — Model download, caching, and inference
- `ChatMessage` — VLM chat message struct (role, text, images)
- `FrameData` — Extracted frames with metadata
- `ModelDownloadState` — Download state machine

## PawProfiler-Specific Contracts

| Contract | Purpose |
|----------|---------|
| [`CatGating`](CatGating.swift) | Cat detection gate (majority vote) |
| [`BehaviorAnalyzing`](BehaviorAnalyzing.swift) | Single specialist agent interface |
| [`ProfileCoordinating`](ProfileCoordinating.swift) | Hybrid coordinator (code + VLM) |
| [`CatProfiling`](CatProfiling.swift) | Pipeline orchestrator |
| [`AgentPromptBuilding`](AgentPromptBuilding.swift) | Domain-specific prompt construction |

## Dependency Graph

```
CatProfiling (orchestrator)
├── FrameExtracting (shared)
├── CatGating
│   ├── ModelManaging (shared)
│   └── AgentPromptBuilding
├── BehaviorAnalyzing (×6 agents)
│   ├── ModelManaging (shared)
│   └── AgentPromptBuilding
└── ProfileCoordinating
    ├── ModelManaging (shared) — for persona prose VLM call
    └── AgentPromptBuilding — for coordinator prompt
```
