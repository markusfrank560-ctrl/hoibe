# Lastenheft – Komponente „Ollama-Modell zur Erkennung eines ersten Schlucks aus Video“

## Zielsetzung

Ziel ist die Spezifikation einer Softwarekomponente, die aus einem lokal vorliegenden Video-Clip erkennt, ob ein **erster Schluck** aus einem Bierglas, einer Bierflasche oder einer Bierdose erfolgt ist. Die Auswertung soll **lokal** erfolgen, ohne Upload des Videos in eine Cloud, und darf mit erhöhter Latenz im Hintergrund arbeiten, da Wartezeiten von mehreren zehn Sekunden bis wenigen Minuten akzeptabel sind. Frühere Recherchen zeigten, dass lokale Vision-Language-Modelle unter diesen Randbedingungen deutlich realistischer werden als für Echtzeit-Interaktion, während klassische CV- und Regelkomponenten weiterhin für harte Mess- und Anti-Cheat-Entscheidungen sinnvoll bleiben. [web:353][web:358][web:365]

Der hier beschriebene Umfang betrifft **ausschließlich** den Entwicklungsschritt für das lokale Ollama-basierte Modell beziehungsweise den Ollama-basierten Auswertungspfad. Nicht Gegenstand dieses Dokuments sind die vollständige mobile App, Social-/Challenge-Funktionen, Backend-Services oder die spätere Mehrbenutzerlogik.

## Ausgangslage

Die Produktidee basiert darauf, dass ein kurzer Video-Clip aufgenommen, lokal zwischengespeichert und danach im Hintergrund ausgewertet wird. Der Benutzer akzeptiert Wartezeiten; wichtiger sind Einfachheit und robuste Erkennung als Echtzeitverhalten. Diese Randbedingung verschiebt die technische Architektur weg von harter Streaming-Analyse hin zu „capture first, analyze later“, wodurch effiziente lokale VLMs bzw. Ollama-kompatible Multimodalmodelle als Reviewer oder Klassifikator relevant werden. [web:353][web:365]

Gleichzeitig bleibt das Problem kein reines Sprachproblem. Für robuste Entscheidungen über Mundkontakt, Objektpersistenz, Füllstand und Anti-Cheat sind strukturierte Signale und Regelprüfung weiterhin wichtig. Die Praxisbeispiele zur Drinking Detection empfehlen explizit, für jede Teilaufgabe das jeweils geeignetste Werkzeug zu verwenden, statt ein einziges großes Modell alles lösen zu lassen. [web:66]

## Gegenstand des Lastenhefts

Gegenstand ist eine Softwarekomponente mit folgenden Kernaufgaben:

- Entgegennahme eines lokal gespeicherten Video-Clips.
- Auswahl oder Annahme repräsentativer Frames bzw. kurzer Teilsequenzen.
- Übergabe dieser Daten an ein lokal verfügbares Ollama-kompatibles multimodales Modell.
- Auswertung, ob ein **valider erster Schluck** stattgefunden hat.
- Ausgabe eines strukturierten, maschinenlesbaren Ergebnisses.
- Bereitstellung von Confidence- und Begründungsfeldern für nachgelagerte Regelprüfung.

Nicht Bestandteil dieses Schrittes sind:

- Training großer Foundation-Modelle von Grund auf.
- Entwicklung eines vollständigen mobilen UI/UX-Workflows.
- Serverbasierte Bild- oder Videoanalyse.
- Benutzerkonten, Rankings oder Challenge-Scoring.
- Vollständige Anti-Cheat-Endlogik über mehrere Sessions hinweg.

## Fachliches Zielbild

Die Komponente soll nicht „frei beschreiben“, was in einem Video zu sehen ist, sondern eine **enge binäre bzw. strukturierte Entscheidung** liefern. Die Ausgabe soll auf das konkrete Produktziel einzahlen: „Wurde ein erster Schluck genommen?“ Der Ansatz mit enger, JSON-artiger Ausgabe reduziert Variabilität im Modellverhalten und macht die Komponente besser in automatisierte Folgeentscheidungen integrierbar. Forschung zu mobilen VLMs zeigt, dass Latenz vor allem durch Bildkodierung, Prompt-Prefill und Token-Generierung entsteht; daher ist eine kurze, stark eingeschränkte Antwortstruktur für lokale Modelle zweckmäßig. [web:353][web:364]

Das Modell soll idealerweise nicht alleinige Wahrheit sein, sondern als **semantischer Entscheider oder Reviewer** in einer Hybridarchitektur dienen. Effiziente Multimodalmodelle wie MiniCPM-V-artige Ansätze werden explizit als mobil beziehungsweise edge-tauglich beschrieben, während schwere VLMs für Live-Szenarien oft zu langsam bleiben. [web:363][web:365]

## Begriffsdefinitionen

### Erster Schluck

Ein „erster Schluck“ liegt fachlich vor, wenn ein Getränkebehälter mit Bierbezug erstmals in einem Video-Clip plausibel an den Mund einer erkennbaren Person geführt wird und eine Trinkhandlung stattfindet. Die genaue harte Definition wird außerhalb des Ollama-Modells durch Regeln konkretisiert; das Modell liefert dafür semantische Evidenz.

### Valider Drink Event

Ein valider Drink Event ist ein vom Modell erkannter Vorgang, der mit ausreichender Sicherheit auf einen realen Trinkvorgang hindeutet und nicht bloß auf Posieren, Anstoßen oder Halten eines Glases.

### Bierobjekt

Bierobjekt ist ein im Video sichtbares Glas, eine Flasche oder eine Dose, das beziehungsweise die als möglicher Träger eines Bierkonsums dient. Ob es sich tatsächlich um Bier handelt, kann semantisch über das Modell nur eingeschränkt plausibilisiert werden und wird daher als Evidenzsignal betrachtet, nicht als absoluter Beweis.

## Stakeholder

| Stakeholder | Interesse |
|---|---|
| Produktverantwortliche | Einfache, lokal funktionierende Erkennung mit akzeptabler Robustheit |
| Mobile-Entwicklung | Klare lokale Schnittstellen, begrenzte Laufzeit- und Speicheranforderungen |
| ML/AI-Entwicklung | Präzise Aufgabenabgrenzung für Modellwahl, Prompting und Evaluierung |
| Datenschutz/Compliance | Keine Cloud-Übertragung von Bild- und Videodaten |
| Copilot-Nutzungskontext | Klare Spezifikation, damit Microsoft Copilot Entwicklungsaufgaben strukturiert ableiten kann |

## Randbedingungen

Die Softwarekomponente muss die folgenden Randbedingungen einhalten:

- Verarbeitung **ohne Cloud-Upload**.
- Ausführung auf lokaler Infrastruktur, bevorzugt lokal auf Benutzergerät oder eng gekoppelter lokaler Laufzeitumgebung.
- Nutzung eines **Ollama-kompatiblen** lokalen Modells.
- Wartezeiten von bis zu mehreren Minuten sind akzeptabel.
- Robuste Erkennung ist wichtiger als Echtzeitverhalten.
- Ergebnis muss maschinenlesbar und reproduzierbar sein.

Sustained On-Device-LLM/VLM-Inferenz kann zu Thermal Throttling und Leistungseinbrüchen führen; daher muss die Komponente asynchron und ressourcenschonend arbeiten und darf nicht als permanenter Echtzeitprozess konzipiert werden. [web:358][web:305]

## Funktionale Anforderungen

### FA-1 Eingangsdaten

Die Komponente muss einen lokal gespeicherten Video-Clip als Eingabe verarbeiten können. Unterstützt werden sollen kurze Clips, die typischerweise 5 bis 15 Sekunden lang sind und einen Trinkvorgang oder den Versuch eines Trinkvorgangs zeigen.

### FA-2 Vorverarbeitung

Die Komponente muss eine vorgelagerte Auswahl von Schlüsselbildern oder Teilsequenzen unterstützen. Da die Kosten bei VLMs stark von der visuellen Verarbeitung und Token-Generierung abhängen, soll nicht zwingend das vollständige Rohvideo Frame für Frame an das Modell übergeben werden. [web:353][web:364]

### FA-3 Ollama-Modellaufruf

Die Komponente muss ein lokales Ollama-Modell mit multimodaler Fähigkeit aufrufen können. Das Modell muss Bild- oder Frame-Eingaben verarbeiten und eine strukturierte Antwort erzeugen können. Mobile und edge-orientierte VLMs wie MiniCPM-V werden als geeignete Klassen betrachtet. [web:363][web:365]

### FA-4 Strukturierte Ausgabe

Die Komponente muss mindestens folgende Felder liefern:

| Feld | Beschreibung |
|---|---|
| `first_sip_detected` | true/false |
| `confidence` | Wert von 0.0 bis 1.0 |
| `face_visible` | true/false |
| `drinking_object_visible` | true/false |
| `mouth_contact_likely` | true/false |
| `beer_likely` | true/false/unknown |
| `reason_short` | kurze textliche Begründung |
| `model_name` | verwendetes lokales Modell |
| `analysis_version` | Version des Analyse-Prompts / Schemas |

### FA-5 Deterministische Antwortform

Die Komponente muss das Modell über ein enges Prompt- und Antwortschema betreiben, bevorzugt JSON-only. Offene narrative Ausgaben sind zu vermeiden, da sie die technische Weiterverarbeitung erschweren und die Variabilität erhöhen. [web:353][web:364]

### FA-6 Fehlerbehandlung

Die Komponente muss unvollständige oder unbrauchbare Clips erkennen können, z. B. wenn kein Gesicht sichtbar ist, das Getränk nicht im Bild vorkommt oder die Bildqualität unzureichend ist. In solchen Fällen muss ein definierter Fehler- oder Ablehnungsstatus zurückgegeben werden.

### FA-7 Asynchroner Betrieb

Die Komponente muss Hintergrundverarbeitung unterstützen. Nutzer dürfen den Clip aufnehmen, speichern und die Analyse im Anschluss anstoßen. Eine synchrone Live-Auswertung ist nicht erforderlich.

### FA-8 Erweiterbarkeit

Die Komponente muss so entworfen werden, dass später zusätzliche Prüfsignale integriert werden können, z. B. externe CV-Messwerte für Füllstand, Schaum oder Objektpersistenz. Der modulare Ansatz wird durch bestehende Drinking-Detection-Praxis gestützt, die spezialisierte Teilmodelle kombiniert. [web:66]

## Nichtfunktionale Anforderungen

### NFA-1 Datenschutz

Bild- und Videodaten dürfen die lokale Umgebung nicht verlassen. Die Komponente muss offline oder lokalnetzgebunden ohne Cloud-Analyse nutzbar sein.

### NFA-2 Robustheit

Die Komponente soll gegenüber folgenden Variationen robust sein:

- unterschiedliche Lichtverhältnisse,
- unterschiedliche Kamerawinkel,
- verschiedene Bierbehälter,
- kurze Verdeckungen,
- unterschiedliche Gesichter und Trinkhaltungen.

### NFA-3 Nachvollziehbarkeit

Die Entscheidung muss durch strukturierte Felder und kurze Begründungen nachvollziehbar sein. Das ist besonders wichtig, weil VLMs probabilistisch arbeiten und ihre semantische Einschätzung nachgelagert regelbasiert bewertet werden soll. [web:365]

### NFA-4 Performance

Die Komponente muss nicht echtzeitfähig sein, soll aber innerhalb eines für Nutzer akzeptablen Hintergrundfensters arbeiten. Mehrere zehn Sekunden bis wenige Minuten gelten als zulässig. Forschung zu mobilen VLMs zeigt, dass diese Größenordnung deutlich realistischer ist als harte Echtzeit. [web:353][web:356]

### NFA-5 Ressourcenverbrauch

Die Komponente soll so ausgelegt sein, dass der Ressourcenverbrauch begrenzt bleibt. Schwere Dauerlasten sind zu vermeiden, da lokale LLM/VLM-Inferenz auf mobilen Geräten und Edge-Systemen thermische Probleme verursachen kann. [web:358][web:305]

## Qualitätsanforderungen

### Erkennungsqualität

Die Komponente soll auf einem definierten Testdatensatz eine hohe Präzision für `first_sip_detected = true` erreichen. In diesem Use Case ist eine hohe Precision wichtiger als maximale Recall-Werte, da Fehlpunkte in einer späteren Challenge-Logik schädlicher sind als einzelne nicht erkannte echte Schlücke. Precision, Recall und Confusion Matrix sind Standardmetriken für die Bewertung solcher Klassifikationsentscheidungen. [web:334][web:337]

### Testbarkeit

Die Komponente muss auf Basis gelabelter Testclips bewertbar sein. Sie soll reproduzierbare Ergebnisse bei identischem Modell, identischem Prompt und identischer Frame-Auswahl liefern.

### Wartbarkeit

Prompt-Versionen, Modellauswahl und Ausgabe-Schema müssen versionierbar sein. Änderungen an Prompt oder Schema dürfen nicht implizit erfolgen.

## Abgrenzung Modell vs. Regelwerk

Der Ollama-Schritt soll primär **semantisch bewerten**, ob ein erster Schluck wahrscheinlich vorliegt. Nicht im Modell, sondern außerhalb der Komponente oder in einer nachgelagerten Prüfkomponente sollen insbesondere folgende Regeln bewertet werden:

- Objekt-Lock über mehrere Events,
- Refill-Erkennung,
- Monotonie des Füllstands,
- Mehrpersonen-Konflikte,
- Session-übergreifende Anti-Cheat-Prüfung.

Diese Trennung ist bewusst gewählt, weil strukturierte Mess- und Regelprobleme von klassischen CV-/State-Machine-Komponenten oft robuster gelöst werden als von einem generativen Modell. [web:66][web:365]

## Lösungsansatz

### Zielarchitektur

Der bevorzugte Lösungsansatz ist eine **Hybridarchitektur**:

1. Video-Clip lokal speichern.
2. Schlüsselbilder oder relevante Frames extrahieren.
3. Frames und enger Bewertungs-Prompt an ein lokales Ollama-VLM übergeben.
4. Strukturierte JSON-Antwort erzeugen.
5. Antwort an nachgelagerte Rule Engine übergeben.

Dieser Ansatz nutzt die semantische Stärke lokaler VLMs, reduziert aber die Schwächen offener generativer Ausgaben. [web:353][web:363][web:365]

### Prompting-Anforderungen

Der Prompt muss kurz, eindeutig und restriktiv sein. Die Modellantwort darf ausschließlich strukturierte Felder enthalten. Beispiele, Debug-Freundlichkeit und feste Entscheidungsdimensionen sind vorzusehen. Offene frei formulierte Antworten sind auszuschließen.

### Modellklassen

Bevorzugt zu evaluieren sind kleine bis mittlere lokale multimodale Modelle, die mit Ollama oder in einem Ollama-kompatiblen Workflow betrieben werden können. Effiziente mobile VLMs sind schweren, generischen Vision-LLMs vorzuziehen. [web:363][web:365]

## Anwendungsfälle

### UC-1 Positiver Standardfall

Ein Nutzer nimmt einen kurzen Clip auf, in dem sein Gesicht sichtbar ist, ein Bierglas im Vordergrund erkennbar ist und ein klarer Schluck stattfindet. Die Komponente soll `first_sip_detected = true` zurückgeben.

### UC-2 Posieren ohne Schluck

Ein Nutzer hält ein Bier nur vor die Kamera. Gesicht und Glas sind sichtbar, aber kein plausibler Schluck findet statt. Die Komponente soll `first_sip_detected = false` zurückgeben.

### UC-3 Ungültiger Clip

Im Clip ist kein Gesicht oder kein Getränk klar sichtbar. Die Komponente soll einen ungültigen bzw. nicht ausreichend auswertbaren Zustand liefern.

### UC-4 Unsicherer Fall

Beleuchtung oder Verdeckung verhindern eine klare Entscheidung. Die Komponente soll einen niedrigen Confidence-Wert liefern und keine harte Positiventscheidung erzwingen.

## Akzeptanzkriterien

Die Komponente gilt als fachlich abnahmefähig, wenn mindestens folgende Kriterien erfüllt sind:

- Lokale Auswertung ohne Cloud ist technisch nachgewiesen.
- Ein Ollama-kompatibles multimodales Modell ist integriert.
- Die Komponente gibt strukturierte JSON-Ergebnisse aus.
- Positiv- und Negativfälle lassen sich mit Testclips reproduzierbar unterscheiden.
- Unsichere Fälle werden mit geringer Confidence oder Ablehnungsstatus behandelt.
- Prompt, Ausgabeformat und Modellversion sind dokumentiert.

## Testanforderungen

Für die Abnahme ist ein Testset mit mindestens folgenden Szenarien vorzusehen:

| Szenario | Erwartetes Ergebnis |
|---|---|
| echter erster Schluck | positiv |
| Glas nur halten | negativ |
| Anstoßen ohne Trinken | negativ |
| Gesicht teilweise verdeckt | je nach Evidenz negativ oder unsicher |
| Getränk teilweise verdeckt | je nach Evidenz negativ oder unsicher |
| mehrere Behälter im Bild | nur bei klarem Schluck positiv |
| verschiedene Lichtverhältnisse | stabil oder kontrolliert unsicher |

Zusätzlich sind Precision, Recall und Fehlerarten getrennt auszuwerten. [web:334][web:337]

## Liefergegenstände des Entwicklungsschritts

Der Schritt „Ollama-Modell entwickeln“ umfasst mindestens folgende Deliverables:

- technische Evaluierung geeigneter lokaler multimodaler Modelle,
- definierte Eingabeschnittstelle für Video bzw. Frames,
- implementierter Ollama-Aufruf,
- dokumentierter Analyse-Prompt,
- dokumentiertes JSON-Schema der Antwort,
- Tests mit Positiv-/Negativbeispielen,
- kurze Bewertung der Modellgüte und Grenzen.

## Risiken

| Risiko | Beschreibung | Auswirkung |
|---|---|---|
| Modellhalluzination | Modell liefert plausible, aber falsche semantische Aussagen | falsche Event-Erkennung |
| große Latenz | lokales Modell ist auf Zielgerät langsamer als erwartet | schlechte Nutzererfahrung |
| thermische Drosselung | wiederholte Inferenz verlangsamt Gerät | inkonsistente Laufzeiten |
| geringe Deterministik | gleiches Material führt zu leicht abweichenden Antworten | schwierigere Automatisierung |
| schwache Sichtbarkeit | Clip enthält zu wenig visuelle Evidenz | hohe Unsicherheit |

## Annahmen

Dieses Lastenheft basiert auf folgenden Annahmen:

- Nutzer akzeptieren asynchrone Analyse mit Wartezeit.
- Lokale Ausführung hat höhere Priorität als maximale Geschwindigkeit.
- Ein enger Aufgabenfokus „erster Schluck ja/nein“ ist sinnvoller als ein allgemeines Videoverständnissystem.
- Zusätzliche harte Regeln werden später außerhalb des Ollama-Modells ergänzt.

## Offene Punkte für das spätere Pflichtenheft

Folgende Punkte sind im nächsten Schritt zu konkretisieren:

- Zielplattformen: iOS, Android, Desktop oder Hybrid.
- Konkretes Ollama-Modell bzw. Modellkandidaten.
- Strategie zur Frame-Selektion.
- Exaktes Prompt-Template.
- JSON-Schema und Fehlermodell.
- Confidence-Schwellenwerte.
- Integration externer CV-Signale.
- Benchmark- und Testdatensatz.

## Ergebnis

Für den aktuellen Scope ist der bevorzugte Zielzustand eine lokale, asynchron arbeitende Softwarekomponente, die mit einem Ollama-kompatiblen multimodalen Modell kurze Video-Clips semantisch bewertet und strukturiert zurückmeldet, ob ein erster Schluck wahrscheinlich stattgefunden hat. Aufgrund der akzeptierten Wartezeit ist dieser Ansatz praktikabler als Echtzeit-Vision; gleichzeitig bleibt eine strikte Trennung zwischen semantischer Modellbewertung und nachgelagerten harten Regeln notwendig, um Robustheit und Anti-Cheat-Fähigkeit später sauber auszubauen. [web:353][web:358][web:365]
