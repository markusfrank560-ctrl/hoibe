# Hoibe – Ollama First-Sip Detection

Lokale Erkennung eines „ersten Schlucks" aus kurzen Video-Clips mittels Ollama VLM. Kein Cloud-Upload, vollständig offline.

## Voraussetzungen

- Python 3.11+
- [Ollama](https://ollama.com/) installiert und laufend (`ollama serve`)
- Multimodales Modell geladen: `ollama pull qwen3-vl:4b`

## Installation

```bash
uv venv --python python3.12
source .venv/bin/activate
uv pip install -e ".[dev]"
```

## Verwendung

### CLI – Analyse mit Datei-Output

```bash
hoibe analyze path/to/clip.mp4
# → Erzeugt path/to/clip.result.json
```

### CLI – Ergebnis auf stdout

```bash
hoibe check path/to/clip.mp4
```

### Sliding-Window-Modus (empfohlen)

```bash
hoibe check path/to/clip.mp4 --sliding
hoibe analyze path/to/clip.mp4 --sliding
```

Der Sliding-Window-Modus analysiert den Clip in 3 überlappenden Fenstern und enthält eine Vorab-Füllstand-Prüfung, die False Positives bei halb-leeren Gläsern verhindert.

### Optionen

```bash
hoibe analyze clip.mp4 --model qwen3-vl:4b --frames 2 --threshold 0.8 --sliding
```

| Option | Default | Beschreibung |
|--------|---------|-------------|
| `--model` | `qwen3-vl:4b` | Ollama-Modellname |
| `--frames` | `2` | Anzahl extrahierter Frames pro Fenster |
| `--threshold` | `0.7` | Confidence-Schwellenwert für positive Erkennung |
| `--sliding` | `false` | Sliding-Window-Modus mit Füllstand-Gate |
| `--sliding-window-count` | `3` | Anzahl überlappender Fenster |
| `--sliding-window-min-span` | `0.6` | Mindestanteil des Clips pro Fenster |
| `--output` / `-o` | neben Video | Pfad für Output-JSON |

### Umgebungsvariablen

| Variable | Default | Beschreibung |
|----------|---------|-------------|
| `HOIBE_COOLDOWN` | `5` | Sekunden Pause zwischen Modell-Isolierungen |
| `HOIBE_TIMEOUT` | `90` | Timeout (s) für VLM-Inferenz |
| `HOIBE_TIMEOUT_LIGHT` | `30` | Timeout (s) für leichte Abfragen (Füllstand) |

## Ausgabeformat

```json
{
  "first_sip_detected": true,
  "confidence": 0.95,
  "face_visible": true,
  "drinking_object_visible": true,
  "mouth_contact_likely": true,
  "beer_likely": "true",
  "beer_fill_level": "full",
  "reason_short": "Person drinking from beer glass with clear tilt and mouth contact",
  "model_name": "qwen3-vl:4b",
  "analysis_version": "v2"
}
```

## Tests

```bash
# Unit + Integration
python -m pytest tests/ -v

# E2E gegen laufende Ollama-Instanz
python -m pytest tests/ -v --run-e2e --e2e-full-config
```

## Architektur

```
VideoClip (.mp4)
  → Frame Extractor (endpoint-inclusive sampling)
  → [Sliding] Fill-Level Gate (2 frames, sharpest, 3× majority vote)
  → Prompt Engine (v2, system + user + images)
  → Ollama Client (think=True, 16K ctx, 90s timeout)
  → Result Parser (JSON extraction + threshold gate)
  → AnalysisResult JSON
```

Modularer Aufbau: `src/frame_extractor.py`, `src/prompt_engine.py`, `src/ollama_client.py`, `src/result_parser.py`, `src/analyzer.py`

## Spec-Driven Development

Dieses Projekt nutzt [GitHub Spec Kit](https://github.com/github/spec-kit). Artefakte:

- Constitution: `.specify/memory/constitution.md`
- Spec: `specs/001-ollama-first-sip-detection/spec.md`
- Plan: `specs/001-ollama-first-sip-detection/plan.md`
- Tasks: `specs/001-ollama-first-sip-detection/tasks.md`
# hoibe
