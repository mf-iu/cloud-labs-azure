# T02 – PlaceFinder auf einer VM (IaaS)

**Ziel:** PlaceFinder v0 läuft auf einer Azure-VM. Die VM richtet sich beim ersten Start selbst ein (cloud-init): Pakete installieren, Code klonen, Abhängigkeiten mit uv installieren, GeoNames-Daten laden, Dienst starten. So wird sichtbar, was bei IaaS alles in der eigenen Verantwortung liegt.

**Kosten:** `Standard_B1s` mit 64-GB-Premium-SSD (P6) gehört zu den kostenlosen Diensten der ersten 12 Monate (750 Stunden im Monat). Die öffentliche IP-Adresse kostet wenige Cent pro Tag. Nach der Übung löschen.

## Voraussetzungen

- `t01-grundlagen` erledigt, `az login` aktiv
- SSH-Schlüssel: `ssh-keygen -t ed25519` (Pfad in `config.env`, `SSH_PUBLIC_KEY`)
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

Ist `Standard_B1s` in der Region gerade nicht verfügbar, hilft eine andere Region in `config.env` oder eine andere Größe: `VM_SIZE=Standard_B2ats_v2 ./create-vm.sh` (ebenfalls in den kostenlosen Diensten enthalten).

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

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| VM | EC2 `t3.micro` | Virtual Machines `Standard_B1s` | Compute Engine `e2-micro` |
| Firewall | Security Group | Network Security Group | VPC-Firewall-Regel |
| Startskript | User Data (cloud-init) | Custom Data (cloud-init) | Metadaten `user-data` (cloud-init) |
