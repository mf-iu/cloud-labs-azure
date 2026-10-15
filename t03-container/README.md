# T03 – Serverless Container mit Azure Container Apps

**Ziel:** Das PlaceFinder-Image läuft auf Azure Container Apps. Container Apps baut auf Kubernetes, KEDA und Envoy auf, verbirgt den Cluster aber vollständig: Image, Port und Größe angeben genügt. Ohne Anfragen skaliert die App auf null.

**Kosten:** Im Verbrauchsmodell sind monatlich 180.000 vCPU-Sekunden, 360.000 GiB-Sekunden und 2 Millionen Anfragen kostenlos – für die Übung reicht das. Die Umgebung wird ohne Log Analytics angelegt, damit keine Kosten für Log-Speicher entstehen.

**Registry:** Die App lädt das Image direkt von ghcr.io. Eine eigene Azure Container Registry kostet auch im Tarif Basic jeden Tag Geld und ist für öffentliche Images nicht nötig. Das Paket auf GitHub muss dafür öffentlich sein.

## Schritte

```bash
./deploy.sh                       # Standard: $PLACEFINDER_IMAGE:t03
./deploy.sh ghcr.io/<user>/placefinder:<tag>
```

Das Skript registriert bei Bedarf die Anbieter `Microsoft.App` und `Microsoft.OperationalInsights`, legt die Ressourcengruppe `rg-pf-<owner>-t03`, die Umgebung `pf-<owner>-env` und die App `pf-<owner>-placefinder` mit externem HTTPS-Eingang an (0,25 vCPU, 0,5 GiB, 0 bis 2 Replikate).

## Prüfen

```bash
url=$(grep SERVICE_URL ../.state/t03.env | cut --delimiter = --fields 2)
curl "$url/health"
curl "$url/places?q=Berlin"
az containerapp replica list --resource-group rg-pf-<owner>-t03 --name pf-<owner>-placefinder --output table
az containerapp logs show --resource-group rg-pf-<owner>-t03 --name pf-<owner>-placefinder --follow
```

Nach einigen Minuten ohne Anfragen zeigt `replica list` keine Replikate mehr. Die nächste Anfrage startet wieder eines (Kaltstart, einige Sekunden).

## Aufräumen

```bash
./destroy.sh
```

Wer in Termin 5 weiterarbeiten will, kann die App stehen lassen – ohne Anfragen kostet sie nichts.

## Fragen zum Weiterdenken

- Welche Kubernetes-Begriffe aus Termin 3 finden sich in Container Apps wieder (Revision ≈ ReplicaSet, Replikat ≈ Pod, Ingress)?
- Was kostet die Skalierung auf null an Antwortzeit, und wann ist eine Mindestzahl von einem Replikat sinnvoll?
- Wann lohnt sich eine eigene Container Registry trotz der Kosten (private Images, Netzanbindung, Scans)?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Registry | Amazon ECR | Azure Container Registry (hier: ghcr.io) | Artifact Registry |
| Serverless Container | ECS Express Mode auf Fargate | Azure Container Apps | Cloud Run |
| Skalierung auf null | nein | ja | ja |
