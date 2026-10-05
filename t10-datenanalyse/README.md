# T10 – Data Lake mit GeoParquet und DuckDB

**Ziel:** GeoNames-Orte liegen als GeoParquet in Azure Data Lake Storage Gen2 (Blob Storage mit hierarchischem Namespace). DuckDB fragt die Datei direkt im Speicher ab, ebenso die öffentlichen Overture-Maps-Daten, die Overture auch auf Azure bereitstellt.

**Kosten:** Speicher praktisch null. Overture-Abfragen lesen aus einem fremden Speicherkonto und kosten im eigenen Abonnement nichts.

## Schritte

```bash
cd ..
tools/tofu.sh t10-datenanalyse/infra apply   # Speicherkonto mit HNS, Container "lake", Rolle für dich
t10-datenanalyse/upload.sh                    # cities15000 -> GeoParquet -> lake/places/
t10-datenanalyse/query-duckdb.sh              # DuckDB auf Blob Storage
```

Neue Rollenzuweisungen brauchen bei Azure einige Minuten, bis sie wirken. Meldet `upload.sh` „AuthorizationPermissionMismatch“, kurz warten und erneut starten.

DuckDB meldet sich über die Azure-Erweiterung mit dem Token des `az login` an (`PROVIDER credential_chain, CHAIN 'cli'`). `export_geoparquet.py` schreibt eine Geometriespalte `geom` als WKB mit GeoParquet-Metadaten und behält Breite und Länge als normale Spalten. Die Datei ist nach Land sortiert, sodass Filter auf `country_code` ganze Row Groups überspringen.

### Overture Maps

Overture veröffentlicht etwa monatlich ein Release als GeoParquet, auf Azure im Speicherkonto `overturemapswestus2`. Die aktuelle Release-Kennung steht unter <https://docs.overturemaps.org/release/latest/>:

```bash
t10-datenanalyse/query-duckdb.sh 2026-09-17.0     # Beispielkennung, aktuelle eintragen
```

DuckDB liest dabei nur die Row Groups, deren Bounding Box zum Filter passt (Predicate Pushdown).

### Serverlose SQL-Dienste

Azure bietet SQL-Abfragen auf dem Data Lake in Microsoft Fabric und in Azure Synapse (serverless SQL pool). Beide brauchen einen eigenen Arbeitsbereich und rechnen nach gelesenen Daten bzw. Kapazität ab; im Kurs werden sie nur vorgestellt. DuckDB zeigt dasselbe Prinzip – Abfragen direkt auf Dateien im Object Storage – ohne zusätzliche Kosten.

## Aufräumen

```bash
tools/tofu.sh t10-datenanalyse/infra destroy
```

## Fragen zum Weiterdenken

- Was bringt der hierarchische Namespace (Data Lake Storage Gen2) gegenüber normalem Blob Storage?
- Warum ist Parquet für Analysen schneller und billiger als CSV, obwohl die Daten dieselben sind?
- Wann reicht DuckDB auf einem Rechner, und wann braucht man Spark oder ein Data Warehouse?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Data Lake | S3 | Blob Storage / Data Lake Storage | Cloud Storage |
| Serverlose SQL-Abfragen | Athena | Fabric, Synapse serverless SQL | BigQuery |
| Overture Maps | S3 (us-west-2) | Blob Storage (West US 2) | BigQuery Public Datasets |
