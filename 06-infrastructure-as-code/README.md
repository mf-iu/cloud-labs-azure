# 06 – Infrastruktur als Code: base und service

**Ziel:** Die Infrastruktur der Zwischenpräsentation entsteht beim neuen Anbieter reproduzierbar aus OpenTofu-Code mit Remote State – in zwei Teilen:

- **`base`** – Ressourcengruppe, VNet aus Termin 4, Speicherkonto aus Termin 7. Entsteht einmal in Termin 8 und bleibt bis zum Kursende; kostet praktisch nichts.
- **`service`** – Container-Apps-Umgebung mit PlaceFinder, optional PostgreSQL Flexible Server. Liest die Ausgaben von `base` und wird im Termin angelegt und wieder gelöscht.

Die Function, der Data Lake, ML und das Abschlussprojekt bauen später ebenfalls auf `base` auf. Ein Workflow im eigenen Fork rollt neue Images ohne gespeicherte Zugangsschlüssel aus. Lokal gehören dazu OpenTofu mit Docker, die Pipeline im eigenen Fork und die Beobachtbarkeit mit Grafana: [cloud-labs-local/08-iac-and-operations](https://github.com/mf-iu/cloud-labs-local/tree/master/08-iac-and-operations).

| Ordner oder Datei | Aufgabe |
|---|---|
| `bootstrap-state.sh`, `destroy-state.sh` | Speicherkonto für den Remote State anlegen bzw. am Kursende löschen |
| `base/` | Ressourcengruppe, VNet aus Termin 4, Speicherkonto aus Termin 7; bleibt bis zum Kursende |
| `service/` | Container-Apps-Umgebung mit PlaceFinder, optional PostgreSQL Flexible Server; im Termin anlegen und löschen |
| `github-oidc/` | Vertrauensstellung für GitHub Actions: Managed Identity mit Federated Credential, das nur der eigene Fork nutzen darf |
| `deploy.example.yml` | Workflow für den eigenen Fork: Image aus der Pipeline per Digest ausrollen, Smoke-Test |

**Kosten:** `base` kostet praktisch nichts und darf bis zum Kursende bestehen bleiben. `service`: Container Apps im Verbrauchsmodell und Blob Storage bleiben im Freikontingent, PostgreSQL `Standard_B1ms` in den ersten 12 Monaten im Rahmen der kostenlosen 750 Stunden. Die private DNS-Zone der Datenbank kostet ca. 0,50 USD im Monat. **`service` nach dem Test wieder löschen** – die Testphase dauert nur 30 Tage.

## Voraussetzungen

- Dev Container dieses Repositorys mit OpenTofu ab 1.10 (`../cloud-labs-local/tools/check-tools.sh`)
- Azure-Konto beim neuen Anbieter eingerichtet (Schritt `01-account` mit dem [Anbieterwechsel](../01-account/README.md#anbieterwechsel)), `az login` aktiv, Ressourcenanbieter registriert (`01-account/register-providers.sh`), `config.env` ausgefüllt
- Image `$PLACEFINDER_IMAGE:t08` öffentlich auf ghcr.io: `../cloud-labs-local/02-container/publish-image.sh --tag t08` oder die Pipeline des Forks, danach das Paket auf GitHub öffentlich machen

## 1. Remote State einrichten (einmalig)

```bash
cd /workspaces/cloud-labs-azure
06-infrastructure-as-code/bootstrap-state.sh
```

Das Skript legt die Ressourcengruppe `rg-pf-<owner>-tfstate` mit einem Speicherkonto an (Blob-Versionierung aktiv, privater Container `tfstate`) und schreibt `.state/backend.hcl`. Gesperrt wird der State über eine Lease auf dem Blob. Das Speicherkonto legt die CLI an, weil OpenTofu seinen State-Speicher nicht verwalten kann, bevor es ihn gibt (Henne-Ei-Problem).

## 2. base anlegen (einmalig, bleibt bis zum Kursende)

```bash
tools/tofu.sh 06-infrastructure-as-code/base plan      # beim ersten Aufruf mit init
tools/tofu.sh 06-infrastructure-as-code/base apply
tools/tofu.sh 06-infrastructure-as-code/base output
```

`tools/tofu.sh` setzt `ARM_SUBSCRIPTION_ID` und die Variablen `prefix`, `owner`, `suffix`, `location` und `placefinder_image` aus `config.env` und verwendet für jeden Ordner einen eigenen Blob im State-Container, z. B. `06-infrastructure-as-code/base/terraform.tfstate`. Dazu kommt `backend` mit den Einstellungen aus `.state/backend.hcl`: Damit liest `service` die Ausgaben von `base` (`terraform_remote_state`).

| Datei | Inhalt |
|---|---|
| `base/network.tf` | Ressourcengruppe `rg-pf-<owner>-t08`, VNet `10.20.0.0/16` mit Anwendungs- und Datenbank-Subnetz wie in Termin 4, NSG für die Datenbank |
| `base/storage.tf` | Speicherkonto mit privatem Container, CORS und Lebenszyklusregel wie in Termin 7 |
| `base/outputs.tf` | Ressourcengruppe, Region, VNet, Subnetze und Speicherkonto für `service` und spätere Konfigurationen |

**Wo ist das öffentliche Subnetz?** Beide Subnetze sind an einen Dienst delegiert: `app` an Container Apps, `db` an PostgreSQL. Von außen erreichbar ist nur der Load Balancer, den die Container-Apps-Umgebung selbst mitbringt. Das Subnetz `app` behält den ausgehenden Standardzugang, damit die Replikate das Image von ghcr.io laden können; in Produktion übernähme das ein NAT-Gateway (ca. 1 EUR pro Tag).

## 3. service anlegen, prüfen, löschen (im Termin)

```bash
tools/tofu.sh 06-infrastructure-as-code/service plan
tools/tofu.sh 06-infrastructure-as-code/service apply     # ca. 5 Minuten
tools/tofu.sh 06-infrastructure-as-code/service output
curl "$(tools/tofu.sh 06-infrastructure-as-code/service output -raw service_url)/health"
tools/tofu.sh 06-infrastructure-as-code/service destroy   # am Ende des Termins
```

`service/base.tf` liest die Ausgaben von `base` aus dessen State (`terraform_remote_state`): Netz, Subnetze, Speicher und was der Dienst sonst braucht. `service` legt also nichts doppelt an und kann jederzeit gelöscht werden, ohne `base` anzutasten.

| Datei | Inhalt |
|---|---|
| `service/base.tf` | liest die Ausgaben von `base` (`terraform_remote_state`) |
| `service/service.tf` | Container-Apps-Umgebung im Anwendungs-Subnetz von `base` (Workload-Profil *Consumption*) und PlaceFinder als Container App |
| `service/database.tf` | optional: PostgreSQL Flexible Server 18 mit privatem Zugriff im Datenbank-Subnetz, private DNS-Zone |
| `service/outputs.tf` | URL, Ressourcengruppe und Name der Container App, Datenbank |

### Mit Datenbank

```bash
tools/tofu.sh 06-infrastructure-as-code/service apply -var enable_database=true    # ca. 10 Minuten mehr
curl "$(tools/tofu.sh 06-infrastructure-as-code/service output -raw service_url)/health"   # "places": 34000 und mehr
```

Anders als in Termin 6 hat der Server keine öffentliche Adresse: Er liegt im delegierten Subnetz `db`, sein Name löst sich nur im VNet über die private DNS-Zone auf, und die NSG lässt nur PostgreSQL aus dem Subnetz `app` zu. Vom eigenen Rechner aus ist er nicht erreichbar, `load-cities.sh` geht also nicht. Stattdessen lädt PlaceFinder beim ersten Start die Orte aus dem Image (`DATABASE_INIT=true`). Die Erweiterungen PostGIS und pg_trgm sind über `azure.extensions` freigegeben.

Das Passwort erzeugt OpenTofu (`random_password`); die Container App bekommt es als Secret und gibt es als `PGPASSWORD` an PlaceFinder, die Verbindungszeichenkette `DATABASE_URL` enthält kein Passwort. Im State steht es aber – ein Grund, warum der State privat und verschlüsselt liegt. Ganz ohne Passwort ginge es mit einer Anmeldung über Entra ID und die Managed Identity der Container App.

## 4. Ausrollen aus der Pipeline, ohne Schlüssel

```bash
tools/tofu.sh 06-infrastructure-as-code/github-oidc apply -var github_repository=<github-user>/placefinder
tools/tofu.sh 06-infrastructure-as-code/github-oidc output
```

Die Konfiguration legt in `rg-pf-<owner>-cicd` eine benutzerseitig zugewiesene Managed Identity an. Ein Federated Credential erlaubt nur Workflows auf dem Branch `master` des genannten Repositorys, sich als diese Identität anzumelden. Die Identität hat die Rolle *Contributor* nur auf der Ressourcengruppe von `base`, in der auch `service` die Container App anlegt – deshalb `base` zuerst anlegen.

Im eigenen PlaceFinder-Fork:

1. `deploy.example.yml` als `.github/workflows/deploy.yml` übernehmen, committen, pushen.
2. Repository-Variablen anlegen (*Settings* → *Secrets and variables* → *Actions* → *Variables*): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` und `AZURE_SUBSCRIPTION_ID` aus `github-oidc`, `RESOURCE_GROUP`, `CONTAINER_APP` und `SERVICE_URL` (Ausgabe `service_url`) aus `service`.
3. Eine kleine Änderung pushen. Nach der grünen Pipeline startet `deploy`: Image per Digest als neue Revision ausrollen (ein bis zwei Minuten), dann der Smoke-Test aus Termin 5.

**Pipeline und OpenTofu:** `image_tag` bestimmt nur das erste Image. Danach rollt die Pipeline aus; `ignore_changes` in `service.tf` verhindert, dass das nächste `apply` auf `image_tag` zurücksetzt. Jede Eigenschaft gehört genau einem Werkzeug.

## 5. Logs und Metriken beim Anbieter

```bash
az containerapp logs show --resource-group rg-pf-<owner>-t08 --name pf-<owner>-t08-placefinder --follow
az containerapp revision list --resource-group rg-pf-<owner>-t08 --name pf-<owner>-t08-placefinder --output table
```

Im Portal: Container App → *Monitoring* → *Metrics* (Anfragen nach Statuscode, Antwortzeit, Replikate, CPU, Speicher). Das ist RED für den Dienst – ohne eine Zeile Code, aber nur an der Grenze der Umgebung; die Spans in der Anwendung liefert erst OpenTelemetry. Die Umgebung hat bewusst keinen Log-Analytics-Arbeitsbereich (Kosten); Logs gibt es deshalb nur als Stream.

## Ausprobieren

- Eine Einstellung ändern (z. B. `-var max_replicas=3`) und den Plan lesen: Was ändert sich in place (`~`), was wird ersetzt (`-/+`)?
- Im Portal etwas von Hand ändern, z. B. die CORS-Regel des Speicherkontos löschen, und mit `plan` die Abweichung finden (Drift).
- `destroy` und `apply` hintereinander: Ist alles wieder gleich? Was hat sich geändert (Adressen, Namen)?
- `tools/tofu.sh 06-infrastructure-as-code/base state list` und `state show azurerm_virtual_network.main`; `tools/tofu.sh 06-infrastructure-as-code/service state show data.terraform_remote_state.base`
- `base` ändern und `service` neu planen: Was sieht `service` von der Änderung, ohne dass sich sein eigener Code ändert?

## Typische Probleme

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `No remote state yet` | `bootstrap-state.sh` fehlt | `06-infrastructure-as-code/bootstrap-state.sh` |
| `Error acquiring the state lock` | Ein anderer Lauf hält die Lease oder ist abgebrochen. | warten; nach einem Abbruch `tofu force-unlock <id>` mit der ID aus der Meldung |
| `RequestDisallowedByAzure` oder `RequestDisallowedByPolicy` | Region in diesem Abonnement nicht erlaubt (z. B. Azure for Students) | erlaubte Region in `config.env` (`01-account/check-cli.sh` zeigt sie) |
| `MissingSubscriptionRegistration` | Ressourcenanbieter nicht registriert | `01-account/register-providers.sh` |
| Container App startet nicht, Image nicht gefunden | `:t08` fehlt auf ghcr.io oder ist privat | `../cloud-labs-local/02-container/publish-image.sh --tag t08`, Paket öffentlich machen |
| `/health` antwortet erst nach einer Minute | Beim ersten Start mit Datenbank lädt PlaceFinder die Orte. | warten; die Logs zeigen `Loaded … places` |
| `github-oidc`: Ressourcengruppe `rg-pf-<owner>-t08` nicht gefunden | `base` fehlt | zuerst `tools/tofu.sh 06-infrastructure-as-code/base apply` |
| Workflow: `AADSTS700213: No matching federated identity record` | Repository oder Branch passt nicht zum Federated Credential | `github_repository` genau wie auf GitHub, Branch `master` |
| `service`: `Unable to find remote state` oder fehlende Ausgaben von `base` | `base` ist noch nicht angelegt oder gelöscht | `tools/tofu.sh 06-infrastructure-as-code/base apply` |

## Aufräumen

Nach jedem Termin:

```bash
tools/tofu.sh 06-infrastructure-as-code/service destroy
```

Am Kursende, nach den Konfigurationen der späteren Termine:

```bash
tools/tofu.sh 06-infrastructure-as-code/github-oidc destroy -var github_repository=<github-user>/placefinder
tools/tofu.sh 06-infrastructure-as-code/base destroy
06-infrastructure-as-code/destroy-state.sh      # nach allen anderen destroy-Aufrufen
tools/find-leftovers.sh
```

## Fragen zum Weiterdenken

- Was steht im State, und warum gehört er nicht ins Git-Repository? Wie schützt dieses Speicherkonto ihn?
- Warum ist OIDC-Federation sicherer als ein Client Secret in den GitHub-Secrets?
- Welche Teile der Konfiguration sind anbieterspezifisch, welche ließen sich als Modul für alle drei Anbieter schreiben?
- Die Pipeline rollt aus, OpenTofu ignoriert das Image. Was ginge verloren, wenn OpenTofu auch das Image verwaltete – und was mit GitOps?
- Welches SLO würden Sie für PlaceFinder festlegen, und welche Metrik misst es?
- Was gehört in `base`, was in `service`? Woran erkennt man, dass eine Ressource zwischen den Terminen bestehen bleiben darf?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| State-Backend | S3 mit Lock-Datei | Storage Account (Blob Lease) | Cloud Storage |
| Datenbank im privaten Netz | RDS in Subnetzen ohne Route ins Internet | Flexible Server mit delegiertem Subnetz und privater DNS-Zone | Cloud SQL mit privater IP über Private Services Access |
| Datenbank-Passwort | Secrets Manager, von RDS verwaltet | Secret der Container App | Secret Manager |
| Ausrollen ohne Schlüssel | IAM-OIDC-Anbieter + Rolle | Managed Identity + Federated Credential | Workload Identity Federation |
| Native IaC | CloudFormation, CDK | Bicep | Infrastructure Manager |
| Logs und Metriken | CloudWatch, X-Ray | Azure Monitor, Application Insights | Cloud Logging, Cloud Monitoring, Cloud Trace |
