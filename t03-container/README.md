# T03 – Kubernetes lokal und Serverless Container

Zwei Teile: In der Übung läuft PlaceFinder in einem lokalen Kubernetes-Cluster, den k3d im Dev Container anlegt. In der Selbstlernphase läuft das Image auf **Azure Container Apps**.

## Teil 1: Kubernetes lokal mit k3d (Übung)

**Kosten:** keine – alles läuft im Dev Container. Drei Nodes brauchen zusammen rund 1,5 bis 2 GB Arbeitsspeicher; unter WSL ggf. die Grenze in `.wslconfig` erhöhen.

| Skript | Aufgabe |
|---|---|
| `cluster-up.sh` | Cluster `pf` anlegen (1 Server, 2 Agents, k3s 1.36) oder wieder starten |
| `build-image.sh` | Image `placefinder:<version>` aus `../placefinder` bauen und in die Nodes laden; mit `--push` zusätzlich als `:<version>` und `:t03` nach ghcr.io (Teil 2; `--tag t05` für den Stand von Termin 5) |
| `cluster-down.sh` | Cluster löschen; die Images bleiben in Docker |

```bash
cd /workspaces/cloud-labs-azure/t03-container
./cluster-up.sh                         # beim ersten Mal 1–2 Minuten (k3s-Image laden)
./build-image.sh                        # placefinder:0.1.0, Version aus pyproject.toml
cd /workspaces/placefinder
kubectl apply --filename deploy/k8s/    # eigenes Manifest aus der Übung
kubectl get pods --output wide          # drei Pods, verteilt auf die Nodes
kubectl port-forward svc/placefinder 8000:80
```

Wie es weitergeht – neue Version ausrollen, Konfiguration ändern, Helm-Chart, Autoscaler – steht im README von PlaceFinder, Abschnitt *Kubernetes*. Die Musterlösung liegt im Tag `t03` von PlaceFinder: `git fetch upstream --tags`, dann `git diff t03 -- deploy/` (`upstream` einrichten: siehe [t02-vm](../t02-vm/README.md#container-und-compose)).

**Typische Probleme**

- `ErrImagePull` oder `ImagePullBackOff`: Das Image ist nicht in den Nodes. `./build-image.sh` nach `./cluster-up.sh` ausführen; Tag im Manifest und Version müssen übereinstimmen.
- Pods bleiben `Pending`: zu wenig Speicher, `kubectl describe pod <name>` zeigt den Grund.
- Nach einem Neubau des Dev Containers kennt `kubectl` den Cluster nicht mehr: `./cluster-up.sh` startet ihn und trägt ihn wieder ein.

Aufräumen nach der Selbstlernphase: `./cluster-down.sh`.

## Teil 2: Azure Container Apps (Selbstlernphase)

**Ziel:** Das PlaceFinder-Image läuft auf Azure Container Apps. Container Apps baut auf Kubernetes, KEDA und Envoy auf, verbirgt den Cluster aber vollständig: Image, Port und Größe angeben genügt. Ohne Anfragen skaliert die App auf null.

**Kosten:** Im Verbrauchsmodell sind monatlich 180.000 vCPU-Sekunden, 360.000 GiB-Sekunden und 2 Millionen Anfragen kostenlos – für die Übung reicht das. Die Umgebung wird ohne Log Analytics angelegt, damit keine Kosten für Log-Speicher entstehen.

**Registry:** Die App lädt das Image direkt von ghcr.io. Eine eigene Azure Container Registry kostet auch im Tarif Basic jeden Tag Geld und ist für öffentliche Images nicht nötig. Das Paket auf GitHub muss dafür öffentlich sein: `./build-image.sh --push`, danach auf GitHub *Packages* → *placefinder* → *Package settings* → *Change visibility*. `deploy.sh` prüft das vor dem Anlegen.

### Schritte

```bash
./deploy.sh                       # Standard: $PLACEFINDER_IMAGE:t03
./deploy.sh ghcr.io/<user>/placefinder:<tag>
```

Das Skript registriert bei Bedarf die Anbieter `Microsoft.App` und `Microsoft.OperationalInsights`, legt die Ressourcengruppe `rg-pf-<owner>-t03`, die Umgebung `pf-<owner>-env` und die App `pf-<owner>-placefinder` mit externem HTTPS-Eingang an (0,25 vCPU, 0,5 GiB, 0 bis 2 Replikate).

### Prüfen

```bash
url=$(grep SERVICE_URL ../.state/t03.env | cut --delimiter = --fields 2)
curl "$url/health"
curl "$url/places?q=Erfurt"
az containerapp replica list --resource-group rg-pf-<owner>-t03 --name pf-<owner>-placefinder --output table
az containerapp logs show --resource-group rg-pf-<owner>-t03 --name pf-<owner>-placefinder --follow
```

Nach einigen Minuten ohne Anfragen zeigt `replica list` keine Replikate mehr. Die nächste Anfrage startet wieder eines (Kaltstart, einige Sekunden).

### Aufräumen

```bash
./destroy.sh
```

Wer in Termin 5 weiterarbeiten will, kann die App stehen lassen – ohne Anfragen kostet sie nichts.

### Fragen zum Weiterdenken

- Welche Kubernetes-Begriffe aus Termin 3 finden sich in Container Apps wieder (Revision ≈ ReplicaSet, Replikat ≈ Pod, Ingress)?
- Was kostet die Skalierung auf null an Antwortzeit, und wann ist eine Mindestzahl von einem Replikat sinnvoll?
- Wann lohnt sich eine eigene Container Registry trotz der Kosten (private Images, Netzanbindung, Scans)?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Registry | Amazon ECR | Azure Container Registry (hier: ghcr.io) | Artifact Registry |
| Serverless Container | ECS Express Mode auf Fargate | Azure Container Apps | Cloud Run |
| Skalierung auf null | nein | ja | ja |
