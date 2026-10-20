# T08 – Infrastruktur als Code, Pipeline und Beobachtbarkeit

**Ziel:** Infrastruktur entsteht reproduzierbar aus Code. Zuerst lokal: OpenTofu startet PlaceFinder und Valkey als Container. Dann beim neuen Anbieter: Die Infrastruktur der Zwischenpräsentation – Netz aus Termin 4, Speicherkonto aus Termin 7, Container App aus Termin 3, auf Wunsch die Datenbank aus Termin 6 – entsteht aus OpenTofu-Code mit Remote State im Blob Storage. Eine Pipeline in GitHub Actions testet, baut, scannt und signiert das Image von PlaceFinder; ein zweiter Workflow rollt es ohne gespeicherte Secrets aus. Traces und Metriken zeigt Grafana.

| Ordner oder Datei | Aufgabe |
|---|---|
| `local/` | OpenTofu mit dem Docker-Provider: Netz, Valkey und PlaceFinder als Container (Teil 1) |
| `bootstrap-state.sh`, `destroy-state.sh` | Speicherkonto für den Remote State anlegen bzw. am Kursende löschen |
| `infra/` | Infrastruktur der Zwischenpräsentation: VNet, Speicherkonto, PlaceFinder auf Azure Container Apps, optional PostgreSQL Flexible Server |
| `github-oidc/` | Vertrauensstellung für GitHub Actions: Managed Identity mit Federated Credential, das nur der eigene Fork nutzen darf |
| `deploy.example.yml` | Workflow für den eigenen Fork: Image aus der Pipeline per Digest ausrollen, Smoke-Test |

Dazu gehört PlaceFinder ab Tag `t08`: die CI-Pipeline `.github/workflows/ci.yml`, Telemetrie mit OpenTelemetry und `DATABASE_INIT` (README von PlaceFinder, Abschnitte *Pipeline*, *Beobachtbarkeit* und *Datenbank selbst füllen*).

**Kosten:** Teil 1 läuft lokal und kostet nichts; GitHub Actions ist für öffentliche Repositories kostenlos. Teil 2: Container Apps im Verbrauchsmodell und Blob Storage bleiben im Freikontingent, PostgreSQL `Standard_B1ms` in den ersten 12 Monaten im Rahmen der kostenlosen 750 Stunden. Die private DNS-Zone der Datenbank kostet ca. 0,50 USD im Monat. **Nach dem Test `destroy` ausführen** – die Testphase dauert nur 30 Tage.

## Voraussetzungen

- Dev Container dieses Repositorys mit OpenTofu ab 1.10 (`tools/check-tools.sh`)
- Teil 2: Azure-Konto beim neuen Anbieter eingerichtet (`t01-grundlagen`, Anbieterwechsel in [t07-objektspeicher](../t07-objektspeicher/README.md#anbieterwechsel)), `az login` aktiv, Ressourcenanbieter registriert (`t01-grundlagen/register-providers.sh`), `config.env` ausgefüllt
- Image `$PLACEFINDER_IMAGE:t08` öffentlich auf ghcr.io: `t03-container/build-image.sh --push --tag t08`, danach das Paket auf GitHub öffentlich machen

## Teil 1: lokal (Übung im Termin)

### OpenTofu mit Docker

`local/` beschreibt, was sonst `compose.yaml` erledigt: ein Netz, Valkey und PlaceFinder als Container. Der State bleibt als Datei im Ordner (`terraform.tfstate`, nicht eingecheckt).

```bash
cd /workspaces/placefinder && docker compose build api      # Image placefinder:0.8.0 aus dem eigenen Fork
cd /workspaces/cloud-labs-azure/t08-iac/local
tofu init                                   # lädt den Docker-Provider, legt .terraform.lock.hcl an
tofu plan                                   # was würde passieren? 5 to add
tofu apply                                  # nach Rückfrage anlegen
tofu output                                 # http://localhost:8101
curl "http://localhost:8101/v1/places?q=Erfurt" --include | grep --ignore-case cache-status
```

`docker compose build api` baut das Image unter dem Namen aus `compose.yaml`, ab Tag `t08` `placefinder:0.8.0`. Mit anderem Namen oder ohne eigenes Image: `tofu apply -var placefinder_image=ghcr.io/<github-user>/placefinder:t08`.

**Ausprobieren:**

1. **Ändern:** `tofu apply -var instances=2` – der Plan zeigt *1 to add*: ein zweiter Container auf Port 8102, der Rest bleibt.
2. **Ersetzen:** `tofu apply -var instances=2 -var cache_ttl=60` – eine geänderte Umgebungsvariable lässt sich an einem laufenden Container nicht ändern; der Plan zeigt `-/+` (*must be replaced*).
3. **Drift:** `docker rm --force pf-t08-valkey`, dann `tofu plan` – OpenTofu vergleicht den State mit der Wirklichkeit und will Valkey neu anlegen. `tofu apply` stellt den beschriebenen Zustand wieder her.
4. **State ansehen:** `tofu state list`, `tofu state show 'docker_container.placefinder[0]'`
5. **Abbauen:** `tofu destroy` – Container und Netz verschwinden, die Images bleiben (`keep_locally`).

### Pipeline im eigenen Fork

Der Tag `t08` von PlaceFinder enthält die Pipeline. In den eigenen Fork übernehmen (`upstream` einrichten: siehe [t02-vm](../t02-vm/README.md#container-und-compose)):

```bash
cd /workspaces/placefinder
git fetch upstream --tags                # Tag t08 der Musterlösung holen
git checkout t08 -- .github/workflows/ci.yml .github/dependabot.yml
uv run ruff format && uv run ruff check && uv run pytest      # vorher lokal grün?
git add .github && git commit --message "Add CI pipeline" && git push
```

Auf GitHub unter *Actions* den Lauf verfolgen. Auf `master` lädt der Job `image` das Image als `ghcr.io/<github-user>/placefinder:<commit>` und `:master` hoch, mit SBOM, Provenance und Signatur. Was die Schritte tun und wie sich die Signatur prüfen lässt: README von PlaceFinder, Abschnitt *Pipeline*.

### Beobachtbarkeit lokal

```bash
cd /workspaces/placefinder
OTEL_EXPORTER_OTLP_ENDPOINT=http://lgtm:4318 docker compose --profile observability up --detach --build
```

Last erzeugen, dann in Grafana (http://localhost:3000) das Dashboard *RED Metrics*, die Traces in Tempo und die Abfragen für die SLIs ansehen – Schritt für Schritt im README von PlaceFinder, Abschnitt *Beobachtbarkeit*.

## Teil 2: beim neuen Anbieter (Selbstlernphase)

### 1. Remote State einrichten (einmalig)

```bash
cd /workspaces/cloud-labs-azure
t08-iac/bootstrap-state.sh
```

Das Skript legt die Ressourcengruppe `rg-pf-<owner>-tfstate` mit einem Speicherkonto an (Blob-Versionierung aktiv, privater Container `tfstate`) und schreibt `.state/backend.hcl`. Gesperrt wird der State über eine Lease auf dem Blob. Das Speicherkonto legt die CLI an, weil OpenTofu seinen State-Speicher nicht verwalten kann, bevor es ihn gibt (Henne-Ei-Problem).

### 2. Infrastruktur ausrollen

```bash
tools/tofu.sh t08-iac/infra plan      # beim ersten Aufruf mit init
tools/tofu.sh t08-iac/infra apply     # ca. 5 Minuten
tools/tofu.sh t08-iac/infra output
curl "$(tools/tofu.sh t08-iac/infra output -raw service_url)/health"
```

`tools/tofu.sh` setzt `ARM_SUBSCRIPTION_ID` und die Variablen `prefix`, `owner`, `suffix`, `location` und `placefinder_image` aus `config.env` und verwendet für jeden Ordner einen eigenen Blob im State-Container, z. B. `t08-iac/infra/terraform.tfstate`.

| Datei | Inhalt |
|---|---|
| `infra/network.tf` | Ressourcengruppe `rg-pf-<owner>-t08`, VNet `10.20.0.0/16` mit Anwendungs- und Datenbank-Subnetz wie in Termin 4, NSG für die Datenbank |
| `infra/storage.tf` | Speicherkonto mit privatem Container, CORS und Lebenszyklusregel wie in Termin 7 |
| `infra/service.tf` | Container-Apps-Umgebung im Anwendungs-Subnetz (Workload-Profil *Consumption*) und PlaceFinder als Container App |
| `infra/database.tf` | optional: PostgreSQL Flexible Server 18 mit privatem Zugriff im Datenbank-Subnetz, private DNS-Zone |
| `infra/outputs.tf` | URL, Ressourcengruppe und Name der Container App, Speicherkonto, Datenbank |

**Wo ist das öffentliche Subnetz?** Beide Subnetze sind an einen Dienst delegiert: `app` an Container Apps, `db` an PostgreSQL. Von außen erreichbar ist nur der Load Balancer, den die Container-Apps-Umgebung selbst mitbringt. Das Subnetz `app` behält den ausgehenden Standardzugang, damit die Replikate das Image von ghcr.io laden können; in Produktion übernähme das ein NAT-Gateway (ca. 1 EUR pro Tag).

### Mit Datenbank

```bash
tools/tofu.sh t08-iac/infra apply -var enable_database=true    # ca. 10 Minuten mehr
curl "$(tools/tofu.sh t08-iac/infra output -raw service_url)/health"   # "places": 34000 und mehr
```

Anders als in Termin 6 hat der Server keine öffentliche Adresse: Er liegt im delegierten Subnetz `db`, sein Name löst sich nur im VNet über die private DNS-Zone auf, und die NSG lässt nur PostgreSQL aus dem Subnetz `app` zu. Vom eigenen Rechner aus ist er nicht erreichbar, `load-cities.sh` geht also nicht. Stattdessen lädt PlaceFinder beim ersten Start die Orte aus dem Image (`DATABASE_INIT=true`). Die Erweiterungen PostGIS und pg_trgm sind über `azure.extensions` freigegeben.

Das Passwort erzeugt OpenTofu (`random_password`); die Container App bekommt es als Secret und gibt es als `PGPASSWORD` an PlaceFinder, die Verbindungszeichenkette `DATABASE_URL` enthält kein Passwort. Im State steht es aber – ein Grund, warum der State privat und verschlüsselt liegt. Ganz ohne Passwort ginge es mit einer Anmeldung über Entra ID und die Managed Identity der Container App.

### 3. Ausrollen aus der Pipeline, ohne Secrets

```bash
tools/tofu.sh t08-iac/github-oidc apply -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/github-oidc output
```

Die Konfiguration legt in `rg-pf-<owner>-cicd` eine benutzerseitig zugewiesene Managed Identity an. Ein Federated Credential erlaubt nur Workflows auf dem Branch `master` des genannten Repositorys, sich als diese Identität anzumelden. Die Identität hat die Rolle *Contributor* nur auf der Ressourcengruppe von `infra` – deshalb `infra` zuerst anlegen.

Im eigenen PlaceFinder-Fork:

1. `deploy.example.yml` als `.github/workflows/deploy.yml` übernehmen, committen, pushen.
2. Repository-Variablen anlegen (*Settings* → *Secrets and variables* → *Actions* → *Variables*): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` und `AZURE_SUBSCRIPTION_ID` aus `github-oidc`, `RESOURCE_GROUP`, `CONTAINER_APP` und `SERVICE_URL` (Ausgabe `service_url`) aus `infra`.
3. Eine kleine Änderung pushen. Nach der grünen Pipeline startet `deploy`: Image per Digest als neue Revision ausrollen (ein bis zwei Minuten), dann der Smoke-Test aus Termin 5.

**Pipeline und OpenTofu:** `image_tag` bestimmt nur das erste Image. Danach rollt die Pipeline aus; `ignore_changes` in `service.tf` verhindert, dass das nächste `apply` auf `image_tag` zurücksetzt. Jede Eigenschaft gehört genau einem Werkzeug.

### 4. Logs und Metriken beim Anbieter

```bash
az containerapp logs show --resource-group rg-pf-<owner>-t08 --name pf-<owner>-t08-placefinder --follow
az containerapp revision list --resource-group rg-pf-<owner>-t08 --name pf-<owner>-t08-placefinder --output table
```

Im Portal: Container App → *Monitoring* → *Metrics* (Anfragen nach Statuscode, Antwortzeit, Replikate, CPU, Speicher). Das ist RED für den Dienst – ohne eine Zeile Code, aber nur an der Grenze der Umgebung; die Spans in der Anwendung liefert erst OpenTelemetry. Die Umgebung hat bewusst keinen Log-Analytics-Arbeitsbereich (Kosten); Logs gibt es deshalb nur als Stream.

## Ausprobieren

- Eine Einstellung ändern (z. B. `-var max_replicas=3`) und den Plan lesen: Was ändert sich in place (`~`), was wird ersetzt (`-/+`)?
- Im Portal etwas von Hand ändern, z. B. die CORS-Regel des Speicherkontos löschen, und mit `plan` die Abweichung finden (Drift).
- `destroy` und `apply` hintereinander: Ist alles wieder gleich? Was hat sich geändert (Adressen, Namen)?
- `tools/tofu.sh t08-iac/infra state list` und `state show azurerm_virtual_network.main`

## Typische Probleme

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `No remote state yet` | `bootstrap-state.sh` fehlt | `t08-iac/bootstrap-state.sh` |
| `Error acquiring the state lock` | Ein anderer Lauf hält die Lease oder ist abgebrochen. | warten; nach einem Abbruch `tofu force-unlock <id>` mit der ID aus der Meldung |
| `RequestDisallowedByAzure` oder `RequestDisallowedByPolicy` | Region in diesem Abonnement nicht erlaubt (z. B. Azure for Students) | erlaubte Region in `config.env` (`t01-grundlagen/check-cli.sh` zeigt sie) |
| `MissingSubscriptionRegistration` | Ressourcenanbieter nicht registriert | `t01-grundlagen/register-providers.sh` |
| Container App startet nicht, Image nicht gefunden | `:t08` fehlt auf ghcr.io oder ist privat | `t03-container/build-image.sh --push --tag t08`, Paket öffentlich machen |
| `/health` antwortet erst nach einer Minute | Beim ersten Start mit Datenbank lädt PlaceFinder die Orte. | warten; die Logs zeigen `Loaded … places` |
| `github-oidc`: Ressourcengruppe `rg-pf-<owner>-t08` nicht gefunden | `infra` fehlt | zuerst `tools/tofu.sh t08-iac/infra apply` |
| Workflow: `AADSTS700213: No matching federated identity record` | Repository oder Branch passt nicht zum Federated Credential | `github_repository` genau wie auf GitHub, Branch `master` |

## Aufräumen

```bash
tools/tofu.sh t08-iac/github-oidc destroy -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/infra destroy
(cd t08-iac/local && tofu destroy)
t08-iac/destroy-state.sh      # erst am Kursende, nach allen anderen destroy-Aufrufen
tools/find-leftovers.sh
```

## Fragen zum Weiterdenken

- Was steht im State, und warum gehört er nicht ins Git-Repository? Wie schützt dieses Speicherkonto ihn?
- Warum ist OIDC-Federation sicherer als ein Client Secret in den GitHub-Secrets?
- Welche Teile der Konfiguration sind anbieterspezifisch, welche ließen sich als Modul für alle drei Anbieter schreiben?
- Die Pipeline rollt aus, OpenTofu ignoriert das Image. Was ginge verloren, wenn OpenTofu auch das Image verwaltete – und was mit GitOps?
- Welches SLO würden Sie für PlaceFinder festlegen, und welche Metrik misst es?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| State-Backend | S3 mit Lock-Datei | Storage Account (Blob Lease) | Cloud Storage |
| Datenbank im privaten Netz | RDS in Subnetzen ohne Route ins Internet | Flexible Server mit delegiertem Subnetz und privater DNS-Zone | Cloud SQL mit privater IP über Private Services Access |
| Datenbank-Passwort | Secrets Manager, von RDS verwaltet | Secret der Container App | Secret Manager |
| Ausrollen ohne Schlüssel | IAM-OIDC-Anbieter + Rolle | Managed Identity + Federated Credential | Workload Identity Federation |
| Native IaC | CloudFormation, CDK | Bicep | Infrastructure Manager |
| Logs und Metriken | CloudWatch, X-Ray | Azure Monitor, Application Insights | Cloud Logging, Cloud Monitoring, Cloud Trace |
