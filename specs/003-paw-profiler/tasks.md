# Tasks: PawProfiler — Cat Behavior Profiling Pipeline

**Input**: Design documents from `/specs/003-paw-profiler/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — spec.md defines a 7-category test strategy with 6 test layers and 10+ fixtures.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing. US-4 (Photo input) and US-5 (Langzeit-Profil) are deferred to v2 and not included.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **VLMPipeline/**: Shared local Swift Package (extracted from ios/Hoibe/)
- **PawProfiler/PawProfiler/**: PawProfiler app source
- **PawProfilerTests/**: PawProfiler test target
- **ios/Hoibe/**: Existing Hoibe app (modified to import VLMPipeline)
> **Phase mapping**: tasks.md uses story-driven phases (1–5) while plan.md uses implementation-step numbering (2.0–2.7, 3). Phase 1 = plan 2.0+2.1, Phase 2 = plan 2.1 models+2.3, Phase 3 = plan 2.2+2.4+2.5+2.6, Phase 4 = plan 2.7, Phase 5 = plan post-implementation.
---

## Phase 1: Setup (VLMPipeline Extraction + PawProfiler Project)

**Purpose**: Extract shared pipeline infrastructure into a local Swift Package and create the PawProfiler Xcode project.

**⚠️ GATE**: Hoibe must build and all existing tests must pass after extraction (T006) before proceeding.

- [ ] T001 Create VLMPipeline/Package.swift with MLX Swift LM dependency and library target
- [ ] T002 [P] Extract protocols to VLMPipeline: FrameExtracting.swift, ModelManaging.swift, PromptBuilding.swift from ios/Hoibe/Services/Protocols.swift → VLMPipeline/Sources/VLMPipeline/Protocols/
- [ ] T003 [P] Extract models to VLMPipeline: ChatMessage.swift, FrameData.swift, ModelDownloadState.swift, PipelineConfig.swift from ios/Hoibe/Models/ → VLMPipeline/Sources/VLMPipeline/Models/
- [ ] T004 [P] Extract services to VLMPipeline: FrameExtractor.swift, ModelManager.swift from ios/Hoibe/Services/ → VLMPipeline/Sources/VLMPipeline/Services/
- [ ] T005 Update Hoibe to import VLMPipeline as local package dependency (update Hoibe.xcodeproj, replace direct source with `import VLMPipeline`)
- [ ] T006 Verify Hoibe builds and all existing tests pass after VLMPipeline extraction (xcodebuild test)
- [ ] T007 Create PawProfiler Xcode project with SwiftUI lifecycle (PawProfilerApp.swift, ContentView.swift stub) in PawProfiler/
- [ ] T008 Add VLMPipeline + MLX Swift LM as SPM dependencies and add extended memory entitlement in PawProfiler/PawProfiler.entitlements

---

## Phase 2: Foundational (Models, Config, Prompts, Test Infrastructure)

**Purpose**: Create all data models, pipeline configuration, prompt engine, agent prompts, and test infrastructure. MUST be complete before user story work begins.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Models

- [ ] T009 [P] Create CatGateResult and CatGateStatus models (Codable, Sendable) in PawProfiler/PawProfiler/Models/CatGateResult.swift
- [ ] T010 [P] Create AgentResult and AgentStatus models (Codable, Sendable) in PawProfiler/PawProfiler/Models/AgentResult.swift
- [ ] T011 [P] Create FelineFiveScores model (5 traits, 0.0–1.0 range) in PawProfiler/PawProfiler/Models/FelineFiveScores.swift
- [ ] T012 [P] Create BreedEstimate model (breed, confidence, traits) in PawProfiler/PawProfiler/Models/BreedEstimate.swift
- [ ] T013 [P] Create CompositeProfile model (all fields from data-model.md) in PawProfiler/PawProfiler/Models/CompositeProfile.swift
- [ ] T014 [P] Create AnalysisSession and ProfileMode models in PawProfiler/PawProfiler/Models/AnalysisSession.swift
- [ ] T015 [P] Create PawProfilerConfig extending PipelineConfig (gate, agent, coordinator timeouts, framesPerCall, windowsPerAgent, thermal settings) in PawProfiler/PawProfiler/Models/PawProfilerConfig.swift

### Prompt Engine & Prompts

- [ ] T016 Implement AgentPromptEngine conforming to AgentPromptBuilding protocol (buildGateMessages, buildAgentMessages, buildCoordinatorMessages) in PawProfiler/PawProfiler/Services/AgentPromptEngine.swift
- [ ] T016b [P] Write AgentPromptEngineTests: template loading per agent, message construction format, coordinator message with aggregated data in PawProfilerTests/AgentPromptEngineTests.swift
- [ ] T017 [P] Create gate system prompt (cat detection, species classification, JSON schema) in PawProfiler/PawProfiler/Resources/Prompts/gate/v1/system.txt
- [ ] T018 [P] Create 6 agent system prompts with embedded research context in PawProfiler/PawProfiler/Resources/Prompts/{personality,social,play,stress,health,breed}/v1/system.txt
- [ ] T019 [P] Create coordinator system prompt (persona prose generation, archetype table, JSON schema) in PawProfiler/PawProfiler/Resources/Prompts/coordinator/v1/system.txt

### Test Infrastructure

- [ ] T020 [P] Create MockModelManager for deterministic testing (returns pre-recorded responses per agent) in PawProfilerTests/Mocks/MockModelManager.swift
- [ ] T021 [P] Create test fixtures (10+ labeled JSON files covering all 7 categories: playful-cat, relaxed-cat, stressed-cat, no-cat, not-a-cat, dark-clip, multiple-cats; include edge cases: short-clip <5s, all-agents-fail) in PawProfilerTests/Fixtures/

**Checkpoint**: All models compile, prompts load, MockModelManager returns fixture responses. User story implementation can begin.

---

## Phase 3: US-1/US-2 — Video Profiling Pipeline + Specialized Agents (P1) 🎯 MVP

**Goal**: End-to-end cat profiling pipeline — video input → frame extraction → cat gate → 6 specialist agents → hybrid coordinator → CompositeProfile output. Each agent uses domain-specific research-embedded prompts and produces structured AgentResult JSON.

**Independent Test**: Feed a cat video clip → receive a CompositeProfile with Feline-Five scores, archetype label, mood, breed estimates, and per-agent confidence values. Verify with MockModelManager-based pipeline integration test.

### Cat Gate (FR-004, FR-005)

- [ ] T022 [US1] Implement CatGate conforming to CatGating protocol with majority-vote logic (≥2/3 = cat_detected) in PawProfiler/PawProfiler/Agents/CatGate.swift
- [ ] T023 [P] [US1] Write GateTests: cat-detected, no-cat, not-a-cat with species guess, multiple-cats, majority-vote threshold edge cases in PawProfilerTests/GateTests.swift

### Specialist Agents (FR-006, FR-007, FR-008, FR-009)

- [ ] T024 [US2] Create BaseAgent with shared logic: timeout handling, JSON response parsing, not_observable fallback, error mapping in PawProfiler/PawProfiler/Agents/BaseAgent.swift
- [ ] T025 [P] [US2] Implement PersonalityAgent (Feline Five trait scoring per Litchfield et al. 2017) in PawProfiler/PawProfiler/Agents/PersonalityAgent.swift
- [ ] T026 [P] [US2] Implement SocialBehaviorAgent (attachment style, proximity, vocalization per Vitale Shreve & Udell 2017) in PawProfiler/PawProfiler/Agents/SocialBehaviorAgent.swift
- [ ] T027 [P] [US2] Implement PlayActivityAgent (movement speed, play style, activity rhythm per Hall et al. 2002) in PawProfiler/PawProfiler/Agents/PlayActivityAgent.swift
- [ ] T028 [P] [US2] Implement StressWelfareAgent (Cat-Stress-Score indicators per Kessler & Turner 1997) in PawProfiler/PawProfiler/Agents/StressWelfareAgent.swift
- [ ] T029 [P] [US2] Implement HealthBehaviorAgent (pain indicators per Robertson 2008, "consider discussing with vet" flags) in PawProfiler/PawProfiler/Agents/HealthBehaviorAgent.swift
- [ ] T030 [P] [US2] Implement BreedArchetypeAgent (breed features per Salonen et al. 2019, visual trait matching) in PawProfiler/PawProfiler/Agents/BreedArchetypeAgent.swift
- [ ] T031 [P] [US2] Write AgentResultParsingTests: schema validation per agent type, not_observable status, timed_out status, confidence ranges in PawProfilerTests/AgentResultParsingTests.swift

### Hybrid Coordinator (FR-010, FR-011)

- [ ] T032 [US1] Implement ArchetypeResolver with deterministic lookup table (8 archetypes + Everyday Cat fallback, most-specific-match-wins precedence) in PawProfiler/PawProfiler/Services/ArchetypeResolver.swift
- [ ] T033 [P] [US1] Write ArchetypeResolverTests: all 8 archetypes, Everyday Cat fallback, Chaotic Acrobat vs Midnight Gremlin precedence, mid-range scores in PawProfilerTests/ArchetypeResolverTests.swift
- [ ] T034 [US1] Implement ProfileCoordinator conforming to ProfileCoordinating — confidence-weighted score aggregation + VLM persona prose call in PawProfiler/PawProfiler/Services/ProfileCoordinator.swift
- [ ] T035 [US1] Implement partial-result handling in ProfileCoordinator: skip not_observable/timed_out agents in aggregation, inform VLM of missing agents in PawProfiler/PawProfiler/Services/ProfileCoordinator.swift
- [ ] T036 [P] [US1] Write CoordinatorTests: score aggregation accuracy, partial results with 2 missing agents, VLM persona generation with MockModelManager in PawProfilerTests/CoordinatorTests.swift

### Pipeline Orchestrator (FR-020, FR-021, FR-023, NFR-006)

- [ ] T037 [US1] Create CatAnalysisState as @Observable enum for SwiftUI state binding (idle → extracting → gate → agents → coordinator → complete/error) in PawProfiler/PawProfiler/Models/CatAnalysisState.swift
- [ ] T037b [US1] Create protocol definition source files from contracts/ (CatGating, BehaviorAnalyzing, ProfileCoordinating, CatProfiling, AgentPromptBuilding) in PawProfiler/PawProfiler/Protocols/
- [ ] T038 [US1] Implement CatProfiler conforming to CatProfiling — full pipeline: extract frames → gate → 6 agents sequential → coordinator → profile in PawProfiler/PawProfiler/Services/CatProfiler.swift
- [ ] T039 [US1] Implement Quick/Deep mode switching in CatProfiler (windowsPerAgent: 1 vs 3, sliding window frame distribution) in PawProfiler/PawProfiler/Services/CatProfiler.swift
- [ ] T040 [US1] Implement thermal management in CatProfiler: cooldown escalation at .serious (5s), pause at .critical with state update in PawProfiler/PawProfiler/Services/CatProfiler.swift
- [ ] T041 [US1] Implement cancellation support in CatProfiler (Task cancellation, discard partial results, return to idle) in PawProfiler/PawProfiler/Services/CatProfiler.swift
- [ ] T042 [US1] Write PipelineIntegrationTests: full pipeline with MockModelManager (gate → 6 agents → coordinator), cancellation, gate rejection path, all-agents-fail path (≥ 3 threshold), minimum-agent-count insufficient path in PawProfilerTests/PipelineIntegrationTests.swift

**Checkpoint**: Full pipeline works end-to-end with MockModelManager. CompositeProfile produced with correct scores, archetype, and observations. US-1 and US-2 independently testable.

---

## Phase 4: US-3 — Cat Persona Card UI (P1)

**Goal**: Visual presentation of profiling results — Persona Card with Feline-Five radar chart, archetype label, behavioral observations, breed affinity, and stress hints. Plus video selection UI, analysis progress, and gate rejection view.

**Independent Test**: Complete analysis → verify Persona Card displays radar chart with 5 axes, archetype label, ≥3 observations, breed affinity. Verify progress UI shows "Agent N/6: {name}..." during analysis.

### Views

- [ ] T043 [US3] Implement ContentView: PhotosPicker video selection with duration validation (15–90s, MP4/MOV), Quick/Deep mode toggle, analyze button, model download UI in PawProfiler/PawProfiler/App/ContentView.swift
- [ ] T044 [P] [US3] Implement AgentProgressView ("Agent 3/6: Stress & Welfare…" with progress indicator) in PawProfiler/PawProfiler/Views/AgentProgressView.swift
- [ ] T045 [P] [US3] Implement RadarChartView (Feline-Five radar chart with 5 axes using SwiftUI Charts) in PawProfiler/PawProfiler/Views/RadarChartView.swift
- [ ] T046 [US3] Implement PersonaCardView: archetype label, persona description, top-3 observations, breed affinity, inline stress/health hints in PawProfiler/PawProfiler/Views/PersonaCardView.swift
- [ ] T047 [P] [US3] Implement GateRejectedView (no-cat/not-a-cat result with species guess and guidance for retrying) in PawProfiler/PawProfiler/Views/GateRejectedView.swift

### Integration

- [ ] T048 [US3] Implement AgentDetailView: per-agent reasoning drill-down with research references, accessible from PersonaCardView (US-2 AC-3) in PawProfiler/PawProfiler/Views/AgentDetailView.swift
- [ ] T049 [US3] Wire CatAnalysisState to views for state-driven UI transitions (idle → progress → persona card / gate rejected / error) in PawProfiler/PawProfiler/App/ContentView.swift

**Checkpoint**: US-3 fully functional — video selection → analysis with progress → Persona Card or gate rejection. All P1 user stories complete.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Build verification, validation, and cleanup across all user stories.

- [ ] T050 [P] Verify PawProfiler builds clean (xcodebuild build -project PawProfiler/PawProfiler.xcodeproj)
- [ ] T051 [P] Verify Hoibe still builds and tests pass after VLMPipeline extraction (xcodebuild test -project Hoibe.xcodeproj)
- [ ] T052 Run full PawProfiler test suite and verify all tests pass (xcodebuild test)
- [ ] T053 Run quickstart.md validation: build, test, basic flow on device

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001–T008) — BLOCKS all user stories
- **US-1/US-2 (Phase 3)**: Depends on Foundational completion (T009–T021)
- **US-3 (Phase 4)**: Depends on Phase 3 (needs CatAnalysisState and CatProfiler)
- **Polish (Phase 5)**: Depends on all phases complete

### User Story Dependencies

- **US-1/US-2 (P1)**: Can start after Phase 2 — No dependencies on US-3
- **US-3 (P1)**: Depends on US-1/US-2 for CatAnalysisState, CatProfiler, and CompositeProfile
- **US-6 (Stress)**: Covered by StressWelfareAgent (T028) + stress hints in PersonaCardView (T046) — no separate phase
- **US-7 (Breed/Archetype)**: Covered by BreedArchetypeAgent (T030) + ArchetypeResolver (T032) + archetype label in PersonaCardView (T046) — no separate phase

### Within Each Phase

- Models (T009–T015) before services (T016)
- Prompts (T017–T019) before agents (T024–T030)
- BaseAgent (T024) before specialist agents (T025–T030)
- ArchetypeResolver (T032) before ProfileCoordinator (T034)
- ProfileCoordinator (T034) before CatProfiler (T038)
- CatProfiler (T038) before UI integration (T043–T049)

### Parallel Opportunities

**Phase 1**:
- T002, T003, T004 can run in parallel (different VLMPipeline subdirectories)

**Phase 2**:
- T009–T015 can all run in parallel (independent model files)
- T017, T018, T019 can run in parallel (independent prompt files)
- T020, T021 can run in parallel with prompts

**Phase 3**:
- T025–T030 can all run in parallel (each agent is an independent file, all depend on T024)
- T023, T031, T033, T036 test tasks can run in parallel with their implementations

**Phase 4**:
- T044, T045, T047 can run in parallel (independent view files)

---

## Parallel Example: Phase 3 Agents

```bash
# After T024 (BaseAgent) is complete, launch all 6 agents in parallel:
Task T025: "PersonalityAgent in Agents/PersonalityAgent.swift"
Task T026: "SocialBehaviorAgent in Agents/SocialBehaviorAgent.swift"
Task T027: "PlayActivityAgent in Agents/PlayActivityAgent.swift"
Task T028: "StressWelfareAgent in Agents/StressWelfareAgent.swift"
Task T029: "HealthBehaviorAgent in Agents/HealthBehaviorAgent.swift"
Task T030: "BreedArchetypeAgent in Agents/BreedArchetypeAgent.swift"

# Then launch agent tests:
Task T031: "AgentResultParsingTests in PawProfilerTests/"
```

---

## Implementation Strategy

### MVP First (US-1/US-2 + US-3)

1. Complete Phase 1: Setup (VLMPipeline extraction + project creation)
2. Complete Phase 2: Foundational (models, prompts, test infra)
3. Complete Phase 3: US-1/US-2 (pipeline + agents) — **backend MVP**
4. **VALIDATE**: Run PipelineIntegrationTests with MockModelManager
5. Complete Phase 4: US-3 (Persona Card UI) — **full MVP**
6. **VALIDATE**: End-to-end on device with real VLM inference

### Incremental Delivery

1. Setup + Foundational → Project builds, prompts load, mocks work
2. Add US-1/US-2 → Pipeline produces CompositeProfile (mock or real) → **Testable backend**
3. Add US-3 → Persona Card renders results → **Shippable MVP**
4. Each story adds value without breaking previous stories

### v2 Scope (Not in this task list)

- US-4: Photo-based analysis (FR-017b)
- US-5: Langzeit-Profil / CatProfile aggregation (FR-015, FR-016)
- SC-008: Share-as-image (FR-014)

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- US-6 (Stress) and US-7 (Breed/Archetype) are integrated into US-1/US-2 agents and US-3 UI — no separate phases
- All agents conform to BehaviorAnalyzing protocol and extend BaseAgent
- All models conform to Codable + Sendable (per contract definitions)
- Commit after each task or logical group
- Stop at Phase 3 checkpoint to validate pipeline independently
