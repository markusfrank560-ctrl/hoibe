# Feature Specification: iOS On-Device First-Sip Detection

**Feature Branch**: `002-ios-on-device`  
**Created**: 2026-05-03  
**Status**: Draft  
**Input**: Port hoibe first-sip detection pipeline to run entirely on-device on iPhone using MLX Swift LM with Qwen3-VL-4B-Instruct-MLX-4bit  
**Base Feature**: `001-ollama-first-sip-detection`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Erster Schluck erkennen (Priority: P1)

Ein Nutzer nimmt mit der iPhone-App einen kurzen Video-Clip (5–15s) auf, in dem er/sie erstmals aus einem Bierglas, einer Bierflasche oder einer Bierdose trinkt. Die App analysiert den Clip vollständig lokal auf dem Gerät und meldet strukturiert zurück, ob ein valider erster Schluck stattgefunden hat.

**Why this priority**: Kernfunktionalität – ohne diese Erkennung existiert kein Produktwert. Direkte Portierung der bewährten 001-Logik.

**Independent Test**: Video mit klarem Schluck aus Bierglas in der App aufnehmen oder auswählen; Ergebnis-Karte mit ✅ und `confidence >= 0.7` prüfen.

**Acceptance Scenarios**:

1. **Given** ein Clip mit sichtbarem Gesicht + Bierglas + klarer Trinkbewegung, **When** die On-Device-Analyse abgeschlossen ist, **Then** zeigt die App ✅ mit `confidence >= 0.7` und kurzem Grund
2. **Given** ein Clip mit sichtbarem Gesicht + Bierglas + klarer Trinkbewegung, **When** die Analyse ausgeführt wird, **Then** werden keine Netzwerk-Requests während der Inferenz gesendet

---

### User Story 2 - Posieren ohne Schluck ablehnen (Priority: P1)

Ein Nutzer hält ein Bier vor die Kamera ohne zu trinken (Posieren, Anstoßen). Die App muss dies als negativen Fall erkennen.

**Why this priority**: Gleichwertig mit P1 – False Positives sind schädlicher als verpasste echte Schlücke (Precision > Recall).

**Independent Test**: Clip mit Bierglas-Halten ohne Mundkontakt aufnehmen; Ergebnis-Karte zeigt ❌.

**Acceptance Scenarios**:

1. **Given** ein Clip in dem ein Nutzer ein Bierglas nur hält, **When** die On-Device-Analyse abgeschlossen ist, **Then** zeigt die App ❌ mit `first_sip_detected: false`
2. **Given** ein Clip in dem Anstoßen ohne Trinken stattfindet, **When** die Analyse ausgeführt wird, **Then** zeigt die App ❌

---

### User Story 3 - Ungültigen Clip erkennen (Priority: P2)

Ein Clip enthält kein erkennbares Gesicht oder kein Getränk. Die App muss einen nicht-auswertbaren Status zurückmelden.

**Why this priority**: Fehlerbehandlung ist essentiell für gute UX, aber sekundär zur Kernerkennung.

**Independent Test**: Clip ohne sichtbares Gesicht einspielen; Ergebnis zeigt ❌ mit niedrigem Confidence und erklärendem Grund.

**Acceptance Scenarios**:

1. **Given** ein Clip ohne sichtbares Gesicht, **When** die Analyse abgeschlossen ist, **Then** zeigt die App ❌ mit `confidence <= 0.3` und erklärendem Grund
2. **Given** ein Clip ohne erkennbares Getränk, **When** die Analyse abgeschlossen ist, **Then** zeigt die App ❌ mit Hinweis auf fehlendes Getränk

---

### User Story 4 - Model Download & Setup (Priority: P1)

Beim ersten App-Start ist kein ML-Modell vorhanden. Der Nutzer muss das Modell (~2.5 GB) einmalig herunterladen bevor die Analyse funktioniert. Der Download zeigt Fortschritt, kann pausiert/fortgesetzt werden, und ist standardmäßig auf WiFi beschränkt.

**Why this priority**: Ohne Modell ist keine Analyse möglich – zwingend für Erstbenutzung.

**Independent Test**: App auf frischem Gerät starten; Download-UI erscheint, Fortschritt wird angezeigt, nach Abschluss ist Analyse verfügbar.

**Acceptance Scenarios**:

1. **Given** die App wird erstmals gestartet und kein Modell ist lokal vorhanden, **When** der Nutzer den Download startet, **Then** wird ein Fortschrittsbalken mit MB/Gesamtgröße angezeigt
2. **Given** der Download ist aktiv und das Gerät verliert WiFi, **When** die Verbindung wiederhergestellt wird, **Then** kann der Download fortgesetzt werden ohne Neustart
3. **Given** der Download ist abgeschlossen, **When** der Nutzer einen Clip analysieren will, **Then** ist die Analyse sofort verfügbar ohne erneuten Download
4. **Given** der Nutzer hat nur mobile Daten aktiv, **When** er den Download starten will, **Then** wird eine Warnung angezeigt mit Option zum Fortfahren oder Warten auf WiFi

---

### User Story 5 - Video Capture (Priority: P1)

Der Nutzer kann direkt in der App ein Video aufnehmen oder ein bestehendes Video aus der Bibliothek auswählen. Clips müssen 5–15s lang sein.

**Why this priority**: Input-Erfassung ist Grundvoraussetzung für die Analyse-Pipeline.

**Independent Test**: App öffnen, „Aufnehmen" wählen, 10s filmen, Clip wird zur Analyse übergeben.

**Acceptance Scenarios**:

1. **Given** der Nutzer tippt auf „Aufnehmen", **When** er 10 Sekunden filmt und stoppt, **Then** wird der Clip zur Analyse bereitgestellt
2. **Given** der Nutzer tippt auf „Aus Bibliothek", **When** er ein 12s-Video auswählt, **Then** wird das Video zur Analyse bereitgestellt
3. **Given** der Nutzer wählt ein Video kürzer als 5s, **When** er es zur Analyse einreichen will, **Then** wird ein Hinweis angezeigt dass der Clip zu kurz ist
4. **Given** der Nutzer nimmt länger als 15s auf, **When** die Aufnahme 15s erreicht, **Then** wird die Aufnahme automatisch gestoppt

---

### User Story 6 - On-Device Privacy (Priority: P1)

Während der gesamten Analyse werden keine Netzwerk-Requests gesendet. Alle Videoframes und Inferenz-Ergebnisse bleiben auf dem Gerät.

**Why this priority**: Datenschutz-Garantie ist Kernversprechen der App – keine Cloud-Abhängigkeit.

**Independent Test**: Gerät in Flugmodus versetzen (nach Model-Download), Analyse durchführen – muss erfolgreich abschließen.

**Acceptance Scenarios**:

1. **Given** das Modell ist heruntergeladen und das Gerät ist im Flugmodus, **When** der Nutzer einen Clip analysiert, **Then** schließt die Analyse erfolgreich ab
2. **Given** die Analyse läuft, **When** man den Netzwerkverkehr überwacht, **Then** werden keine ausgehenden Verbindungen hergestellt

---

### User Story 7 - Thermal Management (Priority: P2)

Bei anhaltender Inferenz auf dem Mobilgerät kann thermische Drosselung auftreten. Die App handhabt dies graceful mit Timeouts und informativer UI.

**Why this priority**: Verhindert Hänger und Abstürze bei intensiver Nutzung, aber nicht für Kernfunktionalität nötig.

**Independent Test**: Analyse bei warmem Gerät starten; App zeigt ggf. Hinweis, bricht aber nicht unerwartet ab.

**Acceptance Scenarios**:

1. **Given** die Inferenz überschreitet den konfigurierten Timeout, **When** die Zeitgrenze erreicht wird, **Then** wird die Analyse sauber abgebrochen und eine Fehlermeldung angezeigt
2. **Given** das Gerät ist thermisch gedrosselt, **When** der Nutzer eine Analyse startet, **Then** wird die Analyse trotzdem gestartet, aber der Timeout verhindert endloses Warten

---

### Edge Cases

- Was passiert wenn der Model-Download bei 50% abbricht? → Partieller Download wird erkannt, Nutzer kann fortsetzen
- Was bei unzureichendem Speicherplatz für das Modell? → Hinweis vor Download mit benötigtem Speicherplatz
- Was bei Jetsam (Memory-Kill durch iOS)? → App erkennt beim Neustart den unterbrochenen Zustand und bietet Retry an
- Was bei mehreren Personen im Bild? → Nur bei klarem Schluck einer Person positiv (wie 001)
- Was bei Videos mit falschem Codec? → Definierter Fehler-Status mit Nutzerhinweis
- Was bei parallelem Kamera-Zugriff durch andere App? → Graceful Fehlerbehandlung

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUSS Video-Aufnahme via Kamera ermöglichen (5–15s, H.264/HEVC)
- **FR-002**: App MUSS Video-Auswahl aus der Foto-Bibliothek ermöglichen (5–15s Beschränkung)
- **FR-003**: App MUSS Frames aus dem Video extrahieren (gleicher Algorithmus wie 001: endpoint-inklusive Gleichverteilung über das Analysefenster)
- **FR-004**: App MUSS Inferenz mit Qwen3-VL-4B-MLX-4bit lokal auf dem Gerät ausführen (num_ctx=4096, think=false)
- **FR-005**: App MUSS Fill-Level-Gate implementieren: Füllstand-Prompt × N Votes (1 Frame pro Vote, schärfster Frame), Majority-Vote, Ablehnung bei {half, mostly_empty, empty}
- **FR-006**: App MUSS Sliding-Window-Analyse implementieren: 3 überlappende Fenster, OR-Logik, Early-Exit bei erstem Positiv
- **FR-007**: App MUSS call_timeout pro Inferenz-Aufruf einhalten (Default: 90s für Window-Analyse, 45s für Gate)
- **FR-008**: App MUSS das ML-Modell von HuggingFace herunterladen mit Fortschritts-UI und WiFi-only Option
- **FR-009**: App MUSS Ergebnisse als Karte darstellen (✅/❌ + Confidence + Grund)
- **FR-010**: App MUSS Prompt-Templates aus v3 verwenden (gebündelt in der App)
- **FR-011**: App MUSS Extended-Memory-Entitlement nutzen für >4 GB RAM-Nutzung
- **FR-012**: App MUSS vollständig offline funktionieren nach einmaligem Model-Download (keine Netzwerk-Requests während Analyse)
- **FR-013**: App MUSS das heruntergeladene Modell permanent im App-Container cachen
- **FR-014**: App MUSS strukturiertes JSON-Ergebnis mit Pflichtfeldern erzeugen (`first_sip_detected`, `confidence`, `reason_short`, `face_visible`, `drinking_object_visible`, `mouth_contact_likely`, `beer_likely`, `beer_fill_level`, `model_name`, `analysis_version`)

### Non-Functional Requirements

- **NFR-001**: Vollständige Pipeline innerhalb von 3 Minuten auf iPhone 15 Pro
- **NFR-002**: RAM-Spitze < 6.5 GB (kein Jetsam-Kill)
- **NFR-003**: Keine Netzwerk-Requests während der Analyse
- **NFR-004**: Modell permanent gecacht nach Download
- **NFR-005**: App funktioniert im Flugmodus nach Model-Download
- **NFR-006**: iOS 17.0+ Minimum (MLX Framework Voraussetzung)
- **NFR-007**: Unterstützte Geräte: iPhone 15 Pro, iPhone 16 Pro, iPhone 16e (alle 8 GB RAM)

### Key Entities

- **VideoClip**: Aufgenommener oder ausgewählter Clip, 5–15s, H.264/HEVC
- **FrameSet**: Extrahierte Schlüsselbilder für die Modellanalyse
- **AnalysisResult**: Strukturiertes Ergebnis mit allen Bewertungsfeldern (kompatibel mit 001-Schema)
- **MLXModel**: Heruntergeladenes Qwen3-VL-4B-MLX-4bit Modell (~2.5 GB)
- **PromptTemplate**: Gebündelte v3 Prompt-Templates (system_prompt, user_prompt, fill_level_prompt)
- **ModelDownloadState**: Zustand des Model-Downloads (pending, downloading, paused, complete, error)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Precision für `first_sip_detected: true` liegt bei ≥ 85% auf dem Testdatensatz (identisch zu 001)
- **SC-002**: Recall für echte erste Schlücke liegt bei ≥ 70% auf dem Testdatensatz (identisch zu 001)
- **SC-003**: Vollständige Pipeline-Verarbeitung eines 15s-Clips innerhalb von 3 Minuten auf iPhone 15 Pro
- **SC-004**: RAM-Peak während Analyse bleibt unter 6.5 GB (kein Jetsam-Kill auf 8 GB Geräten)
- **SC-005**: Keine ausgehenden Netzwerk-Verbindungen während der Analyse (verifizierbar via Instruments)
- **SC-006**: False-Positive-Rate für „Posieren ohne Trinken"-Szenarien liegt bei ≤ 10%
- **SC-007**: Model-Download kann nach Unterbrechung fortgesetzt werden ohne Datenverlust
- **SC-008**: App startet und ist analysefähig innerhalb von 10 Sekunden nach App-Launch (Modell bereits geladen)

## Assumptions

- Zielgeräte haben mindestens 8 GB RAM (iPhone 15 Pro, 16 Pro, 16e)
- MLX Swift LM unterstützt Qwen3-VL-4B in der 4-bit quantisierten Variante
- HuggingFace-Hosting ist verfügbar für den initialen Model-Download
- v3 Prompts mit num_ctx=4096 liefern auf MLX vergleichbare Ergebnisse wie auf Ollama (validiert in Phase 0)
- iOS Extended-Memory-Entitlement wird für die App genehmigt (Apple Review)
- Nutzer akzeptieren einmaligen ~2.5 GB Download vor Erstbenutzung
- Nutzer akzeptieren Analysezeit von 1–3 Minuten pro Clip
- Testdatensatz aus 001 wird für iOS-Validierung wiederverwendet
- Anti-Cheat-Regeln, Session-Logik und Backend-Synchronisation sind NICHT Bestandteil dieser Spezifikation

## RAM Budget

| Component | Estimate |
|---|---|
| Qwen3-VL-4B MLX 4-bit weights | ~2.5 GB |
| KV cache at num_ctx=4096 | ~0.5–1 GB |
| Image encoding (1024px × 2) | ~0.3 GB |
| App + OS overhead | ~2.5 GB |
| **Total** | **~6–6.3 GB** |

## Compatibility with 001

This feature maintains full compatibility with `001-ollama-first-sip-detection`:

- **Same structured output schema** (all mandatory fields preserved)
- **Same prompt templates** (v3, bundled)
- **Same gate logic** (fill-level check, majority vote, rejection thresholds)
- **Same sliding-window strategy** (3 overlapping, OR-logic, early exit)
- **Same acceptance criteria** (Precision ≥ 85%, Recall ≥ 70%)
- **Same confidence threshold** (≥ 0.7 for positive detection)
