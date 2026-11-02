# 05 – Object Storage und verwaltete Datenbank

In Termin 7 kommen die Rohdaten von GeoNames und die Kacheldatei aus [cloud-labs-local/07-cache-and-storage](https://github.com/mf-iu/cloud-labs-local/tree/master/07-cache-and-storage) in den privaten Object Storage von Azure; die Karte von PlaceFinder liest ihre Kacheln von dort, mit zeitlich begrenztem Zugriff, Range Requests und CORS. Die verwaltete PostgreSQL-Datenbank aus Termin 6 ist **Zusatz** – freiwillig und ohne Folgen für spätere Termine; PostGIS lokal steht in [cloud-labs-local/06-postgis](https://github.com/mf-iu/cloud-labs-local/tree/master/06-postgis).

| Skript | Aufgabe |
|---|---|
| `create-storage.sh`, `destroy-storage.sh` | ein Speicherkonto mit privatem Container `data` beim Anbieter, mit CORS und Lebenszyklusregel; Rohdaten hochladen; alles wieder löschen |
| `upload.sh` | Datei hochladen: `.pmtiles` nach `tiles/`, alles andere nach `raw/` |
| `sas.sh` | SAS-URL (Shared Access Signature) für eine Stunde, getestet ohne Signatur, mit Range Request und CORS; für PMTiles die Adresse der Karte |
| `create-db.sh`, `destroy-db.sh` | PostgreSQL 18 beim Anbieter anlegen, nur von der eigenen IP-Adresse erreichbar, und wieder löschen |
| `backups.sh` | automatische Backups und das Zeitfenster für Point-in-Time Recovery anzeigen; ändert nichts |
| `with-db.sh` | ein Skript aus `cloud-labs-local/06-postgis` mit dieser Datenbank ausführen, z. B. `./with-db.sh load-cities.sh` |

**Kosten:** Object Storage: Blob Storage (LRS, Hot) gehört in den ersten 12 Monaten mit 5 GB zu den kostenlosen Diensten; danach ca. 0,02 USD je GB und Monat. Datenbank: `Standard_B1ms` mit 32 GB Speicher gehört in den ersten 12 Monaten zu den kostenlosen Diensten (750 Stunden im Monat). Nach der Übung trotzdem löschen oder anhalten (`az postgres flexible-server stop`, nach sieben Tagen startet Azure den Server automatisch wieder).

## Object Storage mit Kacheln (Termin 7)

Voraussetzung ist die Kacheldatei `erfurt.pmtiles` aus `cloud-labs-local/07-cache-and-storage/make-tiles.sh`; sie liegt in `cloud-labs-local/.state/data/`.

```bash
cd /workspaces/cloud-labs-azure/05-storage
./create-storage.sh                                            # Speicherkonto, Container data, CORS, Lebenszyklus, cities15000
./upload.sh ../../cloud-labs-local/.state/data/erfurt.pmtiles  # nach tiles/
./sas.sh tiles/erfurt.pmtiles                                  # Tests und Adresse der Karte
./sas.sh                                                       # dasselbe für die Rohdaten in raw/geonames/
./destroy-storage.sh                                           # danach alles löschen
```

Die Adresse der Karte, die `sas.sh` ausgibt, im Browser öffnen, während PlaceFinder und der Webserver für `frontend/` laufen ([cloud-labs-local/07-cache-and-storage](https://github.com/mf-iu/cloud-labs-local/tree/master/07-cache-and-storage)). Die Karte lädt dann ihre Kacheln direkt aus dem Object Storage des Anbieters – ohne eigenen Server dafür.

**Was die Skripte einstellen:**

- Speicherkonto `Standard_LRS` (drei Kopien in einem Rechenzentrum), mindestens TLS 1.2, keine öffentlichen Blobs. Daten im Ruhezustand sind immer verschlüsselt.
- CORS: GET und HEAD von `http://localhost:5173`, Header `Range` erlaubt, `ETag`, `Content-Length` und `Content-Range` für den Browser sichtbar.
- `lifecycle.json`: Blobs unter `data/raw/` werden 30 Tage nach der letzten Änderung gelöscht.
- Die Datenbefehle und die SAS melden sich mit dem Kontoschlüssel an (`AZURE_STORAGE_KEY`). Besser ist die Anmeldung mit Entra ID und der Rolle *Storage Blob Data Contributor*; so arbeiten die Termine 9–11. Eine SAS lässt sich dann als *User Delegation SAS* ohne Kontoschlüssel ausstellen.

**Prüfen:** Die Ausgabe von `sas.sh` zeigt ohne Signatur ein Fehler (`409 PublicAccessNotPermitted` oder `404`) – das Objekt ist privat –, mit Signatur und `Range: bytes=0-99` die Antwort `206 Partial Content` mit `Content-Range` und bei der Preflight-Anfrage `Access-Control-Allow-Origin: http://localhost:5173`.

## Zusatz: verwaltete Datenbank (Termin 6)

Freiwillig und ohne Folgen für spätere Termine; die Übung von Termin 6 ist rein lokal ([cloud-labs-local/06-postgis](https://github.com/mf-iu/cloud-labs-local/tree/master/06-postgis)). Pflicht wird die verwaltete Datenbank in Termin 8 – dann im privaten Netz, angelegt mit OpenTofu in `06-infrastructure-as-code/service`. Die Instanz wird stündlich abgerechnet; der Ablauf dauert mit Anlegen und Löschen rund 30 Minuten.

```bash
cd /workspaces/cloud-labs-azure/05-storage
./create-db.sh               # Server mit Firewall-Regel für die eigene IP, ca. 5-10 min
./with-db.sh load-cities.sh  # dieselben Daten, jetzt über das Internet
./with-db.sh query.sh        # Zeiten mit der lokalen Datenbank vergleichen
./with-db.sh test-api.sh     # PlaceFinder lokal, die Daten aus der Cloud
./backups.sh                 # Backups und Point-in-Time Recovery
./destroy-db.sh              # danach löschen – gehört dazu
../tools/find-leftovers.sh   # nichts mehr, was kostet?
```

`with-db.sh` setzt `DATABASE_URL` auf die Datenbank aus `create-db.sh` und ruft das Skript aus [cloud-labs-local/06-postgis](https://github.com/mf-iu/cloud-labs-local/tree/master/06-postgis) auf – dieselben Skripte wie lokal, jetzt über das Internet.

`create-db.sh` erzeugt ein zufälliges Passwort für den Benutzer `pfadmin` und speichert die Verbindungszeichenkette in `../.state/t06.env` (nicht eingecheckt). Der Server ist öffentlich erreichbar, die Firewall lässt aber nur die eigene IP-Adresse zu, und die Verbindung ist mit TLS verschlüsselt (`sslmode=require`). Version: PostgreSQL 18 wie lokal.

Besonderheit bei Azure: Erweiterungen müssen erst über den Serverparameter `azure.extensions` freigegeben werden, bevor `CREATE EXTENSION postgis` funktioniert. Das Skript gibt PostGIS und pg_trgm frei.

PlaceFinder von Hand mit derselben Datenbank starten (im Ordner `/workspaces/placefinder`), etwa für die Karte (`http://localhost:5173/?api=http://localhost:8000`):

```bash
source ../cloud-labs-azure/.state/t06.env && export DATABASE_URL   # the database from create-db.sh
uv run fastapi dev src/placefinder/main.py                # meldet: Using PostGIS at <host>:5432/placefinder
```

**Zeiten vergleichen:** Lokal brauchen die Anfragen wenige Millisekunden. Mit der Datenbank beim Anbieter kommt für jede Abfrage mindestens ein Weg durchs Internet hinzu – die Zeiten von `./with-db.sh test-api.sh` zeigen, warum Anwendung und Datenbank in dieselbe Region und dasselbe Netz gehören (Termin 8).

**Backups:** Der Flexible Server sichert täglich einen Snapshot und archiviert das WAL alle fünf Minuten; die Backups bleiben sieben Tage (Standard). `backups.sh` zeigt Einstellungen, Backups und den frühesten Zeitpunkt für Point-in-Time Recovery. Eine Wiederherstellung legt einen **neuen Server** an (`az postgres flexible-server restore`); das Skript zeigt den Befehl nur.

Im Portal: *Monitoring* → *Metrics*, *Settings* → *Backup and restore* (automatische Backups, Wiederherstellung auf einen Zeitpunkt).

## Typische Probleme

| Meldung | Ursache | Abhilfe |
|---|---|---|
| Karte zeigt die Basiskarte von OpenFreeMap | Parameter `tiles` fehlt oder ist nicht URL-kodiert. | Adresse aus `sas.sh` verwenden |
| Konsole des Browsers: CORS-Fehler | Die Karte läuft unter einer anderen Herkunft, z. B. `http://127.0.0.1:5173`. | Karte über `http://localhost:5173` öffnen |
| `403` trotz Signatur | Die URL ist abgelaufen oder wurde beim Kopieren verändert. | neue URL erzeugen, vollständig kopieren |
| `connection timeout expired`, psql hängt | Die eigene IP-Adresse hat sich geändert (neuer Tag, anderes Netz) und ist nicht freigegeben. | neue Adresse freigeben, siehe unten |
| `does not read DATABASE_URL yet` | PlaceFinder hat noch keine Datenbankanbindung. | Übung abschließen oder Tag `t06` auschecken |
| `Table places not found` | Die Datenbank ist leer. | `./with-db.sh load-cities.sh` |
| `Port 8006 is in use` | Ein früherer Lauf oder ein anderer Server belegt den Port. | `./with-db.sh test-api.sh --port 8007` |

Neue IP-Adresse freigeben:

```bash
az postgres flexible-server firewall-rule create --resource-group rg-pf-<owner>-t06 \
  --name <server> --rule-name new-ip --start-ip-address <ip> --end-ip-address <ip>
```

Den Namen des Servers zeigt `az postgres flexible-server list --resource-group rg-pf-<owner>-t06 --output table`, die eigene IP-Adresse `curl https://checkip.amazonaws.com`.

## Aufräumen

```bash
./destroy-storage.sh        # Ressourcengruppe mit dem Speicherkonto
./destroy-db.sh             # Ressourcengruppe mit Server und Backups
../tools/find-leftovers.sh  # nothing left that costs money?
```

## Fragen zum Weiterdenken

- Welche Arten von SAS-Token gibt es (Konto, Dienst, User Delegation), und welche ist am sichersten?
- Welche Zugriffsebene (Hot, Cool, Cold, Archive) passt zu selten gelesenen Rohdaten, und was kostet dann der Abruf?
- Wie würde Azure Front Door als CDN vor dem Speicherkonto die Kosten für viele Kartenaufrufe senken?
- Warum braucht die Karte mit PMTiles keinen Kachelserver – und was ändert ein CDN davor an Kosten und Latenz?
- Welche Aufgaben übernimmt der Flexible Server gegenüber PostgreSQL auf einer eigenen VM?
- Was bedeuten RPO und RTO bei sieben Tagen Backup-Aufbewahrung?
- Wie müsste der Server ins Subnetz `db` aus Termin 4 (VNet-Integration), damit nur die Anwendung ihn erreicht?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Object Storage | S3 | Blob Storage | Cloud Storage |
| Zeitlich begrenzter Zugriff | Pre-Signed URL | SAS-Token | Signed URL |
| Privat | Block Public Access | `--allow-blob-public-access false` | Public Access Prevention |
| CORS | Bucket (`put-bucket-cors`) | Blob-Dienst des Kontos | Bucket (`--cors-file`) |
| Verwalteter Cache | ElastiCache for Valkey | Azure Managed Redis | Memorystore for Valkey |
| Dienst | RDS for PostgreSQL | Azure Database for PostgreSQL (Flexible Server) | Cloud SQL for PostgreSQL |
| Kleinste Größe | `db.t4g.micro` | `Standard_B1ms` | `db-f1-micro` (Edition Enterprise) |
| Zugang nur von der eigenen IP | Security Group | Firewall-Regel | autorisiertes Netz |
| PostGIS aktivieren | `CREATE EXTENSION` | erst freigeben (`azure.extensions`), dann `CREATE EXTENSION` | `CREATE EXTENSION` |
| Backups in der Übung | täglich, ein Tag Aufbewahrung | täglich, sieben Tage | täglich, sieben Backups |
| Point-in-Time Recovery | immer an; neue Instanz | immer an; neuer Server | mit `--enable-point-in-time-recovery`; Klon |
