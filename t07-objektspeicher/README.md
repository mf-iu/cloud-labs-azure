# T07 – Object Storage mit Azure Blob Storage

**Ziel:** Ein Speicherkonto mit privatem Container für Rohdaten und Kartenkacheln, zeitlich begrenzter Zugriff über SAS-Token (Shared Access Signature), Range Requests (Grundlage von PMTiles), CORS für den Abruf aus dem Browser und eine Lebenszyklusregel.

**Kosten:** Bei wenigen hundert Megabyte praktisch null; Blob Storage gehört in den ersten 12 Monaten in kleinem Umfang zu den kostenlosen Diensten.

## Schritte

```bash
./create-storage.sh                # Speicherkonto, Container "data", CORS, Lebenszyklus
./sas.sh                           # SAS-URL, Test mit und ohne Token, Range Request
./upload.sh erfurt.pmtiles       # eigene Datei nach tiles/
./sas.sh tiles/erfurt.pmtiles
```

Eine PMTiles-Datei für eine Region lässt sich mit dem `pmtiles`-Werkzeug aus dem Dev Container aus dem täglichen Protomaps-Build schneiden, ohne den ganzen Planeten zu laden:

```bash
pmtiles extract https://build.protomaps.com/<YYYYMMDD>.pmtiles erfurt.pmtiles \
  --bbox=10.90,50.90,11.20,51.10 --maxzoom=14
```

Das aktuelle Datum steht unter <https://maps.protomaps.com/builds>.

## Was die Skripte einstellen

- Speicherkonto `Standard_LRS` (drei Kopien in einem Rechenzentrum), mindestens TLS 1.2, keine öffentlichen Blobs. Daten im Ruhezustand sind immer verschlüsselt.
- CORS: GET und HEAD von jeder Herkunft, Header `Range` erlaubt, `ETag` und `Content-Range` für den Browser sichtbar – nötig für MapLibre GL JS mit PMTiles.
- `lifecycle.json`: Blobs unter `data/raw/` werden 30 Tage nach der letzten Änderung gelöscht.
- Die Datenbefehle melden sich mit dem Kontoschlüssel an (`AZURE_STORAGE_KEY`). Besser ist die Anmeldung mit Entra ID und der Rolle *Storage Blob Data Contributor*; so arbeiten die Termine 9–11.

## Prüfen

Die Ausgabe von `sas.sh` zeigt:

- ohne Token: Fehler – der Container ist privat,
- mit Token und `Range: bytes=0-99`: `206 Partial Content` mit `Content-Range`.

## Aufräumen

```bash
./destroy-storage.sh
```

## Cache (Theorie)

Ein verwalteter Cache (Azure Managed Redis) kostet auch im kleinsten Ausbau jede Stunde Geld. Die Übung zum Caching läuft daher lokal mit Valkey im Dev Container.

## Anbieterwechsel

Nach Termin 7 wechselt jeder Teilnehmer den Anbieter. Wer neu zu Azure kommt, arbeitet [t01-grundlagen](../t01-grundlagen/README.md) durch und liest die Zwischenpräsentation des Vorgängers. Wer Azure verlässt, prüft mit `../tools/find-leftovers.sh`, dass nichts mehr läuft.

## Fragen zum Weiterdenken

- Welche Arten von SAS-Token gibt es (Konto, Dienst, User Delegation), und welche ist am sichersten?
- Welche Zugriffsebene (Hot, Cool, Cold, Archive) passt zu selten gelesenen Rohdaten, und was kostet dann der Abruf?
- Wie würde Azure Front Door als CDN vor dem Speicherkonto die Kosten für viele Kartenaufrufe senken?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Object Storage | S3 | Blob Storage | Cloud Storage |
| Zeitlich begrenzter Zugriff | Pre-Signed URL | SAS-Token | Signed URL |
| Cache | ElastiCache | Azure Managed Redis | Memorystore |
