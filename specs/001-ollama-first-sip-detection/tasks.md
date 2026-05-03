# Tasks: Ollama First-Sip Detection

**Input**: Design documents from `specs/001-ollama-first-sip-detection/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)
**Last Updated**: 2026-05-02

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure) ✅

**Purpose**: Projektstruktur und Abhängigkeiten einrichten

- [x] T001 Projektstruktur anlegen: `src/`, `prompts/v1/`, `tests/`, `tests/fixtures/`
- [x] T002 Python-Projekt initialisieren: `pyproject.toml` mit Dependencies (ollama, opencv-python, pydantic, click, pytest)
- [x] T003 [P] Pydantic-Schemas definieren in `src/schemas.py`: `AnalysisResult`, `AnalysisConfig`, `FrameData`

---

## Phase 2: Foundational (Blocking Prerequisites) ✅

**Purpose**: Kernmodule die für alle User Stories benötigt werden

- [x] T004 [US1] Frame Extractor implementieren: `src/frame_extractor.py` – Video laden, N gleichverteilte Frames extrahieren, als base64 zurückgeben
- [x] T005 [US1] Unit-Tests Frame Extractor: `tests/test_frame_extractor.py` – Tests mit kurzem Testvideo
- [x] T006 [US1] Prompt Engine implementieren: `src/prompt_engine.py` – Template aus `prompts/v2/` laden, Frames einbetten, System+User-Prompt bauen
- [x] T007 [US1] Prompt-Template erstellen: `prompts/v2/system_prompt.txt` + `user_prompt_template.txt` – Rolle, JSON-Schema-Vorgabe, Bewertungsdimensionen
- [x] T008 [US1] Ollama Client implementieren: `src/ollama_client.py` – Async-Aufruf an Ollama API, think=True, num_ctx=16384, Temperatur 0.0
- [x] T009 [US1] Unit-Tests Ollama Client: `tests/test_ollama_client.py` – Mock-Tests für API-Aufruf und Fehlerbehandlung
- [x] T010 [US1] Result Parser implementieren: `src/result_parser.py` – Ollama-Antwort → Pydantic AnalysisResult validieren + Fallback-Parsing
- [x] T011 [US1] Unit-Tests Result Parser: `tests/test_result_parser.py` – Valide/invalide JSON-Antworten testen

---

## Phase 3: User Story 1 – Erster Schluck erkennen (P1) ✅

**Purpose**: End-to-End-Erkennung eines positiven Trinkvorgangs

- [x] T012 [US1] Analyzer-Orchestrierung implementieren: `src/analyzer.py` – Pipeline: clip → frames → prompt → ollama → result
- [x] T013 [US1] CLI implementieren: `src/cli.py` – `analyze` + `check` Befehle, JSON-Output
- [x] T014 [US1] Integrationstest positiver Fall: `tests/test_analyzer_integration.py` – Testclip mit echtem Schluck, erwartetes JSON prüfen

---

## Phase 4: User Story 2 – Posieren ablehnen (P1) ✅

**Purpose**: False-Positive-Fälle korrekt als negativ erkennen

- [x] T015 [P] [US2] Integrationstest negativer Fall: `tests/test_analyzer_integration.py` – Testclip „Bier halten ohne Trinken"
- [x] T016 [P] [US2] Integrationstest Sip-not-first: Testclip „Trinken aus halb-leerem Glas" → false (kein erster Schluck)
- [x] T017 [US2] Prompt-Tuning v2: `prompts/v2/` – Explizite Negativbeispiele, Fill-Level-Kriterium im Prompt

---

## Phase 5: User Story 3 – Ungültigen Clip erkennen (P2) ✅

**Purpose**: Fehlerbehandlung für unbrauchbare Eingaben

- [x] T018 [P] [US3] Validierung in Frame Extractor: Leere/korrupte Videos erkennen → FileNotFoundError / ValueError
- [x] T019 [P] [US3] Logik für fehlende Evidenz: `_is_definitive_negative()` – face_visible=false, drinking_object_visible=false → Frühes Negativ
- [x] T020 [US3] Test ungültiger Clip: Integration-Tests mit fehlenden Signalen

---

## Phase 6: Sliding Window & Fill-Level Gate ✅

**Purpose**: Temporale Abdeckung verbessern, False Positives durch Füllstand-Prüfung eliminieren

- [x] T029 [US2] Sliding-Window-Analyse: `analyze_clip_sliding()` – 3 überlappende Fenster, OR-Logik, Early-Exit bei Positive/Definitive-Negative
- [x] T030 [US2] Fill-Level-Gate: `_check_fill_level()` – Dedizierter Prompt, 2 Frames (schärfster), 3× Majority-Vote, Vorab-Ablehnung bei half/empty
- [x] T031 [US2] Fill-Level-Prompt: `prompts/v2/fill_level_prompt.txt` – Fokussierter Prompt nur für Füllstand
- [x] T032 [US2] `call_ollama_light`: Leichtgewichtiger Client-Pfad (think=False, 4K ctx) für Gate-Abfragen
- [x] T033 [US2] `_parse_fill_level()`: JSON-Parse + Keyword-Fallback für Füllstand-Antworten
- [x] T034 [US2] Integration-Tests Fill-Level: 14 parametrisierte Tests für `_parse_fill_level`, Gate-Logik-Tests

---

## Phase 7: Robustheit & Observability ✅

**Purpose**: Betriebssicherheit und Debugging-Support

- [x] T035 Timeouts: `asyncio.wait_for` in `call_ollama` (90s) und `call_ollama_light` (30s), konfigurierbar via Env-Vars
- [x] T036 `--verbose` Flag: Structured Logging für Fill-Level-Gate-Votes, Window-Ergebnisse auf stderr
- [x] T037 Sharpness-basierte Frame-Selektion: Laplacian-Varianz für Gate-Frame-Auswahl (2 Kandidaten → schärfster)

---

## Phase 8: E2E Tests & Fixtures ✅

**Purpose**: Live-Validierung gegen echte Ollama-Instanz

- [x] T038 E2E-Test-Framework: `tests/test_analyzer_e2e.py` mit `--run-e2e`, `--e2e-full-config`, `--e2e-case`, `--e2e-isolate`
- [x] T039 Golden Fixtures: 4 `.result.json` Dateien (2× positiv, 1× no_sip, 1× sip_not_first) mit ground_truth + config + last_run
- [x] T040 Fixture-Auto-Update: `_update_fixture_on_pass()` schreibt last_run bei erfolgreichem E2E-Pass
- [x] T041 Model-Isolation: `unload_model()` + Cooldown zwischen Cases für konsistente Ergebnisse

---

## Phase 9: Noch offen

**Purpose**: Verbleibende Lücken für Produktionsreife

- [ ] T021 [US4] Test teilweise Verdeckung: E2E-Fixture mit verdecktem Gesicht → `confidence < 0.5`
- [ ] T022 [US4] Test schlechte Beleuchtung: Dunkler Clip → kein erzwungenes Positiv
- [ ] T026 Modell-Evaluierung: Testmatrix über alle Fixtures → Precision/Recall/Confusion Matrix
- [ ] T042 Fixture-Corpus erweitern: 15–20 Clips für statistische Validierung der VLM-Stabilität
- [ ] T043 CI-Integration: GitHub Actions mit `--run-e2e` gegen Ollama-Container (optional)
