# T08 – Infrastruktur als Code mit OpenTofu

**Ziel:** Die Infrastruktur der Zwischenpräsentation entsteht reproduzierbar aus Code: Ressourcengruppe, Virtual Network mit NSGs, Speicherkonto und PlaceFinder auf Container Apps, optional mit Datenbank. Der State liegt versioniert im Blob Storage. Außerdem darf eine GitHub-Actions-Pipeline ohne gespeicherte Secrets ausrollen (OIDC-Federation mit einer Managed Identity).

**Kosten:** Im Freikontingent von Container Apps und Blob Storage; die Datenbank (`enable_database=true`) im Rahmen der kostenlosen 750 Stunden. Nach dem Test `destroy` ausführen.

## Voraussetzungen

- OpenTofu ab 1.10 (`tofu version`)
- `az login` aktiv, Ressourcenanbieter registriert (`t01-grundlagen/register-providers.sh`)
- Image `$PLACEFINDER_IMAGE:t07` öffentlich auf ghcr.io (oder ein anderer Tag über `-var image_tag=…`)

## 1. Remote State einrichten (einmalig)

```bash
./bootstrap-state.sh
```

Das Skript legt die Ressourcengruppe `rg-pf-<owner>-tfstate` mit einem Speicherkonto an (Blob-Versionierung aktiv, Container `tfstate`) und schreibt `../.state/backend.hcl`. Gesperrt wird der State über eine Lease auf dem Blob. Das Speicherkonto entsteht mit der CLI, weil OpenTofu seinen State-Speicher nicht verwalten kann, bevor es ihn gibt.

## 2. Infrastruktur ausrollen

```bash
cd ..
tools/tofu.sh t08-iac/infra plan      # beim ersten Aufruf mit init
tools/tofu.sh t08-iac/infra apply
tools/tofu.sh t08-iac/infra output
```

`tools/tofu.sh` setzt `ARM_SUBSCRIPTION_ID` und die Variablen `prefix`, `owner`, `suffix`, `location`, `placefinder_image` und `admin_cidrs` (eigene IP-Adresse) aus `config.env` und verwendet für jeden Ordner einen eigenen State-Schlüssel.

| Datei | Inhalt |
|---|---|
| `infra/network.tf` | Ressourcengruppe, Virtual Network, Subnetze und NSG-Regeln wie in Termin 4 |
| `infra/storage.tf` | Speicherkonto und Container für Daten |
| `infra/service.tf` | Container-Apps-Umgebung und PlaceFinder |
| `infra/database.tf` | optional: PostgreSQL Flexible Server mit PostGIS-Freigabe (`-var enable_database=true`) |
| `infra/outputs.tf` | URL, Namen, Verbindungszeichenkette |

Mit Datenbank:

```bash
tools/tofu.sh t08-iac/infra apply -var enable_database=true
tools/tofu.sh t08-iac/infra output -raw database_url
```

Die Datenbank ist wie in Termin 6 nur von der eigenen IP-Adresse aus erreichbar. Den Dienst mit der Datenbank zu verbinden, ist Teil der Übung: entweder über VNet-Integration (Container-Apps-Umgebung mit `infrastructure_subnet_id`, Server im delegierten Subnetz `db`) oder vorübergehend über eine Firewall-Regel; die Verbindungszeichenkette gehört als Secret in die Container App oder in Key Vault.

### Ausprobieren

- Eine Einstellung ändern (z. B. `max_replicas`) und `plan` lesen: Was ändert sich, was wird ersetzt?
- Im Portal etwas von Hand ändern und mit `plan` die Abweichung (Drift) finden.
- `destroy` und `apply` hintereinander ausführen: Ist alles wieder gleich?

## 3. GitHub Actions ohne Secrets (OIDC)

```bash
tools/tofu.sh t08-iac/github-oidc apply -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/github-oidc output
```

Die Konfiguration legt in `rg-pf-<owner>-cicd` eine benutzerseitig zugewiesene Managed Identity an. Ein Federated Credential erlaubt nur Workflows auf dem Branch `master` des genannten Repositorys, sich als diese Identität anzumelden. Sie erhält die Rolle *Contributor*, aber nur auf der Ressourcengruppe von `t08-iac/infra` – deshalb zuerst `infra` ausrollen.

In den eigenen PlaceFinder-Fork übernehmen:

1. `deploy.example.yml` als `.github/workflows/deploy.yml`
2. Repository-Variablen (*Settings* → *Secrets and variables* → *Actions* → *Variables*): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` aus `github-oidc`, `RESOURCE_GROUP` und `CONTAINER_APP` aus `infra`

Der Workflow schiebt das Image mit dem `GITHUB_TOKEN` nach ghcr.io und aktualisiert die Container App. Rollt die Pipeline ein neues Image aus, weicht die App von der OpenTofu-Konfiguration ab; das nächste `apply` würde wieder `image_tag` setzen – ein gutes Beispiel für Drift.

## Aufräumen

```bash
tools/tofu.sh t08-iac/github-oidc destroy -var github_repository=<github-user>/placefinder
tools/tofu.sh t08-iac/infra destroy
t08-iac/destroy-state.sh      # erst am Kursende, nach allen anderen destroy-Aufrufen
```

## Fragen zum Weiterdenken

- Was steht im State, und warum gehört er nicht ins Git-Repository?
- Warum ist OIDC-Federation sicherer als ein Service Principal mit Client Secret in den GitHub-Secrets?
- Welche Teile der Konfiguration sind anbieterspezifisch, welche ließen sich als Modul für alle drei Anbieter schreiben?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| State-Backend | S3 mit Lock-Datei | Storage Account (Blob Lease) | Cloud Storage |
| Keyless CI/CD | IAM-OIDC-Anbieter + Rolle | Managed Identity + Federated Credential | Workload Identity Federation |
| Native IaC | CloudFormation, CDK | Bicep | Infrastructure Manager |
