# Data Model: PawProfiler — Cat Behavior Profiling Pipeline

**Feature**: 003-paw-profiler  
**Date**: 2026-05-25

## Entities

### Shared (from VLMPipeline package — reused from 002)

These entities are extracted from Hoibe into the shared `VLMPipeline` Swift Package:

- **FrameData** — Extracted frames with timestamps and sharpness scores
- **ChatMessage** — VLM chat message (role, text, images)
- **ModelDownloadState** — Model download lifecycle state machine
- **PipelineConfig** — Base pipeline configuration (extended by PawProfiler)

### CatGateResult

Result of the pre-analysis cat detection gate.

| Field | Type | Validation | Description |
|-------|------|-----------|-------------|
| `catDetected` | Bool | required | Whether a cat was detected |
| `status` | CatGateStatus | enum | `cat_detected`, `no_cat_detected`, `not_a_cat` |
| `speciesGuess` | String? | — | If `not_a_cat`, what animal was detected |
| `confidence` | Double | 0.0–1.0 | Gate confidence |
| `multipleCats` | Bool | required | Whether more than one cat was detected |
| `modelName` | String | required | Model used for gate |

### CatGateStatus (enum)

| Value | Semantics |
|-------|-----------|
| `catDetected` | Cat visible, proceed with agents |
| `noCatDetected` | No animal detected in frame |
| `notACat` | Animal detected but not a cat |

### AgentResult

Structured output from a single specialist agent.

| Field | Type | Validation | Description |
|-------|------|-----------|-------------|
| `agentId` | String | required | Agent identifier (e.g., `personality`, `stress`) |
| `domain` | String | required | Human-readable domain name |
| `status` | AgentStatus | enum | Completion status |
| `traitScores` | [String: Double]? | 0.0–1.0 per trait | Feline-Five or domain-specific scores |
| `observations` | [String] | required (may be empty) | Behavioral observations with evidence |
| `flags` | [String] | required (may be empty) | Special flags (e.g., `stress_detected`, `pain_indicator`) |
| `confidence` | Double | 0.0–1.0 | Agent confidence in its assessment |
| `reasoning` | String? | — | Brief reasoning for the assessment |
| `promptVersion` | String | required | Version of the agent prompt used |

### AgentStatus (enum)

| Value | Semantics |
|-------|-----------|
| `completed` | Agent produced valid results |
| `notObservable` | Relevant body parts/behaviors not visible |
| `timedOut` | Agent exceeded timeout limit |
| `failed` | Agent encountered an error |

### FelilneFiveScores

Aggregated Feline Five personality scores.

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `neuroticism` | Double | 0.0–1.0 | Fearfulness, anxiety, sensitivity |
| `extraversion` | Double | 0.0–1.0 | Activity, curiosity, sociability |
| `dominance` | Double | 0.0–1.0 | Assertiveness, territorial behavior |
| `impulsiveness` | Double | 0.0–1.0 | Erratic behavior, rapid switches |
| `agreeableness` | Double | 0.0–1.0 | Friendliness, tolerance, bonding |

**Scoring scale**: 0.0 = trait not observed/minimal, 0.5 = average, 1.0 = strongly expressed.

### CompositeProfile

Coordinator output: synthesized profile from all agent results.

| Field | Type | Validation | Description |
|-------|------|-----------|-------------|
| `felineFiveScores` | FelineFiveScores | required | Aggregated trait scores |
| `archetypeLabel` | String | required | Matched archetype (e.g., "The Midnight Gremlin") |
| `archetypeDescription` | String | required | VLM-generated persona description |
| `overallMood` | String | required | Current mood assessment |
| `breedEstimate` | [BreedEstimate] | required (may be empty) | Top-3 breed guesses |
| `stressIndicators` | [String] | required (may be empty) | Detected stress signals |
| `healthFlags` | [String] | required (may be empty) | "Consider discussing with vet" flags |
| `topObservations` | [String] | required, min 3 | Most notable behavioral observations |
| `contextualNotes` | [String] | — | Additional context from VLM |
| `confidencePerAgent` | [String: Double] | required | Confidence score per agent |
| `agentResults` | [AgentResult] | required | Raw agent results for drill-down |
| `modelName` | String | required | Model identifier |
| `analysisVersion` | String | required | Pipeline/prompt version |
| `analyzedAt` | String | ISO 8601 | UTC timestamp |
| `inputType` | String | required | `video` (v1 only) |
| `profileMode` | String | required | `quick` or `deep` |

### BreedEstimate

| Field | Type | Validation | Description |
|-------|------|-----------|-------------|
| `breed` | String | required | Breed name |
| `confidence` | Double | 0.0–1.0 | Estimate confidence |
| `traits` | [String] | — | Visual traits that matched |

### AnalysisSession

Single analysis run metadata (v1: in-memory only).

| Field | Type | Validation | Description |
|-------|------|-----------|-------------|
| `id` | UUID | required | Session identifier |
| `startedAt` | Date | required | Analysis start time |
| `completedAt` | Date? | — | Analysis completion time |
| `videoURL` | URL | local file | Source video |
| `videoDuration` | TimeInterval | 15.0–90.0 | Clip duration |
| `profileMode` | ProfileMode | enum | `quick` or `deep` |
| `gateResult` | CatGateResult | required | Gate outcome |
| `compositeProfile` | CompositeProfile? | — | Final profile (nil if gate rejected) |

### ProfileMode (enum)

| Value | windowsPerAgent | Frames per call | Estimated time |
|-------|----------------|-----------------|----------------|
| `quick` | 1 | 2–3 | ~8–12 min |
| `deep` | 3 | 2–3 per window | ~20–30 min |

### PawProfilerConfig (extends PipelineConfig)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `gateVotes` | Int | 3 | Number of cat-gate votes |
| `gateTimeout` | TimeInterval | 45.0 | Per-vote timeout |
| `agentTimeout` | TimeInterval | 90.0 | Per-agent-call timeout |
| `coordinatorTimeout` | TimeInterval | 90.0 | Coordinator VLM call timeout |
| `framesPerCall` | Int | 3 | Frames per agent inference call |
| `windowsPerAgent` | Int | 1 | 1 = Quick, 3 = Deep |
| `windowMinSpan` | Double | 0.6 | Minimum window span (0–1) |
| `candidateFrameCount` | Int | 8 | Frames to extract before ranking |
| `numCtx` | Int | 4096 | Context window size |
| `temperature` | Double | 0.1 | Sampling temperature |
| `cooldown` | TimeInterval | 2.0 | Pause between inference calls |
| `thermalCooldown` | TimeInterval | 5.0 | Cooldown at thermal `.serious` |

### Archetype (lookup table)

| Archetype Label | Trait Pattern | Specificity |
|----------------|---------------|-------------|
| The Chaotic Acrobat | E>0.7 + I>0.7 + N<0.3 | 3 traits |
| The Midnight Gremlin | I>0.7 + E>0.7 | 2 traits |
| The Royal Aristocat | D>0.7 + I<0.3 | 2 traits |
| The Lone Strategist | D>0.7 + A<0.3 | 2 traits |
| The Anxious Explorer | N>0.7 + E>0.7 | 2 traits |
| The Gentle Soul | A>0.7 + D<0.3 | 2 traits |
| The Couch Philosopher | E<0.3 + I<0.3 | 2 traits |
| The Social Butterfly | A>0.7 + E>0.7 | 2 traits |
| The Everyday Cat | (fallback) | 0 traits |

**Evaluation rule**: Most-specific match wins (highest trait-condition count). Ties broken by table order.

## Relationships

```
VideoClip ──extracts──▶ FrameData
FrameData ──gate check──▶ CatGateResult
CatGateResult ──if cat_detected──▶ AgentResult[] (6 agents, sequential)
AgentResult[] ──aggregated by──▶ CompositeProfile (Hybrid Coordinator)
CompositeProfile ──rendered as──▶ CatPersonaCard (UI)
AnalysisSession ──wraps──▶ CatGateResult + CompositeProfile
ModelManager ──manages──▶ ModelDownloadState
PawProfilerConfig ──configures──▶ Pipeline timeouts, frame counts, modes
```

## State Transitions

### AnalysisState (UI-observable)

```
idle
  ──startAnalysis──▶ extractingFrames
extractingFrames
  ──framesReady──▶ runningGate(vote: 1, of: 3)
runningGate(vote: N, of: 3)
  ──voteComplete──▶ runningGate(vote: N+1, of: 3)  [if N < 3]
  ──gateComplete(cat_detected)──▶ runningAgent(agent: 1, of: 6, name: "Personality")
  ──gateComplete(no_cat/not_a_cat)──▶ gateRejected(CatGateResult)
runningAgent(agent: N, of: 6, name: String)
  ──agentComplete──▶ runningAgent(agent: N+1, of: 6, name: String)  [if N < 6]
  ──allAgentsComplete──▶ runningCoordinator
runningCoordinator
  ──coordinatorComplete──▶ complete(CompositeProfile)
  ──coordinatorFailed──▶ error(String)
*any state*
  ──cancel──▶ idle
  ──error──▶ error(String)
```

### ModelDownloadState

Same as 002 — reused from VLMPipeline package.
