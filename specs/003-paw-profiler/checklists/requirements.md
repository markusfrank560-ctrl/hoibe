# Requirements Quality Checklist: PawProfiler

**Purpose**: Validate completeness, clarity, testability, consistency, and constitution alignment of the PawProfiler spec — "unit tests for the requirements, not the implementation."
**Created**: 2026-05-25
**Feature**: [spec.md](../spec.md)
**Constitution**: [constitution.md](../../../.specify/memory/constitution.md)
**Scope**: v1 core + v2 deferral boundary validation
**Depth**: Standard
**Audience**: Reviewer (PR)

## Requirement Completeness

- [ ] CHK001 — Are the specific protocol interfaces (`FrameExtracting`, `ModelManaging`, `PromptBuilding`) and their required versions/signatures specified for reuse? [Completeness, Spec §FR-001]
- [ ] CHK002 — Are the Swift Package (`VLMPipeline`) boundaries defined — which types/protocols go into the package vs. remain app-specific? [Completeness, Spec §FR-002]
- [ ] CHK003 — Are the observable video behaviors (input signals) each agent should detect explicitly listed per agent domain? [Completeness, Spec §FR-006]
- [ ] CHK004 — Is the agent result JSON schema defined with all required fields, data types, and value ranges — not just field names? [Completeness, Spec §FR-007]
- [ ] CHK005 — Is the versioning scheme for agent schemata specified (format, bump rules, migration path)? [Completeness, Spec §FR-007]
- [ ] CHK006 — Are the weights for the Coordinator's Feline-Five score aggregation defined or is the weighting algorithm documented? [Completeness, Spec §FR-010]
- [ ] CHK007 — Is the Archetype lookup table format, versioning, and extensibility mechanism specified? [Completeness, Spec §FR-010, Archetype System]
- [ ] CHK008 — Are all mandatory fields of `CompositeProfile` exhaustively listed in the requirements (not only in acceptance scenarios)? [Completeness, Spec §FR-012]
- [ ] CHK009 — Is the Feline-Five scoring scale defined (0–1? 1–5? 0–100?) with anchor descriptions for each level? [Completeness, Scientific Framework]
- [ ] CHK010 — Are requirements defined for the onboarding flow referenced in SC-001 ("2 Minuten nach App-Start")? [Gap]
- [ ] CHK011 — Are requirements defined for model selection, model version pinning, and model update lifecycle? [Gap]
- [ ] CHK012 — Are requirements for pipeline-level error recovery defined (full pipeline failure, app crash mid-analysis, device storage exhaustion)? [Gap]
- [ ] CHK013 — Are requirements for the progress UI defined beyond "Agent 3/6: Stress…" (e.g., estimated time, cancel button, background behavior)? [Gap, Spec §FR-022]
- [ ] CHK014 — Is the breed library scope defined — how many breeds, which breeds, and how the list is maintained? [Gap, Spec §FR-006 Agent 6]
- [ ] CHK015 — Are data retention and deletion requirements specified for locally stored profiles and analysis results? [Gap, Spec §FR-016]
- [ ] CHK016 — Are requirements for the `CatGateResult` response time defined separately from full pipeline timing? [Gap, Spec §FR-004]

## Requirement Clarity

- [ ] CHK017 — Is the Cat Gate "Majority-Vote über N Frames" quantified — what is N, and what constitutes majority? [Clarity, Spec §FR-004]
- [ ] CHK018 — Is "2–3 Frames" per window in Quick/Deep Profile disambiguated to a deterministic value or selection rule? [Clarity, Spec §FR-021]
- [ ] CHK019 — Is "gewichteter Durchschnitt" in the Coordinator score aggregation quantified with specific weights or a weighting formula? [Clarity, Spec §FR-010]
- [ ] CHK020 — Is "Standard-Katzenclip" in SC-003 defined with measurable characteristics (lighting, angle, resolution, behavior visibility)? [Clarity, Spec §SC-003]
- [ ] CHK021 — Is "verwertbare Ergebnisse" in SC-003 defined beyond Confidence ≥ 0.5 (e.g., minimum number of observations, minimum trait scores)? [Clarity, Spec §SC-003]
- [ ] CHK022 — Is the NFR-001 timing target specified as wall-clock time, and are conditions defined (cold start vs. warm, model already loaded vs. first load)? [Clarity, Spec §NFR-001]
- [ ] CHK023 — Is "dezenter Hinweis 'Worth monitoring'" in US-3 AS-3 specified with placement, visual treatment, and trigger threshold? [Clarity, Spec §US-3]
- [ ] CHK024 — Is the `not_observable` agent status defined with required fields (reason, affected traits, confidence impact)? [Clarity, Spec §FR-009]
- [ ] CHK025 — Are the Cat-Stress-Score levels (Kessler & Turner's 7-point scale) mapped to the agent's output format? [Clarity, Scientific Framework]

## Requirement Consistency

- [ ] CHK026 — FR-014 requires 9:16 image export via Sharesheet, but v1 scope explicitly defers "Share-as-image (9:16 export, iOS Sharesheet)". Which takes precedence? [Conflict, Spec §FR-014 vs. v1 Scope]
- [ ] CHK027 — FR-015 requires Langzeit-CatProfile aggregation, but v1 scope explicitly defers "Langzeit-Profil / CatProfile aggregation". Which takes precedence? [Conflict, Spec §FR-015 vs. v1 Scope]
- [ ] CHK028 — FR-017 requires Einzelfotos (JPEG/HEIC/PNG) as input, but v1 scope states "Video input only (15–90s clips)". Which takes precedence? [Conflict, Spec §FR-017 vs. v1 Scope]
- [ ] CHK029 — SC-008 measures share rate (≥ 50%), but sharing is deferred to v2. Is this success criterion applicable to v1? [Conflict, Spec §SC-008 vs. v1 Scope]
- [ ] CHK030 — US-3 AS-2 specifies share-as-9:16-Grafik, but v1 scope defers this. Is US-3 AS-2 a v1 acceptance scenario? [Conflict, Spec §US-3 vs. v1 Scope]
- [ ] CHK031 — Constitution Technical Constraints specify "5–15 Sekunden Clips", but spec §FR-017 specifies "15–90s". Is the constitution outdated, or is this a deliberate deviation? [Conflict, Constitution §Technical Constraints vs. Spec §FR-017]
- [ ] CHK032 — FR-013 includes "optionale Stress-/Gesundheitshinweise" on the Persona Card, but v1 defers "Stress-specific UI section". Is the Persona Card mention in-scope or deferred? [Ambiguity, Spec §FR-013 vs. v1 Scope]
- [ ] CHK033 — v1 scope says "Single-session results (no persistence across sessions)" but FR-016 requires local storage. Are results stored within a session only or persisted between app launches? [Conflict, Spec §FR-016 vs. v1 Scope]

## Constitution Alignment

- [ ] CHK034 — Constitution Principle III mandates "Structured Output Only — keine offenen narrativen Antworten." Does the VLM-generated persona description (FR-010) violate this principle, and if so, is the deviation documented and justified? [Constitution §III vs. Spec §FR-010]
- [ ] CHK035 — Constitution Principle IV mandates separation of "semantische Bewertung (VLM)" and "harte Regelprüfung." Is the boundary between VLM inference and code-based logic in the Hybrid Coordinator sufficiently specified to satisfy this principle? [Constitution §IV, Spec §FR-010]
- [ ] CHK036 — Constitution Principle VI requires "Hohe Precision ist wichtiger als maximaler Recall." Is SC-005's 80% consistency threshold justified against this principle? [Constitution §VI, Spec §SC-005]
- [ ] CHK037 — Constitution Principle VII requires explicit versioning of "Prompt-Versionen, Modellauswahl, Ausgabe-Schema und Frame-Selektionslogik." Are prompt versioning requirements defined for the 6 agent prompts and the Coordinator prompt? [Constitution §VII, Gap]
- [ ] CHK038 — Constitution Principle I (Privacy-First) is addressed by FR-003 and NFR-003. Are privacy requirements also specified for stored CatProfiles and CompositeProfiles (encryption at rest, no metadata leakage)? [Constitution §I, Gap]
- [ ] CHK039 — Constitution Principle V (Async & Resource-Aware) requires "Thermal Throttling vermeiden durch asynchrone Batch-Verarbeitung." Are thermal management requirements specified for the 6-agent sequential pipeline? [Constitution §V, Gap]
- [ ] CHK040 — Constitution Principle II (Local Inference) specifies "GGUF-/MLX-kompatibles multimodales Modell." Is the model compatibility requirement explicit in the PawProfiler spec (not only inherited by assumption)? [Constitution §II, Spec §Assumptions]

## Acceptance Criteria Quality

- [ ] CHK041 — SC-001 ("2 Minuten nach App-Start") — does this include first-launch model download, or only subsequent launches with model cached? [Measurability, Spec §SC-001]
- [ ] CHK042 — SC-005 ("≥ 80% der Agenten konsistente Bewertungen bei 5 Wiederholungen") — is "konsistent" defined with a quantitative tolerance band (e.g., ±0.1 on trait scores)? [Measurability, Spec §SC-005]
- [ ] CHK043 — SC-006 ("≤ 5% False-Positive für Katze erkannt") — is the test set composition and size specified (how many non-cat inputs, what types)? [Measurability, Spec §SC-006]
- [ ] CHK044 — SC-007 ("80% der Nutzer finden Profilbeschreibungen zutreffend") — are the measurement method, sample size, and evaluation protocol defined? [Measurability, Spec §SC-007]
- [ ] CHK045 — SC-003 ("mindestens 4 von 6 Agenten") — are the conditions under which fewer than 4 agents are acceptable documented as degraded-mode requirements? [Measurability, Spec §SC-003]
- [ ] CHK046 — US-1 AS-3 states the profile should "spiegelt die entspannte Stimmung korrekt wider." Is "korrekt" defined with measurable criteria for mood mapping? [Measurability, Spec §US-1]

## Scenario Coverage

- [ ] CHK047 — Are requirements defined for user-initiated cancellation of a running analysis (mid-pipeline abort, partial results handling)? [Coverage, Gap]
- [ ] CHK048 — Are requirements defined for app backgrounding during analysis (should analysis continue, pause, or abort)? [Coverage, Gap]
- [ ] CHK049 — Are requirements defined for insufficient device storage during analysis or profile storage? [Coverage, Gap]
- [ ] CHK050 — Are requirements defined for model download failure or corruption (retry, fallback, user guidance)? [Coverage, Gap]
- [ ] CHK051 — Are requirements defined for the case where all 6 agents return `not_observable` (complete analysis failure)? [Coverage, Gap]
- [ ] CHK052 — Are requirements defined for the analysis of kittens vs. adult cats (age-dependent behavior baselines)? [Coverage, Gap]
- [ ] CHK053 — Are requirements defined for simultaneous analysis requests (user starts new analysis while one is running)? [Coverage, Gap]
- [ ] CHK054 — Are requirements defined for video codec/format validation and rejection of unsupported formats? [Coverage, Spec §FR-017]

## Edge Case Coverage

- [ ] CHK055 — The spec defines "mehrere Katzen im Bild → Analyse der dominanten/größten Katze." Is "dominante/größte" defined with a measurable selection criterion? [Clarity, Edge Cases]
- [ ] CHK056 — Is the minimum video quality threshold defined below which analysis should be refused rather than attempted with low confidence? [Gap, Edge Cases]
- [ ] CHK057 — Are requirements defined for the edge case of a cat that is only partially visible throughout the entire clip (never fully in frame)? [Coverage, Edge Cases]
- [ ] CHK058 — Is the behavior defined when the Cat Gate result is ambiguous (e.g., 50/50 vote split on cat presence)? [Clarity, Spec §FR-004]
- [ ] CHK059 — Are requirements specified for clips at the boundary of the 15–90s range (exactly 15s, exactly 90s, slightly outside)? [Coverage, Spec §FR-017]

## Scientific Framework Specification

- [ ] CHK060 — Is the mapping from specific observable video behaviors (ear position, tail posture, gait speed, etc.) to Feline Five dimensions explicitly documented? [Completeness, Scientific Framework]
- [ ] CHK061 — Are the thresholds for each Cat-Stress-Score level defined in terms of observable behaviors the VLM can detect? [Completeness, Scientific Framework]
- [ ] CHK062 — Are the Helsinki Breed Study's 7 behavioral traits mapped to specific agent outputs, or is the mapping left to prompt engineering? [Clarity, Scientific Framework]
- [ ] CHK063 — Are the pain assessment indicators (Robertson 2008) specified as concrete observable features in video frames? [Completeness, Scientific Framework]
- [ ] CHK064 — Is the Archetype assignment algorithm specified — exact score thresholds or ranges for each trait pattern (e.g., "High Impulsiveness" = score > X)? [Clarity, Archetype System]
- [ ] CHK065 — Are requirements defined for when a cat's Feline Five scores don't match any predefined archetype pattern? [Gap, Archetype System]

## Non-Functional Requirements Coverage

- [ ] CHK066 — Are accessibility requirements specified for the Persona Card UI (VoiceOver, Dynamic Type, color contrast for radar chart)? [Gap, NFR]
- [ ] CHK067 — Are localization requirements defined for agent observation text and persona descriptions (v1 language: English only? German? Both?)? [Gap, NFR]
- [ ] CHK068 — Are battery consumption requirements or guidelines specified for the 8–30 minute analysis pipeline? [Gap, NFR]
- [ ] CHK069 — Are app size requirements defined, considering the VLM model must be bundled or downloaded? [Gap, NFR]
- [ ] CHK070 — Is the minimum free RAM requirement specified for analysis start (given NFR-002 caps peak at 6.5 GB)? [Clarity, Spec §NFR-002]

## v1 / v2 Scope Boundaries

- [ ] CHK071 — Are the 6 deferred items (Share, Photo, Langzeit, Stress UI, Agent-specific frames, i18n) each clearly marked with the FR/US they affect? [Completeness, v1 Scope]
- [ ] CHK072 — Do the functional requirements (FR-001–FR-022) have clear v1/v2 annotations, or do FRs exist that span both scopes without disambiguation? [Consistency, v1 Scope]
- [ ] CHK073 — Are the v1 acceptance criteria (US-1 through US-3) free of v2-deferred functionality in their scenarios? [Consistency, v1 Scope]
- [ ] CHK074 — Is the CatProfile entity's role in v1 defined, given Langzeit-Profil is deferred — does v1 use CatProfile at all, or is it a v2-only entity? [Ambiguity, v1 Scope]
- [ ] CHK075 — Is the MediaInput entity's v1 scope consistent with "Video input only" — are photo-related fields deferred? [Consistency, v1 Scope]

## Dependencies & Assumptions

- [ ] CHK076 — Is the assumption "Qwen3-VL-4B-Instruct-MLX-4bit ist leistungsfähig genug für visuelle Katzenanalyse" validated with evidence or a validation milestone? [Assumption]
- [ ] CHK077 — Is the dependency on 002-Pipeline-Infrastruktur specified with required interface versions and any breaking-change risks? [Dependency, Spec §Assumptions]
- [ ] CHK078 — Is the assumption about acceptable wait times (minutes per agent) validated with user research or usability requirements? [Assumption]
- [ ] CHK079 — Are the 8 GB RAM device constraints validated against the 6-agent sequential pipeline's cumulative memory pattern (allocation/deallocation per agent)? [Assumption, Spec §NFR-002]

## Notes

- Check items off as completed: `[x]`
- Add comments or findings inline
- Items marked `[Conflict]` require immediate resolution before implementation
- Items marked `[Gap]` indicate missing requirements that should be authored
- Items marked `[Ambiguity]` need clarification in the spec
- 5 major conflicts identified (CHK026–CHK033) between FRs and v1 scope boundary
- 1 constitution conflict identified (CHK031) between clip duration constraints
