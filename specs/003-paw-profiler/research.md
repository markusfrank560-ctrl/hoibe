# Research: PawProfiler — Cat Behavior Profiling Pipeline

**Feature**: 003-paw-profiler  
**Date**: 2026-05-25

## Research Tasks

### R1: Can Qwen3-VL-4B Analyze Cat Behavior from Video Frames?

**Decision**: Yes, with structured prompts and domain-embedded context. Qwen3-VL-4B can identify cat body postures, ear positions, tail states, and activity levels from still frames. It cannot reliably detect subtle microexpressions or rapid motion blur.

**Rationale**:
- Qwen3-VL-4B demonstrated competent object recognition and scene understanding in 002 (beverage fill levels, lip-to-rim contact)
- Cat body language signals (ear position, tail carriage, body posture, eye shape) are visually prominent and well-documented in feline behavior literature
- Structured prompts with embedded research context (e.g., "ears flattened sideways = anxiety per Kessler & Turner") guide the model toward validated behavioral indicators
- 4-bit quantization does not meaningfully degrade spatial feature recognition for large body parts (ears, tail, posture)
- Limitation: fine-grained breed identification may be less accurate than posture analysis — acceptable with confidence scores

**Alternatives considered**:
- Larger model (7B+): Would exceed 8 GB RAM budget on iPhone 15 Pro
- Custom fine-tuned model: No labeled feline behavior dataset available; fine-tuning infrastructure out of scope
- Dedicated cat detection model (YOLO): Could complement VLM but adds dependency; VLM gate sufficient for v1

### R2: Multi-Agent vs. Single-Prompt Architecture

**Decision**: Multi-agent with sequential execution. Each agent gets a domain-specific system prompt with embedded research citations. All agents share the same extracted frame set.

**Rationale**:
- Single mega-prompt (all 6 domains in one call) exceeded context window budget and produced inconsistent results in preliminary testing with 002's pipeline
- Sequential execution (one MLX inference at a time) is mandated by iPhone memory constraints — no parallel inference possible
- Domain-specific prompts allow precise research embedding: each agent references only its relevant literature (e.g., Stress agent cites Kessler & Turner, not Litchfield)
- Agent isolation improves testability: each agent can be unit-tested with mock responses independently
- Shared frames reduce extraction overhead: extract once, distribute to all agents

**Alternatives considered**:
- Parallel agents: Impossible on single-GPU iPhone; would require model duplication
- Two-pass architecture (coarse → fine): Adds latency without proportional accuracy gain
- Tool-calling agent: Qwen3-VL-4B lacks reliable tool-calling capability at 4-bit quantization

### R3: Hybrid Coordinator Design

**Decision**: Code-based score aggregation + archetype lookup + single VLM call for persona prose.

**Rationale**:
- Score aggregation (confidence-weighted averages) is deterministic and should not depend on VLM output variability
- Archetype lookup is a table operation: compare Feline-Five scores against threshold patterns, select most-specific match
- Persona description benefits from natural language generation: "Your cat exhibits the bold curiosity of a Midnight Gremlin..." is better generated than templated
- Single VLM call for prose keeps total inference calls to 8 (1 gate + 6 agents + 1 coordinator) for Quick Profile
- Coordinator VLM receives pre-aggregated scores and observations as structured input, not raw frames — faster inference, smaller context

**Alternatives considered**:
- Fully code-based coordinator: Persona descriptions would be template-based and feel robotic
- Fully VLM-based coordinator: Score aggregation would be non-deterministic; archetype assignment could vary between runs
- LLM-as-judge pattern: Overkill for aggregation; adds latency

### R4: Feline Five Framework Suitability

**Decision**: Adopt Litchfield et al. (2017) Feline Five as primary trait framework. Map video-observable behaviors to trait dimensions using published behavioral indicators.

**Rationale**:
- Feline Five is the most widely cited and validated cat personality framework (N=2,802 cats, factor analysis)
- Five dimensions (Neuroticism, Extraversion, Dominance, Impulsiveness, Agreeableness) map well to visually observable behaviors
- Observable indicators per dimension:
  - **Neuroticism**: Freeze response, hiding, startle reflex, wide eyes, flattened ears
  - **Extraversion**: Approach behavior, exploration, play initiation, vocal frequency
  - **Dominance**: Direct stare, elevated posture, resource guarding, slow blink absence
  - **Impulsiveness**: Rapid behavioral switches, pouncing, erratic movement, interrupted grooming
  - **Agreeableness**: Slow blink, head bunting, allogrooming, relaxed near humans/other cats
- Helsinki Breed Study (Salonen et al. 2019) provides breed-level behavioral baselines for validation

**Alternatives considered**:
- Big Five (human personality model): Not validated for cats, forced anthropomorphism
- Custom trait axes: Would lack scientific credibility; Feline Five already covers key dimensions
- MBTI-style typing: Fun but not scientifically grounded for animals

### R5: VLMPipeline Swift Package Extraction Strategy

**Decision**: Extract shared infrastructure into a local Swift Package named `VLMPipeline` within the monorepo. Both Hoibe (002) and PawProfiler (003) import it as a local package dependency.

**Rationale**:
- Protocols (`FrameExtracting`, `ModelManaging`) and shared models (`ChatMessage`, `FrameData`, `ModelDownloadState`, `PipelineConfig`) are identical between 002 and 003
- Local Swift Package avoids remote dependency management; changes to shared code are immediately available
- Xcode supports local package references via relative path — no registry or versioning overhead for v1
- Clean separation: `VLMPipeline/` contains protocol definitions, shared models, and base implementations; app-specific logic (agents, coordinator, UI) stays in each app's project

**Alternatives considered**:
- Copy-paste shared code: Maintenance nightmare, divergence risk
- Git submodule: Overkill for single-repo development
- Remote Swift Package (GitHub): Unnecessary for local development; adds CI complexity

### R6: Thermal Management for 8-Agent Pipeline

**Decision**: Reuse 002's thermal management pattern with extended cooldown intervals. Monitor `ProcessInfo.thermalState`; increase cooldown at `.serious`, pause at `.critical`.

**Rationale**:
- PawProfiler runs 8 sequential inferences (1 gate + 6 agents + 1 coordinator) vs. 002's 6 (3 gate + 3 windows)
- Quick Profile total inference time: ~8–12 minutes (each call ~60–90s)
- Default cooldown: 2s between calls (same as 002)
- At `.serious`: increase cooldown to 5s (per NFR-006)
- At `.critical`: pause analysis, show user notification, resume when thermal state drops
- iPhone 15 Pro sustained inference benchmarks show thermal throttling starts around 8–10 minutes of continuous inference — Quick Profile is at the boundary

**Alternatives considered**:
- Batch frames to reduce call count: Would require redesigning prompt structure; agents need to receive frames individually for domain-specific analysis
- Night-mode scheduling: Against user expectation of interactive analysis
- Fan detection (external accessory): Out of scope

### R7: Frame Count and Selection Strategy

**Decision**: Extract 8 candidate frames from the full video, rank by sharpness, distribute top frames to all agents. Quick Profile: 2–3 frames per agent call. Deep Profile: 3 windows × 2–3 frames per window per agent.

**Rationale**:
- Cat behavior is best assessed from diverse temporal samples (different moments in the clip)
- 8 candidates from a 30–60s clip provide sufficient temporal diversity (~1 frame per 4–8s)
- Sharpness ranking ensures frames with motion blur are deprioritized
- All agents share the same frame set for consistency (same visual evidence, different analytical lenses)
- Quick Profile: single call with 2–3 best frames — sufficient for posture and position analysis
- Deep Profile: 3 temporal windows (like 002's sliding windows) give temporal behavior change detection

**Alternatives considered**:
- Per-agent frame selection: Would require agent-specific extraction logic; complexity not justified for v1
- More frames per call (4–5): Increases context window usage and inference time without proportional accuracy gain
- Single frame per agent: Insufficient for behavioral assessment; single posture snapshot is too ambiguous
