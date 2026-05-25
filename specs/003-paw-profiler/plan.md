# Implementation Plan: PawProfiler — Cat Behavior Profiling Pipeline

**Branch**: `003-paw-profiler` | **Date**: 2026-05-25 | **Spec**: `specs/003-paw-profiler/spec.md`
**Input**: Feature specification from `/specs/003-paw-profiler/spec.md`

## Summary

Build PawProfiler, a standalone iOS app that profiles cat behavior and personality using a multi-agent VLM pipeline running entirely on-device. The app captures or selects a 15–90s video, extracts frames, runs a cat detection gate, dispatches 6 specialist behavior agents (Personality, Social, Play, Stress, Health, Breed) sequentially, and synthesizes results via a hybrid coordinator into a Cat Persona Card with Feline-Five radar chart, archetype label, and behavioral observations. Shared pipeline infrastructure (frame extraction, model management, inference) is extracted into a local Swift Package (`VLMPipeline`) reused by both Hoibe (002) and PawProfiler. No network access during analysis.

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 16)  
**Primary Dependencies**: MLX Swift LM v3.31.3+ (SPM), AVFoundation, Accelerate, PhotosUI, Charts (SwiftUI)  
**Storage**: FileManager (model cache in app container, ~2.5 GB)  
**Testing**: XCTest + Swift Testing  
**Target Platform**: iOS 17.0+ (iPhone 15 Pro, 16 Pro, 16e — 8 GB RAM)  
**Project Type**: mobile-app (multi-screen SwiftUI), local Swift Package (VLMPipeline)  
**Performance Goals**: Quick Profile < 12 min, Deep Profile < 30 min on iPhone 15 Pro  
**Constraints**: RAM peak < 6.5 GB, offline-only analysis, sequential inference (1 at a time), 8 total VLM calls (Quick: 1 gate + 6 agents + 1 coordinator) / 20 (Deep: 1 gate + 18 agent windows + 1 coordinator)  
**Scale/Scope**: VLMPipeline package + PawProfiler app (6 agents, 1 coordinator, 8 agent prompts, persona card UI)  
**Base Feature**: 002-ios-on-device (provides shared infrastructure via VLMPipeline extraction)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Privacy-First | ✅ PASS | All analysis on-device, no cloud upload, offline after model download. Same guarantees as 002 |
| II. Local Inference | ⚠️ JUSTIFIED | Uses MLX Swift LM (not Ollama) — same model class (Qwen3-VL-4B), local inference, no proprietary cloud APIs. Justified in 002; same rationale applies. See Complexity Tracking |
| III. Structured Output Only | ✅ PASS | All agent outputs are structured JSON. Coordinator VLM produces JSON with narrative fields (`persona_description`, `top_observations[]`) — JSON envelope satisfies Principle III; narrative content is for user-facing display only |
| IV. Hybrid Architecture | ✅ PASS | Code-based score aggregation + archetype lookup (deterministic) separated from VLM persona prose (semantic). Cat Gate is rule-based (majority vote). Agents are VLM reviewers, not sole truth |
| V. Async & Resource-Aware | ✅ PASS | Swift async/await, sequential agent execution, configurable cooldowns, thermal state monitoring with pause at `.critical` |
| VI. Testability & Precision | ✅ PASS | 7 test categories, 10+ labeled fixtures, MockModelManager for deterministic testing, confidence-weighted scoring. Precision via `not_observable` instead of forced guesses |
| VII. Versionierung | ✅ PASS | Per-agent prompt versioning (`{agent_id}/v{N}/system.txt`), `analysis_version` in output, `model_name` field, archetype table versioned in coordinator prompt |

**Post-Phase-1 Re-check**: All principles remain satisfied. Hybrid Coordinator design (FR-010) strengthens Principle IV alignment — code handles deterministic decisions, VLM handles natural language only.

## Project Structure

### Documentation (this feature)

```text
specs/003-paw-profiler/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (Swift protocol contracts)
│   ├── README.md
│   ├── CatGating.swift
│   ├── BehaviorAnalyzing.swift
│   ├── ProfileCoordinating.swift
│   ├── CatProfiling.swift
│   └── AgentPromptBuilding.swift
├── tasks.md             # Phase 2 output (created by /speckit.tasks)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
VLMPipeline/                         ← NEW: Shared Swift Package
├── Package.swift
├── Sources/VLMPipeline/
│   ├── Protocols/
│   │   ├── FrameExtracting.swift    (extracted from ios/Hoibe/)
│   │   ├── ModelManaging.swift      (extracted from ios/Hoibe/)
│   │   └── PromptBuilding.swift     (base protocol)
│   ├── Models/
│   │   ├── ChatMessage.swift        (extracted from ios/Hoibe/)
│   │   ├── FrameData.swift          (extracted from ios/Hoibe/)
│   │   ├── ModelDownloadState.swift  (extracted from ios/Hoibe/)
│   │   └── PipelineConfig.swift     (extracted from ios/Hoibe/)
│   └── Services/
│       ├── FrameExtractor.swift     (extracted from ios/Hoibe/)
│       └── ModelManager.swift       (extracted from ios/Hoibe/)
└── Tests/VLMPipelineTests/
    └── (shared infra tests)

PawProfiler/                         ← NEW: PawProfiler app
├── PawProfiler.xcodeproj/
├── PawProfiler/
│   ├── PawProfiler.entitlements
│   ├── Info.plist
│   ├── App/
│   │   ├── PawProfilerApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── AgentResult.swift
│   │   ├── CatGateResult.swift
│   │   ├── CompositeProfile.swift
│   │   ├── FelineFiveScores.swift
│   │   ├── AnalysisSession.swift
│   │   └── PawProfilerConfig.swift
│   ├── Agents/
│   │   ├── CatGate.swift
│   │   ├── BaseAgent.swift              Shared agent logic
│   │   ├── PersonalityAgent.swift
│   │   ├── SocialBehaviorAgent.swift
│   │   ├── PlayActivityAgent.swift
│   │   ├── StressWelfareAgent.swift
│   │   ├── HealthBehaviorAgent.swift
│   │   └── BreedArchetypeAgent.swift
│   ├── Services/
│   │   ├── CatProfiler.swift           Pipeline orchestrator
│   │   ├── ProfileCoordinator.swift     Hybrid coordinator
│   │   ├── ArchetypeResolver.swift      Deterministic archetype lookup
│   │   └── AgentPromptEngine.swift      Agent-specific prompt builder
│   ├── Views/
│   │   ├── PersonaCardView.swift        Cat Persona Card
│   │   ├── RadarChartView.swift         Feline-Five radar chart
│   │   ├── AgentProgressView.swift      "Agent 3/6: Stress..." UI
│   │   ├── AgentDetailView.swift        Per-agent reasoning drill-down
│   │   └── GateRejectedView.swift       No-cat / not-a-cat result
│   └── Resources/
│       └── Prompts/
│           ├── gate/v1/system.txt
│           ├── personality/v1/system.txt
│           ├── social/v1/system.txt
│           ├── play/v1/system.txt
│           ├── stress/v1/system.txt
│           ├── health/v1/system.txt
│           ├── breed/v1/system.txt
│           └── coordinator/v1/system.txt
└── PawProfilerTests/
    ├── GateTests.swift
    ├── AgentResultParsingTests.swift
    ├── AgentPromptEngineTests.swift
    ├── CoordinatorTests.swift
    ├── ArchetypeResolverTests.swift
    ├── PipelineIntegrationTests.swift
    ├── Mocks/
    │   └── MockModelManager.swift
    └── Fixtures/
    ├── ArchetypeResolverTests.swift
    ├── PipelineIntegrationTests.swift
    └── Fixtures/
        └── (labeled JSON fixtures per test category)

ios/Hoibe/                           ← MODIFIED: imports VLMPipeline
├── (existing structure, imports VLMPipeline instead of local copies)
```

**Structure Decision**: Two separate Xcode projects (Hoibe, PawProfiler) sharing a local Swift Package (`VLMPipeline`). Clean separation of domain-specific logic (sip detection vs. cat profiling) while reusing infrastructure. `VLMPipeline/Package.swift` references `MLX Swift LM` as dependency.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle II: MLX instead of Ollama | Ollama has no iOS runtime. MLX Swift LM is the Apple-maintained equivalent for on-device inference on Apple Silicon. Same model, same privacy. Justified in 002. | Running Ollama on iPhone is impossible; constitution intent (local, no cloud) fully preserved |
| Principle III: Narrative fields in JSON | Coordinator VLM produces `persona_description` and `top_observations[]` as human-readable text inside JSON envelope. Content is for user display only; all scoring/decisions are code-based | Pure template strings would feel robotic and lack contextual personality |
| Constitution clip duration: 15–90s vs. 5–15s | Cat behavior assessment requires longer observation (body language changes, interaction patterns, play sequences). 15s minimum ensures sufficient behavioral evidence | 5–15s clips (per constitution) are too short for multi-agent behavioral analysis; constitution specifies duration as "feature-dependent" (5–15s for Sip Detection, 15–90s for Cat Profiling) |

---

## Phase 0: Research & Validation

**Status**: Complete — see [research.md](research.md)

### Key Decisions

| Topic | Decision | Rationale |
|-------|----------|-----------|
| R1: VLM capability | Qwen3-VL-4B can analyze cat body language from stills | Prominent visual signals (ears, tail, posture); validated in 002 for object/scene analysis |
| R2: Multi-agent architecture | 6 sequential agents + shared frame set | iPhone memory constraint; domain isolation improves testability |
| R3: Hybrid coordinator | Code aggregation + 1 VLM call for prose | Deterministic scores, natural persona text |
| R4: Scientific framework | Feline Five (Litchfield 2017) as primary | Most validated cat personality framework (N=2,802) |
| R5: Package extraction | Local Swift Package `VLMPipeline` | Clean sharing, no remote dependency management |
| R6: Thermal management | Reuse 002 pattern + extended cooldowns | 8+ sequential inferences at thermal boundary |
| R7: Frame strategy | 8 candidates → rank by sharpness → distribute | Temporal diversity + quality filtering |

---

## Phase 1: Design & Contracts

**Status**: Complete — see [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

### Key Entities

| Entity | Purpose | Reference |
|--------|---------|-----------|
| CatGateResult | Cat detection gate output | [data-model.md](data-model.md#catgateresult) |
| AgentResult | Single specialist agent output | [data-model.md](data-model.md#agentresult) |
| FelineFiveScores | Aggregated trait scores (0.0–1.0) | [data-model.md](data-model.md#felinefivescores) |
| CompositeProfile | Full synthesized profile | [data-model.md](data-model.md#compositeprofile) |
| AnalysisSession | Session metadata wrapper | [data-model.md](data-model.md#analysissession) |
| PawProfilerConfig | Pipeline configuration | [data-model.md](data-model.md#pawprofilerconfig-extends-pipelineconfig) |
| Archetype | Trait-based archetype lookup | [data-model.md](data-model.md#archetype-lookup-table) |

### Protocol Contracts

| Contract | File | Purpose |
|----------|------|---------|
| CatGating | [CatGating.swift](contracts/CatGating.swift) | Cat detection gate |
| BehaviorAnalyzing | [BehaviorAnalyzing.swift](contracts/BehaviorAnalyzing.swift) | Single agent interface |
| ProfileCoordinating | [ProfileCoordinating.swift](contracts/ProfileCoordinating.swift) | Hybrid coordinator |
| CatProfiling | [CatProfiling.swift](contracts/CatProfiling.swift) | Pipeline orchestrator |
| AgentPromptBuilding | [AgentPromptBuilding.swift](contracts/AgentPromptBuilding.swift) | Prompt construction |

### Shared Contracts (from VLMPipeline)

| Contract | Source | Reused as-is |
|----------|--------|-------------|
| FrameExtracting | 002 | ✅ |
| ModelManaging | 002 | ✅ |
| ChatMessage | 002 | ✅ |
| FrameData | 002 | ✅ |
| ModelDownloadState | 002 | ✅ |

---

## Phase 2: Implementation Plan

### Phase 2.0 — VLMPipeline Package Extraction

Extract shared infrastructure from `ios/Hoibe/` into `VLMPipeline/` local Swift Package.

| Step | Description | Files |
|------|-------------|-------|
| 2.0.1 | Create `VLMPipeline/Package.swift` with MLX Swift LM dependency | `VLMPipeline/Package.swift` |
| 2.0.2 | Move protocols to package: `FrameExtracting`, `ModelManaging`, base `PromptBuilding` | `VLMPipeline/Sources/VLMPipeline/Protocols/` |
| 2.0.3 | Move models to package: `ChatMessage`, `FrameData`, `ModelDownloadState`, `PipelineConfig` | `VLMPipeline/Sources/VLMPipeline/Models/` |
| 2.0.4 | Move implementations: `FrameExtractor`, `ModelManager` | `VLMPipeline/Sources/VLMPipeline/Services/` |
| 2.0.5 | Update Hoibe to import `VLMPipeline` as local package dependency | `ios/Hoibe.xcodeproj`, `ios/Hoibe/` imports |
| 2.0.6 | Verify Hoibe builds and tests pass after extraction | `xcodebuild test` |

**Gate**: Hoibe must build and all existing tests pass before proceeding.

### Phase 2.1 — PawProfiler Project Setup

| Step | Description | Files |
|------|-------------|-------|
| 2.1.1 | Create PawProfiler Xcode project with SwiftUI lifecycle | `PawProfiler/PawProfiler.xcodeproj` |
| 2.1.2 | Add VLMPipeline as local package dependency | Xcode project config |
| 2.1.3 | Add extended memory entitlement | `PawProfiler/PawProfiler.entitlements` |
| 2.1.4 | Create model files: `AgentResult`, `CatGateResult`, `CompositeProfile`, `FelineFiveScores`, `PawProfilerConfig`, `AnalysisSession` | `PawProfiler/PawProfiler/Models/` |
| 2.1.5 | Verify project builds with shared package | `xcodebuild build` |

### Phase 2.2 — Cat Gate

| Step | Description | Files |
|------|-------------|-------|
| 2.2.1 | Create gate system prompt (`gate/v1/system.txt`) | `Resources/Prompts/gate/v1/` |
| 2.2.2 | Implement `CatGate` conforming to `CatGating` protocol | `Agents/CatGate.swift` |
| 2.2.3 | Implement gate: 1 VLM call with 3 frames as multi-image input, majority-vote over JSON output (≥2/3 = cat detected) | `Agents/CatGate.swift` |
| 2.2.4 | Unit tests: gate with mock responses (cat, no-cat, not-a-cat, multiple) | `PawProfilerTests/GateTests.swift` |

### Phase 2.3 — Agent Prompt Engine

| Step | Description | Files |
|------|-------------|-------|
| 2.3.1 | Create `AgentPromptEngine` conforming to `AgentPromptBuilding` | `Services/AgentPromptEngine.swift` |
| 2.3.2 | Create 6 agent system prompts with embedded research context | `Resources/Prompts/{agent}/v1/system.txt` |
| 2.3.3 | Create coordinator system prompt | `Resources/Prompts/coordinator/v1/system.txt` |
| 2.3.4 | Unit tests: prompt construction, message format, template loading | `PawProfilerTests/AgentPromptEngineTests.swift` |

**Agent prompt structure** (each agent):
- System prompt: role definition, observable indicators, research citations, JSON output schema
- User prompt: frames as images + "Analyze this cat's {domain}" instruction

### Phase 2.4 — Specialist Agents

| Step | Description | Files |
|------|-------------|-------|
| 2.4.1 | Implement base `BaseAgent` with shared logic (timeout, JSON parsing, error handling) | `Agents/BaseAgent.swift` |
| 2.4.2 | Implement `PersonalityAgent` (Feline Five trait scoring) | `Agents/PersonalityAgent.swift` |
| 2.4.3 | Implement `SocialBehaviorAgent` (attachment, bonding, vocalization) | `Agents/SocialBehaviorAgent.swift` |
| 2.4.4 | Implement `PlayActivityAgent` (movement, play style, activity) | `Agents/PlayActivityAgent.swift` |
| 2.4.5 | Implement `StressWelfareAgent` (CSS indicators, anxiety signals) | `Agents/StressWelfareAgent.swift` |
| 2.4.6 | Implement `HealthBehaviorAgent` (pain indicators, vet flags) | `Agents/HealthBehaviorAgent.swift` |
| 2.4.7 | Implement `BreedArchetypeAgent` (breed features, visual traits) | `Agents/BreedArchetypeAgent.swift` |
| 2.4.8 | Unit tests: each agent with mock VLM responses → verify AgentResult schema | `PawProfilerTests/AgentResultParsingTests.swift` |

### Phase 2.5 — Hybrid Coordinator

| Step | Description | Files |
|------|-------------|-------|
| 2.5.1 | Implement `ArchetypeResolver` — deterministic archetype lookup from Feline-Five scores | `Services/ArchetypeResolver.swift` |
| 2.5.2 | Implement `ProfileCoordinator` — code-based score aggregation + VLM persona prose | `Services/ProfileCoordinator.swift` |
| 2.5.3 | Score aggregation: confidence-weighted average per trait across agents that report trait_scores | `Services/ProfileCoordinator.swift` |
| 2.5.4 | Partial-result handling: skip `not_observable` / `timed_out` agents in aggregation | `Services/ProfileCoordinator.swift` |
| 2.5.5 | Unit tests: archetype lookup (all archetypes + fallback), score aggregation, partial results | `PawProfilerTests/CoordinatorTests.swift`, `ArchetypeResolverTests.swift` |

**Aggregation formula**:
$$\text{trait\_score} = \frac{\sum_{a \in A} w_a \cdot s_{a,t}}{\sum_{a \in A} w_a}$$
where $w_a = \text{confidence}_a$ and $s_{a,t}$ = agent $a$'s score for trait $t$, $A$ = set of agents that reported trait $t$.

### Phase 2.6 — Pipeline Orchestrator

| Step | Description | Files |
|------|-------------|-------|
| 2.6.1 | Implement `CatProfiler` conforming to `CatProfiling` — full pipeline orchestration | `Services/CatProfiler.swift` |
| 2.6.2 | Pipeline flow: extract frames → gate → 6 agents (sequential) → coordinator → profile | `Services/CatProfiler.swift` |
| 2.6.3 | Implement `CatAnalysisState` as `@Observable` for SwiftUI binding | `Models/CatAnalysisState.swift` |
| 2.6.4 | Implement Quick/Deep mode switching (windowsPerAgent: 1 vs. 3) | `Services/CatProfiler.swift` |
| 2.6.5 | Implement cancellation support | `Services/CatProfiler.swift` |
| 2.6.6 | Implement thermal management (cooldown escalation) | `Services/CatProfiler.swift` |
| 2.6.7 | Integration tests: full pipeline with MockModelManager | `PawProfilerTests/PipelineIntegrationTests.swift` |

### Phase 2.7 — UI

| Step | Description | Files |
|------|-------------|-------|
| 2.7.1 | `ContentView` — video selection (PhotosPicker), mode toggle, analyze button | `App/ContentView.swift` |
| 2.7.2 | `AgentProgressView` — "Agent 3/6: Stress & Welfare..." with progress | `Views/AgentProgressView.swift` |
| 2.7.3 | `PersonaCardView` — archetype label, persona description, observations | `Views/PersonaCardView.swift` |
| 2.7.4 | `RadarChartView` — Feline-Five radar chart using SwiftUI Charts | `Views/RadarChartView.swift` |
| 2.7.5 | `GateRejectedView` — no cat / not a cat result with guidance | `Views/GateRejectedView.swift` |
| 2.7.6 | Model download UI (reuse pattern from 002) | `App/ContentView.swift` |

---

## Phase 3: Test Strategy

### Test Categories (minimum corpus for v1)

| Category | Description | Expected Gate | Expected Agents | Min. Fixtures |
|----------|-------------|---------------|-----------------|---------------|
| `playful-cat` | Active, playing, good visibility | `cat_detected` | All 6, high E/I | 2 |
| `relaxed-cat` | Resting, relaxed posture | `cat_detected` | Low activity scores | 2 |
| `stressed-cat` | Flattened ears, ducking, stress signals | `cat_detected` | Stress flags active | 1 |
| `no-cat` | Empty room, furniture only | `no_cat_detected` | None started | 2 |
| `not-a-cat` | Dog, rabbit, other animal | `not_a_cat` | None started | 1 |
| `dark-clip` | Low lighting, partial visibility | `cat_detected` | Low confidence, quality warning | 1 |
| `multiple-cats` | Two or more cats visible | `cat_detected` | Dominant cat analyzed | 1 |

**Minimum v1 corpus**: 10 labeled fixtures

### Test Layers

| Layer | What | How | Framework |
|-------|------|-----|-----------|
| **Schema Parsing** | AgentResult, CompositeProfile, CatGateResult JSON decoding | Fixture JSON → Codable decode → field assertions | XCTest / Swift Testing |
| **Agent Unit** | Single agent produces correct schema | Mock `ModelManaging.generate()` → fixture response → verify schema | XCTest + MockModelManager |
| **Gate Unit** | Majority-vote logic (≥2/3 threshold) | 3 mock gate responses → verify cat_detected/no_cat threshold | XCTest |
| **Archetype Unit** | Archetype lookup from score patterns | Known FelineFiveScores → verify archetype label + fallback | XCTest |
| **Coordinator Unit** | Score aggregation, partial-result handling | Feed 6 AgentResults (some not_observable) → verify CompositeProfile | XCTest |
| **Pipeline Integration** | Gate → Agents → Coordinator end-to-end (mocked VLM) | Full pipeline with MockModelManager returning fixture responses | XCTest |
| **E2E (on-device)** | Real VLM inference on real cat clip | Labeled clip → real inference → compare with ground truth | Manual / device CI |

### Mock Strategy

`MockModelManager` (same pattern as 002): returns pre-recorded VLM responses from fixtures instead of real inference. Enables:
- Deterministic tests without model download
- CI-friendly (no GPU/MLX required)
- Per-agent response injection for edge case testing

### Fixture Schema

```json
{
  "ground_truth": {
    "category": "playful-cat",
    "description": "Orange tabby playing with feather toy",
    "expected_gate": "cat_detected",
    "expected_archetype": "The Midnight Gremlin",
    "expected_traits": { "extraversion": "high", "impulsiveness": "high" },
    "expected_stress": false,
    "labeler": "manual",
    "labeled_at": "2026-05-25"
  },
  "mock_responses": {
    "gate": { "cat_detected": true, "confidence": 0.95 },
    "personality_agent": { "agent_id": "personality", "status": "completed", ... },
    "stress_agent": { "agent_id": "stress", "status": "completed", ... }
  },
  "last_run": null
}
```

---

## Dependency Graph

```
Phase 2.0 (VLMPipeline extraction)
    │
    ├──▶ Phase 2.1 (Project setup) ──▶ Phase 2.2 (Cat Gate) ──┐
    │                                                          │
    │    Phase 2.3 (Prompt Engine) ────────────────────────────┤
    │                                                          │
    │                                        Phase 2.4 (Agents)┤
    │                                                          │
    │                                    Phase 2.5 (Coordinator)┤
    │                                                          │
    │                                  Phase 2.6 (Orchestrator)─┤
    │                                                          │
    └──────────────────────────────────────── Phase 2.7 (UI) ──┘
                                                               │
                                              Phase 3 (Testing)┘
```

**Critical path**: 2.0 → 2.1 → 2.3 → 2.4 → 2.5 → 2.6 → 2.7  
**Parallelizable**: 2.2 (Gate) and 2.3 (Prompts) can start after 2.1  
**Testing**: Incremental — each phase includes its own unit tests

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Qwen3-VL-4B cannot reliably distinguish cat body language nuances | High — agents produce low-confidence garbage | R1 validation in Phase 0; `not_observable` fallback; confidence thresholds filter unreliable results |
| Thermal throttling during 8+ sequential inferences | Medium — analysis takes >30 min or crashes | NFR-006 thermal management; cooldown escalation; Deep mode is opt-in |
| VLMPipeline extraction breaks Hoibe | High — regression in working feature | Phase 2.0 gate: all 002 tests must pass before proceeding |
| Agent prompts produce inconsistent JSON across runs | Medium — parsing failures, flaky tests | Strict JSON schema in prompts; `temperature=0.1`; robust parsing with fallbacks |
| Archetype system feels arbitrary to users | Low — engagement impact | Based on Feline Five (peer-reviewed); explanations reference literature |
| RAM pressure from 6 sequential agents | Medium — Jetsam kills | Same model instance reused; KV cache cleared between agents; extended memory entitlement |
