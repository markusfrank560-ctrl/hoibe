# Feature Specification: Ollama First-Sip Detection

**Feature Branch**: `001-ollama-first-sip-detection`  
**Created**: 2026-04-30  
**Status**: Implementation Complete  
**Input**: Lastenheft „Ollama-Modell zur Erkennung eines ersten Schlucks aus Video"  
**Last Updated**: 2026-05-02

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Erster Schluck erkennen (Priority: P1)

Ein Nutzer nimmt einen kurzen Video-Clip (5–15s) auf, in dem er/sie erstmals aus einem Bierglas, einer Bierflasche oder einer Bierdose trinkt. Die Komponente analysiert den Clip lokal und meldet strukturiert zurück, ob ein valider erster Schluck stattgefunden hat.

**Why this priority**: Kernfunktionalität – ohne diese Erkennung existiert kein Produktwert.

**Independent Test**: Testclip mit klarem Schluck aus Bierglas einspielen; JSON-Ergebnis mit `first_sip_detected: true` und `confidence >= 0.7` prüfen.

**Acceptance Scenarios**:

1. **Given** ein Clip mit sichtbarem Gesicht + Bierglas + klarer Trinkbewegung, **When** die Analyse ausgeführt wird, **Then** liefert die Komponente `first_sip_detected: true` mit `confidence >= 0.7`
2. **Given** ein Clip mit sichtbarem Gesicht + Bierglas + klarer Trinkbewegung, **When** die Analyse ausgeführt wird, **Then** enthält das Ergebnis alle Pflichtfelder (`face_visible`, `drinking_object_visible`, `mouth_contact_likely`, `beer_likely`, `reason_short`, `model_name`, `analysis_version`)

---

### User Story 2 - Posieren ohne Schluck ablehnen (Priority: P1)

Ein Nutzer hält ein Bier vor die Kamera ohne zu trinken (Posieren, Anstoßen). Die Komponente muss dies als negativen Fall erkennen.

**Why this priority**: Gleichwertig mit P1 – False Positives sind schädlicher als verpasste echte Schlücke (Precision > Recall).

**Independent Test**: Testclip mit Bierglas-Halten ohne Mundkontakt; JSON-Ergebnis mit `first_sip_detected: false`.

**Acceptance Scenarios**:

1. **Given** ein Clip in dem ein Nutzer ein Bierglas nur hält, **When** die Analyse ausgeführt wird, **Then** liefert die Komponente `first_sip_detected: false`
2. **Given** ein Clip in dem Anstoßen ohne Trinken stattfindet, **When** die Analyse ausgeführt wird, **Then** liefert die Komponente `first_sip_detected: false`

---

### User Story 3 - Ungültigen Clip erkennen (Priority: P2)

Ein Clip enthält kein erkennbares Gesicht oder kein Getränk. Die Komponente muss einen nicht-auswertbaren Status zurückmelden.

**Why this priority**: Fehlerbehandlung ist essentiell für Automatisierung, aber sekundär zur Kernerkennung.

**Independent Test**: Clip ohne sichtbares Gesicht einspielen; Ergebnis muss `first_sip_detected: false` mit `confidence <= 0.3` und erklärendem `reason_short` liefern.

**Acceptance Scenarios**:

1. **Given** ein Clip ohne sichtbares Gesicht, **When** die Analyse ausgeführt wird, **Then** liefert die Komponente `face_visible: false` und `first_sip_detected: false` mit niedrigem Confidence
2. **Given** ein Clip ohne erkennbares Getränk, **When** die Analyse ausgeführt wird, **Then** liefert die Komponente `drinking_object_visible: false` und `first_sip_detected: false`

---

### User Story 4 - Unsicherer Fall mit niedrigem Confidence (Priority: P2)

Verdeckungen oder schlechte Beleuchtung verhindern eine klare Entscheidung. Die Komponente meldet Unsicherheit statt eine harte Positiventscheidung zu erzwingen.

**Why this priority**: Kalibrierte Konfidenz ermöglicht nachgelagerte Regelentscheidungen.

**Independent Test**: Clip mit teilweise verdecktem Gesicht; `confidence < 0.5` und kein `first_sip_detected: true`.

**Acceptance Scenarios**:

1. **Given** ein Clip mit teilweise verdecktem Gesicht während einer Trinkbewegung, **When** die Analyse ausgeführt wird, **Then** ist `confidence < 0.5`
2. **Given** ein Clip mit sehr schlechter Beleuchtung, **When** die Analyse ausgeführt wird, **Then** erzwingt die Komponente kein `first_sip_detected: true`

---

### User Story 5 - Asynchrone Hintergrundverarbeitung (Priority: P3)

Die Analyse läuft im Hintergrund. Der Nutzer wartet nicht aktiv, sondern erhält das Ergebnis nach Abschluss (Sekunden bis Minuten akzeptabel).

**Why this priority**: UX-relevant, aber funktional bereits durch die Architektur gegeben.

**Independent Test**: Analyse programmatisch anstoßen; Ergebnis wird asynchron zurückgeliefert ohne blockierenden Aufruf.

**Acceptance Scenarios**:

1. **Given** ein gespeicherter Video-Clip, **When** die Analyse asynchron angestoßen wird, **Then** blockiert der Aufruf nicht und liefert das Ergebnis nach Abschluss
2. **Given** ein 15-Sekunden-Clip, **When** die Analyse auf einem System mit Ollama läuft, **Then** ist das Ergebnis innerhalb von 5 Minuten verfügbar

---

### Edge Cases

- Was passiert bei korrupten oder leeren Videodateien? → Definierter Fehler-Status
- Was bei mehreren Personen im Bild? → Nur bei klarem Schluck einer Person positiv
- Was bei mehreren Getränken im Bild? → Nur bei eindeutigem Mundkontakt positiv
- Was bei Nicht-Bier-Getränken? → `beer_likely: false/unknown`, kein Hard-Block
- Was bei extrem kurzen Clips (<2s)? → Unzureichende Evidenz, niedrige Confidence

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUSS einen lokal gespeicherten Video-Clip (5–15s, MP4/H.264) als Eingabe verarbeiten. Weitere Formate (MOV, WebM) können später ergänzt werden
- **FR-002**: System MUSS konfigurierbar N Schlüsselbilder aus dem Video extrahieren (Default: 2, Range: 1–16). Frame-Sampling nutzt endpoint-inklusive Gleichverteilung über das Analysefenster
- **FR-003**: System MUSS ein lokales Ollama-kompatibles multimodales Modell mit Bild-Eingabe aufrufen. Default-Modell: `qwen3-vl:4b` (4.4B Parameter, Q4_K_M). Modell ist via Konfiguration austauschbar
- **FR-004**: System MUSS eine strukturierte JSON-Antwort mit allen Pflichtfeldern liefern (`first_sip_detected`, `confidence`, `face_visible`, `drinking_object_visible`, `mouth_contact_likely`, `beer_likely`, `beer_fill_level`, `reason_short`, `model_name`, `analysis_version`)
- **FR-005**: System MUSS das Modell über ein enges JSON-only Prompt-Schema betreiben (keine offenen narrativen Ausgaben). `first_sip_detected: true` wird nur gesetzt wenn `confidence ≥ 0.7` (konfigurierbarer Schwellenwert)
- **FR-006**: System MUSS unbrauchbare Clips erkennen (kein Gesicht, kein Getränk, schlechte Qualität) und definierten Ablehnungsstatus zurückgeben
- **FR-007**: System MUSS asynchron im Hintergrund arbeiten (kein blockierender Live-Call). Ergebnis wird als JSON-Datei neben dem Video abgelegt (z.B. `clip.mp4` → `clip.result.json`)
- **FR-008**: System MUSS erweiterbar sein für spätere Integration externer CV-Signale (Füllstand, Schaum, Objektpersistenz)
- **FR-009**: System MUSS einen Sliding-Window-Modus unterstützen (Default: 3 überlappende Fenster, je ≥ 60% Clip-Dauer), der den Clip temporal vollständig abdeckt. Positive Erkennung in einem Fenster genügt (OR-Logik)
- **FR-010**: System MUSS im Sliding-Window-Modus eine Füllstand-Vorabprüfung durchführen (Fill-Level-Gate). Ein Glas das halb-leer oder leerer ist, KANN kein erster Schluck sein. Das Gate nutzt einen dedizierten leichtgewichtigen Prompt mit 3× Majority-Vote auf dem schärfsten Rest-Frame
- **FR-011**: System MUSS Timeouts für VLM-Aufrufe einhalten (Default: 90s für Hauptinferenz, 30s für leichte Abfragen). Bei Timeout wird ein definierter Fehler ausgelöst

### Key Entities

- **VideoClip**: Lokal gespeicherter Clip, 5–15s, enthält potentiellen Trinkvorgang
- **FrameSet**: Extrahierte Schlüsselbilder aus dem Clip für die Modellanalyse
- **AnalysisResult**: Strukturiertes JSON-Ergebnis mit allen Bewertungsfeldern
- **AnalysisPrompt**: Versioniertes Prompt-Template das die Modellausgabe einschränkt
- **Bierobjekt**: Erkanntes Glas/Flasche/Dose im Video

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Precision für `first_sip_detected: true` liegt bei ≥ 85% auf dem Testdatensatz
- **SC-002**: Recall für echte erste Schlücke liegt bei ≥ 70% auf dem Testdatensatz
- **SC-003**: Verarbeitung eines 15s-Clips abgeschlossen innerhalb von 5 Minuten (lokale Hardware)
- **SC-004**: Identisches Video + Modell + Prompt liefert bei 5 Wiederholungen ≥ 80% identische `first_sip_detected`-Entscheidungen
- **SC-005**: Keine Netzwerk-Requests an externe Server während der Analyse (verifizierbar via Netzwerk-Monitoring)
- **SC-006**: False-Positive-Rate für „Posieren ohne Trinken"-Szenarien liegt bei ≤ 10%

## Assumptions

- Nutzer akzeptieren asynchrone Analyse mit Wartezeit (Sekunden bis Minuten)
- Ollama ist auf dem Zielsystem installiert und ein multimodales Modell ist geladen
- Clips sind kurz (5–15s) und zeigen maximal wenige Personen
- Der enge Fokus „erster Schluck ja/nein" ist ausreichend – kein allgemeines Videoverständnis nötig
- Anti-Cheat-Regeln, Session-Logik und Mehrbenutzer-Features sind NICHT Bestandteil dieser Komponente
- Testdatensatz mit gelabelten Clips wird separat bereitgestellt
- Mobilgerät-Optimierung (iOS/Android) ist Zukunftsarbeit – Entwicklung erfolgt zunächst auf Desktop (macOS/Linux)
