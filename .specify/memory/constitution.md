# Hoibe – Project Constitution

## Core Principles

### I. Privacy-First (NON-NEGOTIABLE)
Alle Bild- und Videodaten bleiben lokal. Kein Cloud-Upload, keine externe Übertragung von Nutzerdaten. Verarbeitung erfolgt ausschließlich auf dem Gerät oder in eng gekoppelter lokaler Laufzeitumgebung.

### II. Local Ollama Inference
Alle ML/AI-Auswertungen nutzen ein Ollama-kompatibles multimodales Modell. Keine proprietären Cloud-APIs. Modelle müssen lokal lauffähig sein (edge/mobile VLM-Klasse bevorzugt).

### III. Structured Output Only
Modellausgaben sind ausschließlich maschinenlesbar (JSON). Keine offenen narrativen Antworten. Enge Prompt-Schemata mit definierten Feldern. Reproduzierbarkeit geht vor Flexibilität.

### IV. Hybrid Architecture
Semantische Bewertung (VLM) und harte Regelprüfung (CV/State Machine) sind strikt getrennt. Das Ollama-Modell ist Reviewer, nicht alleinige Wahrheit. Regelbasierte Entscheidungen werden nachgelagert getroffen.

### V. Asynchronous & Resource-Aware
Wartezeiten von Sekunden bis Minuten sind akzeptabel. Keine Echtzeit-Anforderung. Thermal Throttling vermeiden durch asynchrone Batch-Verarbeitung. Kein permanenter Inference-Prozess.

### VI. Testability & Precision
Hohe Precision ist wichtiger als maximaler Recall. Reproduzierbare Ergebnisse bei identischem Modell + Prompt + Frames. Testdatensatz mit klaren Positiv-/Negativ-/Unsicher-Szenarien.

### VII. Versionierung
Prompt-Versionen, Modellauswahl, Ausgabe-Schema und Frame-Selektionslogik müssen explizit versioniert werden. Keine impliziten Änderungen.

## Technical Constraints

- **Sprache**: Python (Ollama-SDK, OpenCV/ffmpeg für Frame-Extraktion)
- **Modell-Interface**: Ollama REST API (localhost)
- **Ausgabeformat**: JSON nach definiertem Schema
- **Video-Input**: Lokale Dateien, 5–15 Sekunden Clips
- **Ziel-Plattform (Dev)**: macOS/Linux mit Ollama installiert
- **Keine Abhängigkeiten** auf Cloud-Services, externe APIs oder Nutzerkonten

## Development Workflow

1. Spec-First: Anforderungen im Lastenheft definieren, bevor Code geschrieben wird
2. Modularer Aufbau: Frame-Extraktion, Prompt-Engine, Ollama-Client, Result-Parser als getrennte Module
3. Tests mit gelabelten Clips: Jede Änderung wird gegen Testdatensatz validiert
4. Prompt-Änderungen erfordern neue `analysis_version`

## Governance

Diese Constitution hat Vorrang vor ad-hoc-Entscheidungen. Änderungen erfordern Dokumentation und Begründung. Bei Konflikten zwischen Performance und Datenschutz gewinnt Datenschutz.

**Version**: 1.0.0 | **Ratified**: 2026-04-30 | **Last Amended**: 2026-04-30
