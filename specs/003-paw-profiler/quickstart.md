# Quickstart: PawProfiler App

**Feature**: 003-paw-profiler  
**Date**: 2026-05-25

## Prerequisites

- macOS 14+ with Xcode 16+
- iPhone 15 Pro / 16 Pro / 16e (8 GB RAM) for device testing
- Apple Developer account (for extended memory entitlement)
- WiFi connection for initial model download (~2.5 GB)
- A cat video (15–90s, MP4/MOV) for testing

## Setup

```bash
# 1. Clone repo and switch to feature branch
git checkout 003-paw-profiler

# 2. Open PawProfiler Xcode project
open PawProfiler/PawProfiler.xcodeproj

# 3. SPM resolves automatically:
#    - VLMPipeline (local package from repo root)
#    - MLX Swift LM v3.31.3+
```

## Build & Run

1. Select target device (iPhone 15 Pro+ physical device recommended)
2. Build: `⌘B`
3. Run: `⌘R`
4. On first launch, tap "Download Model" — requires WiFi (~2.5 GB, ~5 min)
5. After download, select a cat video from library (15–90s)
6. Choose profile mode: Quick (~10 min) or Deep (~25 min)
7. Tap "Analyze" — progress shows per-agent status
8. Result: Cat Persona Card with radar chart, archetype, observations

## Project Structure

```
VLMPipeline/                    ← Shared local Swift Package
├── Package.swift
└── Sources/VLMPipeline/
    ├── Protocols/
    │   ├── FrameExtracting.swift    (from 002)
    │   ├── ModelManaging.swift      (from 002)
    │   └── PromptBuilding.swift     (base protocol)
    ├── Models/
    │   ├── ChatMessage.swift        (from 002)
    │   ├── FrameData.swift          (from 002)
    │   └── ModelDownloadState.swift  (from 002)
    └── Services/
        ├── FrameExtractor.swift     (from 002)
        └── ModelManager.swift       (from 002)

PawProfiler/                    ← PawProfiler app
├── PawProfiler.xcodeproj
└── PawProfiler/
    ├── App/
    │   ├── PawProfilerApp.swift     @main entry point
    │   └── ContentView.swift        Main UI
    ├── Models/
    │   ├── AgentResult.swift
    │   ├── CatGateResult.swift
    │   ├── CompositeProfile.swift
    │   ├── FelineFiveScores.swift
    │   ├── PawProfilerConfig.swift
    │   ├── AnalysisSession.swift
    │   └── CatAnalysisState.swift
    ├── Protocols/
    │   ├── CatGating.swift
    │   ├── BehaviorAnalyzing.swift
    │   ├── ProfileCoordinating.swift
    │   ├── CatProfiling.swift
    │   └── AgentPromptBuilding.swift
    ├── Agents/
    │   ├── BaseAgent.swift          Shared agent logic
    │   ├── CatGate.swift
    │   ├── PersonalityAgent.swift
    │   ├── SocialBehaviorAgent.swift
    │   ├── PlayActivityAgent.swift
    │   ├── StressWelfareAgent.swift
    │   ├── HealthBehaviorAgent.swift
    │   └── BreedArchetypeAgent.swift
    ├── Services/
    │   ├── CatProfiler.swift        Pipeline orchestrator
    │   ├── ProfileCoordinator.swift  Hybrid coordinator
    │   ├── ArchetypeResolver.swift   Deterministic archetype lookup
    │   └── AgentPromptEngine.swift   Agent-specific prompts
    ├── Views/
    │   ├── PersonaCardView.swift     Cat Persona Card
    │   ├── RadarChartView.swift      Feline Five radar chart
    │   ├── AgentProgressView.swift   Agent progress indicator
    │   ├── AgentDetailView.swift     Per-agent reasoning drill-down
    │   └── GateRejectedView.swift    No-cat / not-a-cat result
    └── Resources/
        └── Prompts/
            ├── gate/v1/system.txt
            ├── personality/v1/system.txt
            ├── social/v1/system.txt
            ├── play/v1/system.txt
            ├── stress/v1/system.txt
            ├── health/v1/system.txt
            ├── breed/v1/system.txt
            └── coordinator/v1/system.txt

PawProfilerTests/
├── GateTests.swift
├── AgentResultParsingTests.swift
├── AgentPromptEngineTests.swift
├── CoordinatorTests.swift
├── ArchetypeResolverTests.swift
├── PipelineIntegrationTests.swift
├── Mocks/
│   └── MockModelManager.swift
└── Fixtures/
    └── (labeled JSON fixtures)
└── Fixtures/
    └── (labeled JSON fixtures)
```

## Running Tests

```bash
# From Xcode: ⌘U (all tests)
# Or via command line:
xcodebuild test -project PawProfiler/PawProfiler.xcodeproj \
  -scheme PawProfiler \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Key Configuration

All pipeline parameters in `PawProfilerConfig`:

| Parameter | Quick Mode | Deep Mode | Notes |
|-----------|-----------|-----------|-------|
| Model | Qwen3-VL-4B-MLX-4bit | same | ~2.5 GB |
| Gate votes | 3 | 3 | Majority vote |
| Gate timeout | 45s | 45s | Per vote |
| Agent timeout | 90s | 90s | Per call |
| Windows/agent | 1 | 3 | Key mode difference |
| Frames/call | 3 | 3 | Sharpest frames |
| Cooldown | 2s | 2s | Between calls |
| Thermal cooldown | 5s | 5s | At `.serious` |
| Total calls | 8 | 20 | gate + agents + coord |
| Est. time | ~10 min | ~25 min | On iPhone 15 Pro |

## Agent Overview

| # | Agent | Domain | Key Literature |
|---|-------|--------|---------------|
| 1 | Personality | Feline Five traits | Litchfield et al. 2017 |
| 2 | Social | Attachment, bonding | Vitale Shreve & Udell 2017 |
| 3 | Play | Activity, predatory | Hall et al. 2002 |
| 4 | Stress | Anxiety, welfare | Kessler & Turner 1997 |
| 5 | Health | Pain indicators | Robertson 2008 |
| 6 | Breed | Breed, archetype | Salonen et al. 2019 |

## Entitlements

Same as Hoibe (002): `com.apple.developer.kernel.increased-memory-limit` in entitlements for >4 GB RAM access.
