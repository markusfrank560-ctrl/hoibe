# Implementation Plan: Ollama First-Sip Detection

**Branch**: `001-ollama-first-sip-detection` | **Date**: 2026-04-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-ollama-first-sip-detection/spec.md`
**Last Updated**: 2026-05-02

## Summary

Lokale Softwarekomponente die aus kurzen Video-Clips (5–15s) mittels Frame-Extraktion und Ollama-VLM-Aufruf erkennt, ob ein erster Schluck aus einem Bierbehälter stattgefunden hat. Strukturierte JSON-Ausgabe mit Confidence-Werten für nachgelagerte Regelprüfung. Asynchrone Verarbeitung, kein Cloud-Upload.

## Technical Context

**Language/Version**: Python 3.12  
**Primary Dependencies**: ollama (Python SDK), opencv-python (Frame-Extraktion), pydantic (Schema-Validierung)  
**Storage**: Lokales Dateisystem (Video-Input, JSON-Output)  
**Testing**: pytest + gelabelte Testclips  
**Target Platform**: macOS/Linux Desktop mit lokal installiertem Ollama  
**Project Type**: Library + CLI  
**Performance Goals**: Analyse eines 15s-Clips in < 5 Minuten  
**Constraints**: Offline-only, kein Netzwerk-Upload, RAM < 8GB für Modell-Inference  
**Scale/Scope**: Single-User, ein Clip pro Analyse-Aufruf

## Constitution Check

| Prinzip | Status |
|---------|--------|
| I. Privacy-First | ✅ Kein Cloud-Upload, alles lokal |
| II. Local Ollama | ✅ ollama Python SDK, localhost API |
| III. Structured Output | ✅ JSON-only via pydantic-Schema |
| IV. Hybrid Architecture | ✅ VLM als Reviewer, Regellogik extern |
| V. Async & Resource-Aware | ✅ asyncio-basiert, kein Dauerprozess |
| VI. Testability | ✅ pytest mit gelabelten Clips |
| VII. Versionierung | ✅ analysis_version im Output, Prompt-Dateien versioniert |

## Project Structure

### Documentation (this feature)

```text
specs/001-ollama-first-sip-detection/
├── spec.md              # Feature-Spezifikation
├── plan.md              # Dieser Implementierungsplan
└── tasks.md             # Aufgabenliste (via /speckit.tasks)
```

### Source Code (repository root)

```text
src/
├── __init__.py
├── frame_extractor.py    # Video → Schlüsselbilder (endpoint-inclusive sampling)
├── prompt_engine.py      # Prompt-Templates laden + Frames einbetten
├── ollama_client.py      # Ollama API-Aufruf (call_ollama + call_ollama_light)
├── result_parser.py      # JSON-Antwort validieren + strukturieren
├── analyzer.py           # Orchestrierung: clip → [gate] → frames → prompt → result
├── schemas.py            # Pydantic-Modelle (AnalysisResult, AnalysisConfig, FrameData)
└── cli.py                # CLI-Einstiegspunkt (analyze + check)

prompts/
├── v1/                   # Legacy prompt (deprecated)
└── v2/
    ├── system_prompt.txt
    ├── user_prompt_template.txt
    └── fill_level_prompt.txt    # Dedizierter Füllstand-Prompt

tests/
├── conftest.py                  # GoldenFixture, pytest options
├── test_frame_extractor.py
├── test_prompt_engine.py
├── test_ollama_client.py
├── test_result_parser.py
├── test_analyzer_integration.py
├── test_analyzer_e2e.py         # Live-Tests gegen Ollama
├── test_cli.py
└── fixtures/
    ├── videos/                  # Symlinks zu echten Clips
    └── results/                 # Golden .result.json pro Fixture
```

**Structure Decision**: Single-project Library+CLI. Keine Web-/Mobile-Komponente in diesem Schritt. Modular aufgebaut damit einzelne Module (Frame-Extraktion, Prompt, Client) unabhängig testbar und austauschbar sind.

## Architecture

### Datenfluss

```
VideoClip (.mp4)
    │
    ▼
┌─────────────────────┐
│ Frame Extractor      │  → N endpoint-inclusive Frames (Default: 2)
└─────────────────────┘
    │
    ▼ (Sliding-Window-Modus)
┌─────────────────────┐
│ Fill-Level Gate      │  → 2 Frames aus Start (0–10%), schärfster Frame
│ (call_ollama_light)  │     3× Majority-Vote mit fill_level_prompt.txt
└─────────────────────┘
    │ PASS (full/mostly_full)         │ REJECT (half/empty/mostly_empty)
    ▼                                  ▼
┌─────────────────────┐         Early Negative Return
│ Sliding Windows (3×) │         (confidence=0.0, mode=sliding_precheck)
│ Prompt Engine v2     │
│ call_ollama (think)  │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│ Result Parser        │  → JSON-Extraktion + Threshold-Gate (≥ 0.7)
└─────────────────────┘
    │
    ▼
AnalysisResult (JSON)
```

### Frame-Extraktionsstrategie

- Endpoint-inclusive Gleichverteilung: `start + i * (window_length - 1) / (num_frames - 1)`
- Default: 2 Frames pro Fenster (optimal für temporale Bewegungserkennung bei kleinem VLM)
- Konfigurierbar 1–16 Frames
- Im Sliding-Window-Modus: 3 überlappende Fenster mit min. 60% Clip-Abdeckung je Fenster

### Prompt-Strategie

- **v2 System-Prompt**: Strenge Rollenanweisung als Precision-Drink-Detection-System
- **v2 User-Prompt**: Frame-Beschreibung + Step-by-Step-Evaluation + JSON-Schema
- **v2 Fill-Level-Prompt**: Einzelframe-Analyse nur für Füllstand (leichtgewichtig)
- Temperatur: 0.0 (maximal deterministisch)
- Thinking Mode: `think=True` + `num_ctx=16384` für Hauptinferenz
- Light Mode: `think=False` + `num_ctx=4096` für Fill-Level-Gate

### Modellauswahl (evaluiert)

| Modell | Größe | Multimodal | Ergebnis |
|--------|-------|-----------|----------|
| minicpm-v | 4GB | ✅ | Zu unzuverlässig bei JSON-Output |
| llava:7b | 4GB | ✅ | Inkonsistente Ergebnisse |
| llama3.2-vision:11b | 11GB | ✅ | Gut aber zu langsam |
| **qwen3-vl:4b** | **2.8GB** | ✅ | **Gewählt**: Bester Tradeoff Geschwindigkeit/Qualität/JSON-Compliance |

Produktionsmodell: `qwen3-vl:4b` mit think=True für Chain-of-Thought-Reasoning.

## Dependencies

```
# pyproject.toml / requirements.txt
ollama>=0.4.0
opencv-python>=4.8.0
pydantic>=2.0
click>=8.0        # CLI
```

Dev-Dependencies:
```
pytest>=8.0
pytest-asyncio>=0.23
```

## Risks & Mitigations

| Risiko | Mitigation |
|--------|-----------|
| Modell liefert kein valides JSON | Regex-Fallback-Parser; Markdown-Block-Extraktion; think=True für bessere Compliance |
| Halluzination (false positive) | Temperatur 0.0; Fill-Level-Gate als Pre-Filter; Confidence-Threshold ≥ 0.7 |
| Schlechte Frame-Auswahl | Endpoint-inclusive Sampling; Sharpness-basierte Frame-Selektion im Gate |
| Ollama nicht installiert | Klare ConnectionError + Setup-Anleitung in CLI |
| Zu langsam auf Zielgerät | 2 Frames Default; call_ollama_light für Gate; Timeouts (90s/30s) |
| VLM-Nondeterminismus | Majority-Vote (3×) im Fill-Level-Gate; Sliding-Window OR-Logik |
| Model hängt / OOM | asyncio.wait_for Timeouts; RuntimeError bei Überschreitung |

## Out of Scope (explizit)

- Mobile App Deployment (iOS/Android)
- Rule Engine / Anti-Cheat
- Benutzerkonten / Backend
- Training eigener Modelle
- Streaming/Echtzeit-Analyse
