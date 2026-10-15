# T02 – PlaceFinder auf einer VM (IaaS)

**Ziel:** PlaceFinder v0 läuft auf einer Azure-VM. Die VM richtet sich beim ersten Start selbst ein (cloud-init): Pakete installieren, Code klonen, Abhängigkeiten mit uv installieren, GeoNames-Daten laden, Dienst starten. So wird sichtbar, was bei IaaS alles in der eigenen Verantwortung liegt.

**Kosten:** `Standard_B1s` mit 64-GB-Premium-SSD (P6) gehört zu den kostenlosen Diensten der ersten 12 Monate (750 Stunden im Monat). Die öffentliche IP-Adresse kostet wenige Cent pro Tag. Nach der Übung löschen.

## Voraussetzungen

- `t01-grundlagen` erledigt, `az login` aktiv
- SSH-Schlüssel `~/.ssh/id_ed25519`, einmalig im **Ubuntu-Terminal von WSL** angelegt, nicht im Container (siehe [t01-grundlagen](../t01-grundlagen/README.md#ssh-schlüssel-für-die-vms))
- PlaceFinder-Fork mit dem Tag `t01` unter `PLACEFINDER_REPO` (öffentlich lesbar)

## Schritte

```bash
./create-vm.sh          # oder: ./create-vm.sh <tag/branch>, Standard t01
```

Das Skript

1. legt die Ressourcengruppe `rg-pf-<owner>-t02` an,
2. legt eine Network Security Group an, die SSH (22) und die API (8000) nur von der eigenen IP-Adresse zulässt,
3. erstellt die VM mit Ubuntu 24.04 und `cloud-init.yaml` als Custom Data; `az vm create` legt dabei Virtual Network, Subnetz, Netzwerkkarte und öffentliche IP-Adresse automatisch an,
4. wartet, bis die API antwortet (erster Start ca. 3–5 Minuten).

Die VM-Größe steht in `config.env` (`VM_SIZE`, Standard `Standard_B1s`). Das Skript prüft vorab, ob die Größe in der Region für die Subscription freigegeben ist. Kurzfristige Kapazitätsengpässe zeigt Azure aber erst beim Anlegen der VM mit dem Fehler `SkuNotAvailable` („Capacity Restrictions“). Dann hilft eine andere Größe oder Region:

```bash
./destroy-vm.sh                                   # halb angelegte Ressourcengruppe löschen
# in config.env: VM_SIZE=Standard_B2ats_v2       (ebenfalls in den kostenlosen Diensten)
./create-vm.sh
```

Welche B-Größen in der Region ohne Einschränkung verfügbar sind, zeigt:

```bash
az vm list-skus -l <region> --size Standard_B --resource-type virtualMachines \
  --query "[?length(restrictions)==\`0\`].name" -o tsv
```

## Prüfen

```bash
ssh azureuser@<ip> cloud-init status --wait
ssh azureuser@<ip> journalctl -u placefinder -n 50
curl "http://<ip>:8000/places?q=Erfurt"
az resource list -g rg-pf-<owner>-t02 -o table     # was wurde alles angelegt?
```

## Aufräumen

```bash
./destroy-vm.sh         # löscht die Ressourcengruppe mit allem darin
```

## Fragen zum Weiterdenken

- Was müsste man hier selbst erledigen, was eine PaaS wie Azure App Service übernimmt?
- Welche Ressourcen hat `az vm create` neben der VM angelegt, und welche davon kosten Geld?
- Was passiert mit der Anwendung, wenn die VM neu startet? Und wenn sie gelöscht und neu angelegt wird?

## Container und Compose

Die Container-Übungen von Termin 2 hängen nicht vom Anbieter ab. Sie stehen in der README von PlaceFinder, Abschnitt *Container* (Musterlösung ab Tag `t02`):

- Dockerfile und `.dockerignore` schreiben, Image bauen, starten, Schichten ansehen (Übung im Termin)
- `compose.yaml` mit PlaceFinder und PostGIS (Selbstlernphase)
- optional: Image verkleinern und mit Trivy scannen; Image in die GitHub Container Registry laden (für Termin 3 nötig)

Alle Container-Befehle laufen im **Dev Container** (`cd /workspaces/placefinder`). Er hat eine eigene Docker Engine; einmal `docker login` ausführen, damit das Pull-Limit von Docker Hub nicht greift.

Die Musterlösung holt man so in den eigenen Fork:

```bash
cd /workspaces/placefinder
git remote add upstream https://github.com/mf-iu/placefinder.git   # einmalig
git fetch upstream --tags
git diff t02 -- Dockerfile compose.yaml      # eigene Lösung mit der Musterlösung vergleichen
```

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| VM | EC2 `t3.micro` | Virtual Machines `Standard_B1s` | Compute Engine `e2-micro` |
| Firewall | Security Group | Network Security Group | VPC-Firewall-Regel |
| Startskript | User Data (cloud-init) | Custom Data (cloud-init) | Metadaten `user-data` (cloud-init) |
