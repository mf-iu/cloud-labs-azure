# Cloud-Übungen: Microsoft Azure

Skripte für den praktischen Teil des Kurses „Cloud Computing – Konzepte und Praxis für die Softwareentwicklung“ bei Microsoft Azure. Zu jedem Termin gibt es einen Ordner mit Anleitung und Skripten. Die Gegenstücke für die anderen Anbieter liegen in `cloud-labs-aws` und `cloud-labs-gcp`; Aufbau und Ordnernamen sind dort gleich.

Jeder Teilnehmer arbeitet in der ersten Kurshälfte (Termine 1–7) mit einem Anbieter und wechselt nach der Zwischenpräsentation zu einem anderen (Termine 8–12). Wer Azure erst ab Termin 8 nutzt, richtet das Konto mit `t01-grundlagen` ein und arbeitet dann mit `t08-iac` weiter.

## Voraussetzungen

- Der Dev Container dieses Repositorys (siehe unten) – er enthält alle Werkzeuge der Übungen. Ohne Dev Container: eine Linux-Shell (WSL 2) mit Azure CLI, Docker, Python 3.12, uv, curl, dig, openssl; ab Termin 8 OpenTofu ab Version 1.10, für Termin 9 die Azure Functions Core Tools (`func`). `psql` ist optional, sonst starten die Skripte es als Container.
- Ein kostenloses Azure-Konto – Einrichtung in [t01-grundlagen](t01-grundlagen/README.md)
- Ein eigener Fork von [PlaceFinder](https://github.com/mf-iu/placefinder) auf GitHub; beim Forken „Copy the master branch only“ abwählen, sonst fehlen die Tags der Ausbaustufen (`t01`, `t02` …). Die Skripte erwarten die Container-Images unter `ghcr.io/<github-user>/placefinder:<tag>`, also z. B. `:t03` für den Stand von Termin 3. Azure lädt die Images direkt von ghcr.io; die Pakete müssen dazu **öffentlich** sein (auf GitHub: *Packages* → *placefinder* → *Package settings* → *Change visibility*).

## Arbeitsumgebung: Dev Container

Der Ordner `.devcontainer/` beschreibt einen Container mit allen Werkzeugen der Übungen: Python 3.12 mit uv, eine eigene Docker Engine im Container (Docker in Docker), kubectl, Helm, k3d, OpenTofu, psql, osm2pgsql, pmtiles, die GitHub CLI und die Azure CLI und die Azure Functions Core Tools. `tools/check-tools.sh` zeigt die installierten Versionen.

**Warum:** Alle Teilnehmer arbeiten mit denselben Werkzeugen in denselben Versionen. Auf dem Notebook sind nur WSL 2, Docker Engine und VS Code nötig; alles andere steckt im Container. Ein Neubau stellt jederzeit den Ausgangszustand her.

**Starten** (im Ubuntu-Terminal von WSL):

```bash
mkdir -p ~/kurs && cd ~/kurs
git clone https://github.com/mf-iu/cloud-labs-azure.git
git clone https://github.com/<github-user>/placefinder.git   # eigener Fork
code cloud-labs-azure
```

VS Code öffnet den Ordner in WSL und meldet „Folder contains a Dev Container configuration file“: **Reopen in Container** wählen. Ohne Meldung: F1 → „Dev Containers: Reopen in Container“. Der erste Start baut das Image und dauert 10–15 Minuten, danach startet der Container in Sekunden. Unten links zeigt VS Code dann „Dev Container: Cloud-Kurs: …“; jedes Terminal in VS Code läuft jetzt im Container.

**Was erhalten bleibt:** Der Container sieht den ganzen Ordner `~/kurs` unter `/workspaces`, PlaceFinder also unter `/workspaces/placefinder`. SSH-Schlüssel (`~/.ssh`) und die Azure-Anmeldung (`~/.azure`) liegen in WSL und überstehen einen Neubau. Docker-Images und k3d-Cluster liegen in einem Volume des Containers; `docker login` (Docker Hub) ist nach einem Neubau zu wiederholen.

**Aktualisieren:** Ändert sich `.devcontainer/`, in VS Code F1 → „Dev Containers: Rebuild Container“.

### Arbeiten im Terminal des Containers

Zeigt VS Code unten links „Dev Container: Cloud-Kurs: …“, läuft jedes Terminal dieses Fensters im Container.

- **Terminal öffnen:** Strg+Ö (deutsche Tastatur; auf einer US-Tastatur Strg+Backtick) oder *Terminal* → *New Terminal*. Die Eingabeaufforderung zeigt den Benutzer `vscode` und einen Pfad unter `/workspaces`, z. B. `vscode ➜ /workspaces/cloud-labs-azure (master) $`. Nach dem ersten Bau zeigt ein Terminal die Ausgabe von `tools/check-tools.sh`; mit einer Taste schließen und ein neues öffnen.
- **Ordner:** `/workspaces/cloud-labs-azure` (Startordner jedes Terminals) und `/workspaces/placefinder`. Es sind dieselben Dateien wie in WSL unter `~/kurs`; Änderungen sind auf beiden Seiten sofort sichtbar.
- **Erste Befehle:**

  ```bash
  tools/check-tools.sh    # alle Werkzeuge vorhanden?
  cd t01-grundlagen       # Ordner der Übung von Termin 1
  az login --use-device-code
  ```

- **Mehrere Terminals:** mit **+** im Terminalbereich ein weiteres öffnen, mit Strg+Umschalt+5 nebeneinander teilen – praktisch für PlaceFinder: `uv run fastapi dev …` im einen, `curl` im anderen Terminal. Ein laufendes Programm beendet Strg+C, ein Terminal `exit` oder das Papierkorb-Symbol.
- **Ports:** Ports wie 8000 leitet VS Code automatisch weiter (Reiter *Ports* neben *Terminal*); `http://localhost:8000` funktioniert dann auch im Browser unter Windows.
- **Container oder WSL:** Im Container stehen alle Kurswerkzeuge zur Verfügung, aber nicht die eigene Shell-Konfiguration aus WSL. Befehle außerhalb des Containers laufen im Ubuntu-Fenster, z. B. `git clone` vor dem ersten Start und `ssh-keygen` für den SSH-Schlüssel (siehe [t01-grundlagen](t01-grundlagen/README.md#ssh-schlüssel-für-die-vms)); `wsl --shutdown` in der PowerShell. Zeigt VS Code unten links nur „WSL: Ubuntu-24.04“, ist der Ordner ohne Container geöffnet: F1 → „Dev Containers: Reopen in Container“.
- **Nach einem Neustart:** VS Code öffnet den Ordner meist wieder im Container. Sonst *File* → *Open Recent* und den Eintrag mit „[Dev Container]“ wählen. Der Container startet in Sekunden; neu gebaut wird nur, wenn sich `.devcontainer/` geändert hat.

## Einrichtung

Im Terminal des Dev Containers:

```bash
cp config.example.env config.env   # persönliche Einstellungen eintragen
az login --use-device-code         # Anmeldung, siehe t01-grundlagen
t01-grundlagen/check-cli.sh        # prüft CLI, Anmeldung und Abonnement
t01-grundlagen/register-providers.sh
```

`config.env` und der Ordner `.state/` gehören nur auf den eigenen Rechner und sind in `.gitignore` eingetragen. In `.state/` merken sich die Skripte Namen und Adressen der angelegten Ressourcen, außerdem Downloads und Zugangsdaten der Übungsdatenbank.

## Übersicht

| Termin | Ordner | Inhalt | Werkzeug |
|---|---|---|---|
| 1 | [t01-grundlagen](t01-grundlagen/README.md) | Konto absichern, CLI-Anmeldung, Ressourcenanbieter, Budget-Alarm | Azure CLI |
| 2 | [t02-vm](t02-vm/README.md) | PlaceFinder v0 per cloud-init auf einer Azure-VM (IaaS) | Azure CLI |
| 3 | [t03-container](t03-container/README.md) | Betrieb mit Azure Container Apps (Serverless Container) | Azure CLI |
| 4 | [t04-netzwerk](t04-netzwerk/README.md) | Virtual Network mit öffentlichem und privaten Subnetzen, NSGs, Diagnose | Azure CLI |
| 5 | [t05-rest-api](t05-rest-api/README.md) | Neue API-Version als Revision ausrollen und testen, API Management | Azure CLI |
| 6 | [t06-datenbank](t06-datenbank/README.md) | Azure Database for PostgreSQL mit PostGIS, Import von cities15000, räumliche Abfragen | Azure CLI, psql |
| 7 | [t07-objektspeicher](t07-objektspeicher/README.md) | Blob Storage, SAS-Token, Range Requests, CORS, Lebenszyklusregeln | Azure CLI |
| 8 | [t08-iac](t08-iac/README.md) | Infrastruktur der Zwischenpräsentation als OpenTofu-Code, Remote State, GitHub Actions ohne Secrets (OIDC) | OpenTofu |
| 9 | [t09-serverless](t09-serverless/README.md) | Täglicher GeoNames-Abgleich als Azure Function (Flex Consumption, Timer-Trigger) | OpenTofu, Core Tools |
| 10 | [t10-datenanalyse](t10-datenanalyse/README.md) | GeoParquet im Data Lake, Abfragen mit DuckDB, Overture Maps | OpenTofu, DuckDB |
| 11 | [t11-ml](t11-ml/README.md) | Modell-Endpunkt `/estimate`, MLflow-Artefakte im Blob Storage | OpenTofu |

Termin 12 (Abschluss) hat keinen eigenen Ordner; das Abschlussprojekt baut auf `t08-iac` auf.

## Ablauf jeder Übung

1. Ressourcen anlegen: `create-….sh`, `deploy.sh` bzw. `tools/tofu.sh <ordner> apply`
2. Ausprobieren: Testbefehle aus der Anleitung des Termins
3. **Aufräumen:** `destroy-….sh` bzw. `tools/tofu.sh <ordner> destroy`
4. Kontrolle: `tools/find-leftovers.sh` listet übrig gebliebene Ressourcen auf

Jede Übung legt eine eigene **Ressourcengruppe** `rg-<prefix>-<owner>-<termin>` an, z. B. `rg-pf-mf-t02`. Das Aufräumen löscht die ganze Gruppe mit allem, was darin liegt. Alle Gruppen tragen die Tags `course=cloud-computing` und `lab=<termin>`. Die Skripte fragen vor dem Löschen nach; mit `ASSUME_YES=1` vor dem Befehl entfällt die Rückfrage.

**Ab Termin 8 mit OpenTofu:** `t08-iac/bootstrap-state.sh` legt einmalig das Speicherkonto für den Remote State an. Danach läuft jede Konfiguration über `tools/tofu.sh`, das den Backend-Zugang, das Abonnement und die gemeinsamen Variablen aus `config.env` setzt:

```bash
tools/tofu.sh t08-iac/infra plan
tools/tofu.sh t08-iac/infra apply
tools/tofu.sh t08-iac/infra destroy
```

## Kostenregeln

- Gleich am ersten Tag den Budget-Alarm einrichten (`t01-grundlagen/create-budget.sh`).
- Nach jeder Übung alles abbauen. Teuer im Dauerbetrieb sind vor allem NAT-Gateways, öffentliche IP-Adressen, PostgreSQL-Server außerhalb der kostenlosen Stunden, API Management in festen Tarifen und Azure Container Registry.
- **Die Testphase dauert nur 30 Tage.** Danach läuft das Konto nur nach Umstellung auf nutzungsbasierte Bezahlung (Pay-as-you-go) weiter; die 12-monatigen kostenlosen Dienste (z. B. VM `B1s`, PostgreSQL `B1ms`, je 750 Stunden im Monat) gelten weiter, es gibt aber keine harte Ausgabengrenze mehr, nur den Budget-Alarm.
- Preisangaben in den Anleitungen sind Richtwerte (Stand Oktober 2026) und dienen nur der Orientierung.

## Daten und Lizenzen

- GeoNames (`cities15000`, tägliche Änderungsdateien): CC BY 4.0, Namensnennung „GeoNames“
- OpenStreetMap und Overture Maps: ODbL bzw. CDLA Permissive 2.0, je nach Thema
- Geodaten werden nie eingecheckt, sondern von den Skripten geladen.

## Konventionen

Anleitungen auf Deutsch, Skripte, Kommentare und Commit-Messages auf Englisch. Die Shell-Skripte sind mit ShellCheck geprüft (`shellcheck */*.sh`), die OpenTofu-Dateien mit `tofu fmt`.
