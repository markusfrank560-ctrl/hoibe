# Feature Specification: PawProfiler — Cat Behavior Profiling Pipeline

**Feature Branch**: `003-paw-profiler`  
**Created**: 2026-05-25  
**Status**: Draft (clarified)  
**Input**: PawProfiler — A new iOS app that uses expert cat behavior agents based on local Ollama/MLX models to create science-backed personality and behavior profiles of cats.  
**Base Feature**: `002-ios-on-device`

## Architecture Context

PawProfiler extends the multi-agent VLM pipeline established in 002. The existing infrastructure provides:

- **FrameExtracting** — video frame extraction with sharpness ranking
- **ModelManaging** — model download, caching, and inference lifecycle (MLX Swift LM)
- **PromptBuilding** — chat message construction from prompt templates
- **PipelineConfig** — configurable timeouts, frame counts, gate logic

PawProfiler reuses this infrastructure but replaces the sip-detection pipeline with a **multi-agent cat behavior analysis pipeline**:

| 002 Sip Detection | 003 PawProfiler |
|---|---|
| Fill-Level Gate (is glass full?) | Cat Gate (is there a cat?) |
| 3 Sliding Windows → OR-logic | 6 Specialist Agents → Coordinator synthesis |
| Binary result (sip/no-sip) | Composite profile (traits, mood, stress, breed) |
| Single AnalysisResult | AgentResult[] → CompositeProfile → CatProfile |

The pipeline pattern is: **Gate → Sequential Agent Dispatch → Hybrid Coordinator → Profile Output**.

### Clarified Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Coordinator type | Hybrid: code aggregates scores + archetype lookup; VLM generates persona description text | Deterministic scores & archetype, natural-language quality for user-facing prose |
| Agent execution | Sequential, all agents share same extracted frame set | Single MLX inference at a time on iPhone; clean progress UI ("Agent 3/6: Stress...") |
| Frames per agent | Configurable: `windowsPerAgent: 1` (Quick Profile, ~10 min) or `3` (Deep Profile, ~25 min) | Quick = 1 call/agent with 2–3 frames; Deep = 3 sliding windows/agent for temporal behavior changes |
| v1 scope boundary | Core v1: Gate + 6 Agents + Coordinator + Persona Card (radar, archetype, observations) | No share-as-image, no photo input, no Langzeit-Profil, no stress-specific UI. Single-session only |
| Project structure | Local Swift Package (`VLMPipeline`) for shared pipeline infra; PawProfiler as separate Xcode project importing it | Clean separation; Hoibe also imports the package; enables future pipeline apps |

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Katze per Video profilieren (Priority: P1)

Ein Nutzer nimmt einen kurzen Video-Clip (15–90s) seiner Katze auf oder wählt einen aus der Bibliothek. PawProfiler extrahiert Schlüsselbilder, routet sie durch spezialisierte Verhaltens-Agenten und generiert ein strukturiertes Katzenprofil mit Persönlichkeitsmerkmalen, Verhaltensindikatoren und einer „Cat Persona Card".

**Why this priority**: Kernfunktionalität — ohne Profilierung aus Video existiert kein Produktwert. Direkte Erweiterung der 002-Pipeline.

**Independent Test**: Video-Clip einer Katze in Spielhaltung einspielen; JSON-Profil mit ausgefüllten Sektionen für mindestens 4 Verhaltenskategorien und Cat Persona Card prüfen.

**Acceptance Scenarios**:

1. **Given** ein Video-Clip (15–90s) einer Katze mit sichtbarer Körpersprache, **When** die Analyse gestartet wird, **Then** liefert das System ein strukturiertes JSON-Profil mit Bewertungen in mindestens 4 von 6 Verhaltenskategorien
2. **Given** ein Video-Clip einer Katze, **When** die Analyse abgeschlossen ist, **Then** enthält das Profil alle Pflichtfelder (`feline_five_scores`, `overall_mood`, `confidence_per_agent`, `archetype_label`, `model_name`, `analysis_version`)
3. **Given** ein Video-Clip einer Katze in ruhiger Haltung, **When** die Analyse ausgeführt wird, **Then** spiegelt das Profil die entspannte Stimmung korrekt wider (z.B. `overall_mood: relaxed`, Extraversion-Score niedrig)

---

### User Story 2 — Spezialisierte Agenten analysieren verschiedene Verhaltensaspekte (Priority: P1)

Die Analyse wird nicht von einem einzelnen Monolith-Prompt durchgeführt, sondern von 6 spezialisierten Agenten. Jeder Agent ist Experte für einen Aspekt des Katzenverhaltens, hat domänenspezifische Forschungsliteratur im Kontext, und liefert seinen Teil des Profils unabhängig. Ein Coordinator-Agent synthetisiert die Einzelergebnisse zum Gesamtprofil.

**Why this priority**: Das Multi-Agenten-Design mit literaturgestützten Prompts ist das Alleinstellungsmerkmal — „A panel of virtual feline experts, each trained on real cat-behavior science."

**Independent Test**: Clip einspielen und verifizieren, dass mindestens 4 separate Agenten-Ergebnisse im Gesamtprofil zusammengeführt werden, erkennbar an individuellen Confidence-Werten pro Agent.

**Acceptance Scenarios**:

1. **Given** ein Video-Clip einer Katze, **When** die Analyse ausgeführt wird, **Then** werden alle 6 Agenten sequentiell oder parallel ausgewertet und ihre Einzelergebnisse an den Coordinator übergeben
2. **Given** ein Agent der keine verwertbaren Signale findet (z.B. Schwanz nicht sichtbar), **When** die Analyse ausgeführt wird, **Then** meldet dieser Agent `not_observable` mit Begründung statt eine Vermutung zu erzwingen
3. **Given** die Analyse ist abgeschlossen, **When** der Nutzer auf „Why?" tippt, **Then** zeigt die App die Begründung pro Agent mit Bezug auf die zugrunde liegende Forschung

---

### User Story 3 — Cat Persona Card als Hero-Output (Priority: P1)

Das Hauptergebnis ist eine visuell ansprechende „Cat Persona Card" — eine teilbare Karte mit Trait-Radar-Chart, Archetyp-Label (z.B. „The Midnight Gremlin", „The Royal Aristocat"), Verhaltensbeobachtungen und optionalen Gesundheitshinweisen.

**Why this priority**: Die Persona Card ist der virale Mechanismus und das primäre Nutzer-Artefakt. Ohne teilbares Output fehlt der Retention-Loop.

**Independent Test**: Analyse abschließen; Persona Card mit Radar-Chart, Archetyp-Label und mindestens 3 Verhaltensbeobachtungen prüfen; als Bild exportieren und Format verifizieren (9:16, Story-ready).

**Acceptance Scenarios**:

1. **Given** eine abgeschlossene Analyse, **When** die Persona Card angezeigt wird, **Then** enthält sie: Feline-Five Radar-Chart, Archetyp-Label, Top-3 Verhaltensbeobachtungen, und Breed-Affinity
2. **Given** eine Persona Card, **When** der Nutzer auf „Teilen" tippt, **Then** wird eine 9:16-Grafik generiert und der iOS-Sharesheet geöffnet
3. **Given** die Analyse ergibt Stressindikatoren, **When** die Persona Card angezeigt wird, **Then** enthält sie einen dezenten Hinweis „Worth monitoring" mit Erklärung

---

### User Story 4 — Foto-basierte Analyse (Priority: P2)

Ein Nutzer möchte ein einzelnes Foto seiner Katze analysieren lassen. Die App akzeptiert Einzelbilder und erstellt ein eingeschränkteres Profil (keine Bewegungsanalyse, keine zeitliche Veränderung).

**Why this priority**: Niedrigere Einstiegshürde als Video, liefert aber naturgemäß weniger Verhaltensinformationen.

**Independent Test**: Einzelfoto einer Katze einspielen; Profil mit verfügbaren Kategorien und Hinweis auf eingeschränkte Analyse prüfen.

**Acceptance Scenarios**:

1. **Given** ein einzelnes Foto einer Katze, **When** die Analyse gestartet wird, **Then** liefert das System ein Profil mit den aus einem Standbild ableitbaren Kategorien (Ohren, Körperhaltung, Rassevermutung)
2. **Given** ein Foto statt Video, **When** das Profil erstellt wird, **Then** kennzeichnet das System die eingeschränkte Datenbasis (`input_type: photo`, `behavioral_depth: limited`)

---

### User Story 5 — Langzeit-Profil aufbauen (Priority: P2)

Ein Nutzer analysiert seine Katze über mehrere Tage/Wochen mit verschiedenen Clips. PawProfiler aggregiert die Einzelanalysen zu einem immer tieferen, konsistenteren Langzeit-Profil pro Katze.

**Why this priority**: Langzeit-Profilierung liefert höheren Wert als Einzelanalysen, setzt aber funktionierende Einzelanalyse voraus.

**Independent Test**: 3 separate Analysen für dieselbe Katze durchführen; aggregiertes Profil muss konsistente Merkmale stärker gewichten.

**Acceptance Scenarios**:

1. **Given** drei separate Analysen derselben Katze, **When** das aggregierte Profil abgerufen wird, **Then** zeigt es gewichtete Durchschnittswerte mit Trend-Indikatoren
2. **Given** eine Katze die in verschiedenen Clips unterschiedliche Stimmungen zeigt, **When** das Langzeitprofil erstellt wird, **Then** bildet es die Bandbreite des Verhaltens korrekt ab (z.B. `mood_range: [playful, cautious]`)

---

### User Story 6 — Stressindikator-Erkennung (Priority: P2)

Der Stress-Agent erkennt Stressanzeichen (angelegte Ohren, aufgeplusterter Schwanz, Ducken, übermäßiges Putzen) basierend auf dem Cat-Stress-Score (Kessler & Turner 1997) und gibt dem Nutzer verständliche Hinweise — informativ, nie diagnostisch.

**Why this priority**: Echter Mehrwert für Katzenbesitzer die Warnzeichen nicht selbst erkennen. Klare Abgrenzung: „behavioral insights, never diagnoses."

**Independent Test**: Clip einer Katze mit typischen Stresszeichen einspielen; Profil muss Stress-Indikator mit Erklärung und „consider discussing with vet"-Formulierung enthalten.

**Acceptance Scenarios**:

1. **Given** ein Video-Clip einer Katze mit angelegten Ohren und geduckter Haltung, **When** die Analyse ausgeführt wird, **Then** enthält das Profil `stress_indicators` mit erkannten Zeichen und Erklärung in „suggests/may indicate"-Sprache
2. **Given** ein Video-Clip einer entspannten Katze, **When** die Analyse ausgeführt wird, **Then** meldet der Stress-Agent `no_stress_detected`

---

### User Story 7 — Rassevermutung und Archetype-Zuordnung (Priority: P3)

Der Breed & Archetype Agent vermutet anhand visueller Merkmale die wahrscheinliche Rasse und ordnet der Katze einen Archetyp zu (z.B. „The Lone Strategist", „The Chaotic Gremlin") basierend auf der Kombination aller Feline-Five-Scores.

**Why this priority**: Nice-to-have für Katzenbesitzer, aber keine Kernfunktion der Verhaltensanalyse.

**Acceptance Scenarios**:

1. **Given** ein Video/Foto einer Katze mit deutlichen Rassemerkmalen, **When** die Analyse ausgeführt wird, **Then** enthält das Profil `breed_estimate` mit Top-3-Vermutungen und Confidence-Werten
2. **Given** die Feline-Five-Scores einer Katze, **When** der Archetyp berechnet wird, **Then** wird ein Label aus der definierten Archetyp-Tabelle zugeordnet mit Erklärung

---

### Edge Cases

- Was passiert bei Clips ohne erkennbare Katze? → Cat Gate lehnt ab mit `no_cat_detected`, Detail-Agenten werden nicht gestartet
- Was bei mehreren Katzen im Bild? → Analyse der dominanten/größten Katze, Hinweis auf weitere erkannte Tiere
- Was bei sehr dunklen oder unscharfen Aufnahmen? → Eingeschränkte Analyse mit niedrigen Confidence-Werten und Qualitätshinweis
- Was bei anderen Tieren (Hund, Kaninchen)? → Cat Gate lehnt ab mit `not_a_cat` und Tierart-Vermutung
- Was bei extrem kurzen Clips (<5s)? → Unzureichende Evidenz, niedrige Confidence, Empfehlung für längeren Clip
- Was bei schneller Bewegung (Unschärfe)? → Frame-Extraktor wählt schärfste Frames; Agenten melden `motion_blur_detected` für betroffene Bereiche
- Was bei teilweise verdeckter Katze? → Verfügbare Körperteile analysieren, nicht sichtbare als `not_observable` melden
- Was bei Agent-Timeout? → Coordinator synthetisiert aus den verfügbaren Agent-Ergebnissen; fehlende Agenten werden als `timed_out` markiert

## Requirements *(mandatory)*

### Functional Requirements

**Pipeline Infrastructure (extending 002)**:

- **FR-001**: System MUSS die bestehende 002-Pipeline-Infrastruktur wiederverwenden: `FrameExtracting`, `ModelManaging`, `PromptBuilding`-Protokolle, `PipelineConfig`-Muster
- **FR-002**: System MUSS als eigenständige iOS App („PawProfiler") in einem separaten Xcode-Projekt gebaut werden. Geteilte Pipeline-Infrastruktur (`FrameExtracting`, `ModelManaging`, `PromptBuilding`, `PipelineConfig`) wird in ein lokales Swift Package (`VLMPipeline`) extrahiert, das beide Apps (Hoibe, PawProfiler) importieren
- **FR-003**: System MUSS lokal auf dem Gerät via MLX Swift LM inferieren. Keine Cloud-APIs, keine externe Datenübertragung von Bild-/Videomaterial. Gleiche Privacy-Garantien wie 002

**Cat Gate (analog zu Fill-Level Gate in 002)**:

- **FR-004**: System MUSS vor der Detail-Analyse einen Cat Gate ausführen: Ist überhaupt eine Katze im Bild? Majority-Vote über N Frames (analog 002 Fill-Level Gate)
- **FR-005**: Cat Gate MUSS `cat_detected`, `no_cat_detected`, oder `not_a_cat` (mit Tierart-Vermutung) zurückgeben. Bei `no_cat_detected`/`not_a_cat` werden keine Detail-Agenten gestartet

**Multi-Agent Pipeline**:

- **FR-006**: System MUSS ein Multi-Agenten-System mit folgenden 6 spezialisierten Agenten implementieren:
  1. **Personality & Trait Classifier** — Feline Five Dimensionen (Neuroticism, Extraversion, Dominance, Impulsiveness, Agreeableness) nach Litchfield et al. 2017
  2. **Social Behavior & Human Bonding Agent** — Attachment-Style, Proximity, Blickkontakt, Vokalisation nach Vitale Shreve & Udell 2017, Turner & Bateson
  3. **Play, Activity & Predatory Agent** — Bewegungsgeschwindigkeit, Spielstil (Stalking, Batting, Leaping), Aktivitätsrhythmus nach Hall et al. 2002
  4. **Stress, Anxiety & Welfare Agent** — Cat-Stress-Score nach Kessler & Turner 1997, AAFP/ISFM Guidelines, Dantas et al.
  5. **Health-Behavior Correlation Scout** — Schmerz-Indikatoren nach Robertson 2008, Aktivitätsveränderungen nach Lascelles et al. Nur „consider discussing with vet"-Flags, keine Diagnosen
  6. **Breed & Archetype Agent** — Rassemerkmale nach Salonen et al. 2019, Archetyp-Zuordnung aus Trait-Kombinationen

- **FR-007**: Jeder Agent MUSS eine strukturierte JSON-Antwort mit eigenem Confidence-Wert und `observations`-Array liefern. Agent-Schemata sind versioniert
- **FR-008**: Jeder Agent-Prompt MUSS domänenspezifische Forschungsliteratur als Kontext eingebettet haben (Key Findings, nicht Volltext). Sprache: „consistent with", „suggests", „may indicate" — nie „diagnoses" oder „is"
- **FR-009**: Agenten die keine verwertbaren Signale finden MÜSSEN `not_observable` mit Begründung melden statt Vermutungen zu erzwingen

**Coordinator & Synthesis (Hybrid)**:

- **FR-010**: System MUSS einen Hybrid-Coordinator implementieren:
  - **Code-basiert** (deterministic): Feline-Five-Score-Aggregation (gewichteter Durchschnitt), Archetyp-Lookup aus der definierten Tabelle, Stress-/Gesundheitsflags-Sammlung
  - **VLM-basiert** (1 Inference-Call): Generiert die menschenlesbare Persona-Beschreibung, Top-Beobachtungen, und kontextuelle Erklärungen aus den aggregierten Agent-Ergebnissen
- **FR-011**: Coordinator MUSS auch bei teilweisen Agent-Ergebnissen (Timeout, `not_observable`) ein sinnvolles Profil generieren können. Code-basierte Aggregation arbeitet mit verfügbaren Scores; VLM-Call erhält Hinweis auf fehlende Agenten

**Output & Persistence**:

- **FR-012**: System MUSS ein `CompositeProfile` als strukturiertes JSON speichern mit allen Pflichtfeldern
- **FR-013**: System MUSS eine Cat Persona Card generieren: Feline-Five Radar-Chart, Archetyp-Label, Top-Beobachtungen, Breed-Affinity, optionale Stress-/Gesundheitshinweise
- **FR-014**: System MUSS Persona Cards als 9:16-Grafik exportierbar machen (iOS Sharesheet)
- **FR-015**: System MUSS ein Langzeit-CatProfile pro Katze pflegen das Einzelanalysen aggregiert und Verhaltenstrends abbildet
- **FR-016**: System MUSS Ergebnisse lokal auf dem Gerät speichern. Kein Sync, kein Cloud-Backup

**Input & Frame Extraction (reusing 002)**:

- **FR-017**: System MUSS Video-Clips (15–90s, MP4/MOV) und Einzelfotos (JPEG/HEIC/PNG) als Eingabe verarbeiten
- **FR-018**: System MUSS Schlüsselbilder aus Video-Clips extrahieren (konfigurierbar, Default: 4–8 Frames, schärfste Frames bevorzugt) — wiederverwendet `FrameExtracting`-Protokoll aus 002
- **FR-019**: System MUSS Timeouts pro Agent-Aufruf einhalten (konfigurierbar via PipelineConfig-Erweiterung). Bei Timeout wird Agent als `timed_out` markiert

**Agent Execution Model**:

- **FR-020**: Agenten MÜSSEN sequentiell ausgeführt werden (eine MLX-Inference gleichzeitig). Alle Agenten erhalten denselben extrahierten Frame-Satz
- **FR-021**: System MUSS zwei Analyse-Modi unterstützen:
  - **Quick Profile** (`windowsPerAgent: 1`): 1 Aufruf pro Agent mit 2–3 Frames. Gesamtzeit ~8–12 Minuten. Default-Modus
  - **Deep Profile** (`windowsPerAgent: 3`): 3 Sliding-Window-Aufrufe pro Agent mit je 2–3 Frames. Gesamtzeit ~20–30 Minuten. Opt-in via UI-Toggle
- **FR-022**: UI MUSS Fortschritt pro Agent anzeigen (z.B. „Agent 3/6: Stress & Welfare…")

### Non-Functional Requirements

- **NFR-001**: Quick Profile Pipeline (Gate + 6 Agenten × 1 Window + Coordinator) innerhalb von 12 Minuten auf iPhone 15 Pro für einen 60s-Clip; Deep Profile innerhalb von 30 Minuten
- **NFR-002**: RAM-Spitze < 6.5 GB (identisch zu 002 — gleiches Modell, gleiche Geräte-Constraints)
- **NFR-003**: Keine Netzwerk-Requests während der Analyse
- **NFR-004**: iOS 17.0+ Minimum
- **NFR-005**: Unterstützte Geräte: iPhone 15 Pro, iPhone 16 Pro, iPhone 16e (8 GB RAM)

### Key Entities

- **CatProfile**: Langzeit-Profil einer Katze, aggregiert aus mehreren AnalysisSessions. Enthält Name, Foto, Verhaltenstrends, stabile Feline-Five-Scores
- **AnalysisSession**: Einzelne Analyse-Durchführung mit Input-Medium, Zeitstempel, und AgentResults
- **AgentResult**: Strukturiertes Teilergebnis eines spezialisierten Agenten. Schema: `{ agent_id, domain, trait_scores, observations[], flags[], confidence, status }`
- **CompositeProfile**: Coordinator-Output: zusammengeführtes Profil aus allen AgentResults einer Session. Schema: `{ feline_five_scores, archetype_label, overall_mood, breed_estimate, stress_indicators, health_flags, confidence_per_agent }`
- **CatPersonaCard**: Visuelles Artefakt generiert aus CompositeProfile — Radar-Chart, Archetyp, Beobachtungen, teilbare Grafik
- **MediaInput**: Video-Clip oder Foto als Eingabe. Reuses 002 `VideoClip`/`FrameSet` patterns
- **CatGateResult**: Ergebnis der Vorprüfung: `cat_detected` / `no_cat_detected` / `not_a_cat(species:)`

## Scientific Framework — The Feline Five

Das Profilierungssystem basiert auf validierten akademischen Frameworks:

- **Feline Five** (Litchfield et al., 2017): 5 messbare Persönlichkeitsdimensionen aus 2.802 Katzen — Neuroticism, Extraversion, Dominance, Impulsiveness, Agreeableness
- **Helsinki Breed Study** (Salonen et al., 2019, Nature): 7 Verhaltensmerkmale über 4.316 Katzen in 26 Rassen — Activity/Playfulness, Fearfulness, Aggression, Sociability (humans), Sociability (cats), Litterbox issues, Excessive grooming. Heritabilität 0.40–0.53
- **Cat-Stress-Score** (Kessler & Turner, 1997): Validiertes visuelles Stress-Bewertungssystem
- **Pain Assessment** (Robertson 2008, Lascelles et al.): Verhaltensbasierte Schmerz-Indikatoren

Die App mappt video-detektierte Verhaltensweisen (Bewegungsgeschwindigkeit, Haltung, Interaktionsstil, Putzverhalten, Schreckreaktion) auf diese Trait-Achsen.

## Archetype System

Archetypen werden aus Feline-Five-Score-Kombinationen abgeleitet:

| Archetype | Trait Pattern |
|---|---|
| The Midnight Gremlin | High Impulsiveness + High Extraversion |
| The Royal Aristocat | High Dominance + Low Impulsiveness |
| The Lone Strategist | High Dominance + Low Agreeableness |
| The Anxious Explorer | High Neuroticism + High Extraversion |
| The Gentle Soul | High Agreeableness + Low Dominance |
| The Couch Philosopher | Low Extraversion + Low Impulsiveness |
| The Social Butterfly | High Agreeableness + High Extraversion |
| The Chaotic Acrobat | High Extraversion + High Impulsiveness + Low Neuroticism |

*Archetyp-Tabelle wird im Coordinator-Prompt versioniert und ist erweiterbar.*

## Success Criteria *(mandatory)*

### v1 Scope Boundary

**In scope (v1 Core)**:
- Cat Gate (pre-check)
- 6 Specialist Agents (sequential, shared frames)
- Hybrid Coordinator (code aggregation + VLM persona text)
- Persona Card UI (radar chart, archetype label, observations)
- Quick Profile mode (default) + Deep Profile mode (opt-in)
- Video input only (15–90s clips)
- Single-session results (no persistence across sessions)
- Local Swift Package extraction (`VLMPipeline`)

**Deferred (v2+)**:
- Share-as-image (9:16 export, iOS Sharesheet) — US-3 AS-2
- Photo-based analysis — US-4
- Langzeit-Profil / CatProfile aggregation — US-5
- Stress-specific UI section — US-6 (agent runs, but no dedicated UI beyond Persona Card)
- Agent-specific frame selection — optimization for per-agent frame strategies
- Internationalization

### Measurable Outcomes

- **SC-001**: Nutzer können innerhalb von 2 Minuten nach App-Start eine erste Katzenanalyse starten (Onboarding + Clip-Auswahl + Start)
- **SC-002**: Quick Profile eines 60s-Video-Clips ist innerhalb von 12 Minuten abgeschlossen; Deep Profile innerhalb von 30 Minuten (Gate + 6 Agenten + Coordinator, lokale Inference)
- **SC-003**: Mindestens 4 von 6 Agenten liefern bei einem Standard-Katzenclip (Katze frontal, gute Beleuchtung) verwertbare Ergebnisse (Confidence ≥ 0.5)
- **SC-004**: Keine Netzwerk-Requests an externe Server während Analyse (verifizierbar via Instruments)
- **SC-005**: Bei 5 Wiederholungen derselben Analyse liefern ≥ 80% der Agenten konsistente Bewertungen (gleicher Trend, ähnliche Confidence)
- **SC-006**: False-Positive-Rate für „Katze erkannt" bei Nicht-Katzen-Input liegt bei ≤ 5%
- **SC-007**: 80% der Nutzer finden die Profilbeschreibungen ihrer Katze zutreffend (qualitative Nutzer-Validierung)
- **SC-008**: Persona Card wird von ≥ 50% der Nutzer mindestens einmal geteilt (Share-Rate als Viral-Metrik)

## Assumptions

- PawProfiler baut auf der 002-Pipeline-Infrastruktur auf (FrameExtracting, ModelManaging, PromptBuilding, PipelineConfig)
- Gleiches Modell wie 002: Qwen3-VL-4B-Instruct-MLX-4bit, gleiche RAM-Constraints, gleiche Geräte
- Multimodale VLMs der 4B-Klasse sind leistungsfähig genug für visuelle Katzenanalyse (validiert in Phase 0)
- Wartezeiten von Minuten pro Agent sind akzeptabel (kein Echtzeit-Anspruch)
- Katzenverhalten lässt sich aus Standbildern und kurzen Clips sinnvoll ableiten
- Veterinärmedizinische Diagnosen sind explizit NICHT Bestandteil — Stressindikatoren und Gesundheitsflags sind informativ, nie diagnostisch
- Sprache des Agent-Outputs: Deutsch (Nutzer-facing), Englisch (JSON-Keys und wissenschaftliche Referenzen)
- Internationalisierung ist nicht Teil der ersten Version
- Die bestehende Hoibe-App wird refactored: geteilte Pipeline-Module werden in ein lokales Swift Package (`VLMPipeline`) extrahiert. Hoibe importiert das Package statt direkte Quelldateien
- PawProfiler ist ein separates Xcode-Projekt das `VLMPipeline` importiert
- Model-Download und -Management wird 1:1 aus 002 übernommen (via VLMPipeline-Package)
