# T09 – Täglicher GeoNames-Abgleich als Azure Function

**Ziel:** Eine Azure Function lädt jeden Morgen die Änderungs- und Löschdateien des Vortags von GeoNames, filtert sie auf die Orte von `cities15000` und legt sie im Blob Storage ab. Ist `database_url` gesetzt, spielt sie die Änderungen zusätzlich in die Tabelle `places` ein. Ein Timer-Trigger im Code startet sie täglich um 5:30 Uhr UTC; ein HTTP-Trigger dient zum Testen.

**Kosten:** Flex Consumption mit kostenlosem Kontingent (Ausführungen und GB-Sekunden pro Monat); Application Insights im Rahmen der ersten 5 GB Log-Daten pro Monat. Ein Lauf dauert wenige Sekunden.

## Aufbau

| Datei | Inhalt |
|---|---|
| `function/geonames_sync.py` | anbieterneutraler Kern: Download, Filter, Speichern, optional Datenbank (identisch in allen drei Repositories) |
| `function/function_app.py` | Timer- und HTTP-Trigger (Python-Programmiermodell v2), schreibt mit der Managed Identity |
| `function/requirements.txt`, `host.json` | Abhängigkeiten und Host-Konfiguration |
| `infra/main.tf` | Speicherkonto, Log Analytics, Application Insights, Flex-Consumption-Plan, Function App, Rollen |
| `deploy.sh` | `tofu apply` und Veröffentlichung des Codes mit `func azure functionapp publish` |
| `invoke.sh` | HTTP-Trigger mit Function Key aufrufen |

Flex Consumption ist nicht in jeder Region verfügbar. Prüfen mit `az functionapp list-flexconsumption-locations --output table`; notfalls `AZURE_LOCATION` in `config.env` ändern (z. B. `swedencentral`).

## Lokal testen

```bash
cd function
python3 geonames_sync.py --date 2026-10-01 --out ../out
```

Ohne Cloud: Die Dateien landen unter `out/geonames/changes/<datum>/`. Die ganze Function läuft lokal mit den Core Tools: Azurite als Speicher-Emulator starten (`azurite --silent &`), `local.settings.example.json` nach `local.settings.json` kopieren, `DATA_ACCOUNT_URL` aus `tofu output` eintragen, dann `func start` und `curl --request POST "http://localhost:7071/api/sync?date=2026-10-01"`. Geschrieben wird dabei mit dem eigenen `az login` in das echte Speicherkonto.

## Ausrollen

```bash
./deploy.sh
./invoke.sh                 # gestern
./invoke.sh 2026-10-01      # bestimmter Tag
```

Mit Datenbank (z. B. aus Termin 6; die Datenbank aus `t08-iac` liegt im privaten Netz und ist von außen nicht erreichbar):

```bash
./deploy.sh -var "database_url=postgresql://…?sslmode=require"
```

Damit die Function die Datenbank erreicht, muss deren Firewall den Zugriff erlauben (*Networking* → *Allow public access from any Azure service* oder VNet-Integration der Function App).

## Prüfen

- Ein zweiter Aufruf für denselben Tag ändert nichts (Idempotenz): gleiche Dateien, Upsert statt doppelter Zeilen.
- Im Portal: Function App → *Monitoring* → *Invocations* bzw. Application Insights → *Logs*
- Kaltstart: Die erste Ausführung nach einer Pause dauert deutlich länger.

## Aufräumen

```bash
cd ..
tools/tofu.sh t09-serverless/infra destroy
```

## Optional: ereignisgesteuert

Eine zweite Function könnte auf neue Blobs reagieren (Blob-Trigger mit Event Grid als Quelle, `@app.blob_trigger(..., source="EventGrid")`), etwa einen neuen OSM-Auszug unter `osm/` zu POIs verarbeiten. Achtung bei Ereignissen auf demselben Container, in den die Function schreibt: Präfixe trennen, sonst entsteht eine Endlosschleife.

## Fragen zum Weiterdenken

- Was passiert, wenn GeoNames die Datei um 5:30 Uhr UTC noch nicht veröffentlicht hat? Wie helfen Retries?
- Warum muss die Function idempotent sein, obwohl sie nur einmal am Tag läuft?
- Warum schreibt die Function mit ihrer Managed Identity statt mit einem Kontoschlüssel?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Function | Lambda | Azure Functions (Flex Consumption) | Cloud Run functions |
| Zeitsteuerung | EventBridge Scheduler | Timer-Trigger im Code | Cloud Scheduler |
| Lokale Entwicklung | SAM CLI | Functions Core Tools, Azurite | Functions Framework |
