# T04 – Netze: Virtual Network bei Azure, Diagnose, Gateway API lokal

Die Übung von Termin 4 läuft im Termin: Nach dem Entwurf auf Papier wird das Netz als Virtual Network bei Azure angelegt, mit dem Entwurf verglichen und wieder gelöscht (ca. 45 Minuten). Alles Weitere ist **Zusatz** – freiwillig und ohne Folgen für spätere Termine: Test-VMs und NAT-Gateway, Diagnose einer HTTPS-Anfrage und die Demo mit Gateway API und cert-manager im lokalen k3d-Cluster.

| Skript | Aufgabe |
|---|---|
| `create-vnet.sh` | Virtual Network mit Subnetzen und Network Security Groups (NSGs) anlegen; optional Test-VMs und NAT-Gateway |
| `check-vpc.sh` | Netz mit dem Entwurf vergleichen; mit Test-VMs auch: Was ist von wo erreichbar? |
| `destroy-vnet.sh` | Ressourcengruppe mit allem löschen |
| `diagnose.sh` | DNS, TCP, TLS und Zertifikat eines Hosts anzeigen |
| `gateway-up.sh`, `gateway-down.sh` | lokaler Cluster mit Gateway API, cert-manager und PlaceFinder über HTTPS (Dateien in `k8s/`) |

## Im Termin: Netz anlegen, prüfen, löschen

**Ziel:** ein Virtual Network `10.20.0.0/16` mit einem öffentlichen, einem Anwendungs- und einem Datenbank-Subnetz, jeweils mit eigener NSG.

**Kosten:** Virtual Network, Subnetze und NSGs sind kostenlos; ohne die Optionen `--with-vm` und `--with-nat` entsteht nichts, was Geld kostet.

### Aufbau

| Subnetz | CIDR | Standard-Internetzugang | NSG erlaubt eingehend |
|---|---|---|---|
| public | 10.20.0.0/24 | ja | 443 aus dem Internet (mit `--with-vm`: 22 von der eigenen IP) |
| app | 10.20.10.0/24 | nein (mit `--with-nat`: über NAT-Gateway) | 8000 nur aus `public` (mit `--with-vm`: 22 aus `public`) |
| db | 10.20.20.0/24 | nein | 5432 nur aus `app` |

Azure-Subnetze reichen über alle Availability Zones einer Region; eine Aufteilung nach Zonen wie bei AWS ist nicht nötig. Jede NSG enthält Standardregeln, darunter `AllowVnetInBound` mit Priorität 65000, die jeden Verkehr innerhalb des Virtual Network erlaubt. Die Regeln `deny-other-vnet` (Priorität 4000) schließen diese Lücke für `app` und `db`.

Seit dem 31. März 2026 haben neue Virtual Networks standardmäßig keinen impliziten Internetzugang mehr („Default Outbound Access“). Das Skript setzt dies für `app` und `db` ausdrücklich, damit das Verhalten unabhängig von der API-Version gleich ist.

### Anlegen

```bash
./create-vnet.sh
```

Das Skript läuft ein bis zwei Minuten und zeigt am Ende eine Übersicht der Subnetze.

### Prüfen

```bash
./check-vpc.sh
```

Das Skript vergleicht das angelegte Netz mit dem Entwurf und markiert Abweichungen mit `UNEXPECTED`:

| Prüfung | Erwartung |
|---|---|
| Adressbereich und NSG je Subnetz | `public` = `10.20.0.0/24` mit `nsg-public`, `app` = `10.20.10.0/24` mit `nsg-app`, `db` = `10.20.20.0/24` mit `nsg-db` |
| Internetzugang von `app` und `db` | keiner (`defaultOutboundAccess` aus; mit `--with-nat`: `app` über das NAT-Gateway) |
| erlaubte Regeln je NSG | `nsg-public`: 443 aus `Internet`, `nsg-app`: 8000 aus `10.20.0.0/24`, `nsg-db`: 5432 aus `10.20.10.0/24` |
| verbotene Regeln | `nsg-app` und `nsg-db`: alles aus `VirtualNetwork` (`deny-other-vnet`) |

Das Subnetz `public` hat keinen eigenen Weg ins Internet; dorthin kommt eine VM über ihre öffentliche IP-Adresse.

Zum Ausprobieren: in der Konsole des Anbieters eine Regel ändern, etwa die Datenbank aus dem ganzen Internet erlauben, und `./check-vpc.sh` erneut aufrufen. Danach die Änderung zurücknehmen.

Von Hand:

```bash
az network nsg rule list --resource-group rg-pf-<owner>-t04 --nsg-name nsg-app --include-default --output table
az network vnet subnet list --resource-group rg-pf-<owner>-t04 --vnet-name pf-<owner>-vnet --output table
```

### Aufräumen – gehört zur Übung

```bash
./destroy-vnet.sh
../tools/find-leftovers.sh
```

`destroy-vnet.sh` löscht die Ressourcengruppe `rg-pf-<owner>-t04` mit allem darin. Erst wenn beide Befehle durchgelaufen sind, ist die Übung fertig.

### Fragen zum Weiterdenken

- Warum braucht es bei Azure ausdrückliche Deny-Regeln, damit die Datenbank nur aus `app` erreichbar ist?
- Was ist der Unterschied zwischen einer NSG am Subnetz und einer NSG an der Netzwerkkarte?
- Wie würde die private VM ohne NAT-Gateway an Updates kommen?
- Wozu dienen Application Security Groups?

## Zusatz 1: Test-VMs und NAT-Gateway

**Kosten:** Die beiden Test-VMs sind in den kostenlosen Diensten enthalten (750 Stunden im Monat für die Größe aus `VM_SIZE`, zwei VMs verbrauchen doppelt), die öffentliche IP-Adresse des Bastion-Hosts kostet wenige Cent pro Tag. Das **NAT-Gateway kostet ca. 0,05 USD pro Stunde plus Datenmenge**. Am selben Tag wieder löschen.

Die Optionen gelten nur beim Anlegen; ein bestehendes Netz erst mit `./destroy-vnet.sh` löschen.

```bash
./create-vnet.sh --with-vm            # zusätzlich zwei Test-VMs
./create-vnet.sh --with-vm --with-nat # zusätzlich NAT-Gateway für "app" (kostet!)
./check-vpc.sh
```

Mit `--with-vm` entstehen zwei VMs: ein **Bastion-Host** im Subnetz `public` mit öffentlicher Adresse und eine **private VM** im Subnetz `app` ohne öffentliche Adresse. Die private VM ist nur über den Bastion-Host erreichbar (SSH-Sprung mit `-J`). Meldet Azure `SkuNotAvailable`, in `config.env` eine andere `VM_SIZE` oder `AZURE_LOCATION` eintragen, `./destroy-vnet.sh` aufrufen und neu anlegen.

Ein eigener Bastion-Host ist das klassische Muster für den Zugang zu privaten Subnetzen. Azure bietet dafür den verwalteten Dienst Azure Bastion: kein offener Port 22 an den VMs, Zugang über das Portal oder die CLI. Die Varianten Basic und Standard kosten auch ungenutzt jede Stunde; die kostenlose Variante Developer gibt es nur in einigen Regionen.

Mit Test-VMs meldet sich `check-vpc.sh` zusätzlich am Bastion-Host an, springt von dort auf die private VM und prüft vier Erwartungen an die Erreichbarkeit:

| Prüfung | ohne `--with-nat` | mit `--with-nat` |
|---|---|---|
| Bastion-Host erreicht das Internet | ja | ja |
| private VM über den Bastion-Host erreichbar | ja | ja |
| private VM erreicht das Internet | nein | ja (über das NAT-Gateway) |
| private VM direkt von hier erreichbar | nein | nein |

Die private VM löst Namen auch ohne NAT-Gateway auf – der DNS-Dienst von Azure (168.63.129.16) ist im Virtual Network immer erreichbar. Die Verbindung zur Website scheitert dann erst danach.

Von Hand:

```bash
ssh azureuser@<bastion-ip>
ssh -J azureuser@<bastion-ip> azureuser@<private-ip>
```

Die Adressen stehen in der Ausgabe von `create-vnet.sh` und in `../.state/t04.env`. Wechselt die eigene IP-Adresse (anderes WLAN), lässt `nsg-public` keine SSH-Verbindung mehr zu – dann die Regel `allow-ssh-from-my-ip` anpassen oder neu anlegen.

Danach aufräumen wie oben: `./destroy-vnet.sh`.

## Zusatz 2: Diagnose

```bash
./diagnose.sh                          # www.openstreetmap.org
./diagnose.sh https://<eigene-url>     # z. B. der Dienst aus Termin 3
```

Das Skript zeigt nacheinander die DNS-Antwort mit TTL und Resolver, die Delegation ab der Root-Zone (`dig +trace`), Verbindungsaufbau und TLS-Handshake (`curl --verbose`), die Zeit bis zu jedem Schritt (`curl --write-out`) und die Zertifikatskette (`openssl s_client`). Blockiert das Netz DNS-Anfragen an andere Server als den eigenen Resolver (manche Firmen- und Hochschulnetze), bleibt der Abschnitt `dig +trace` leer.

## Zusatz 3: Gateway API und TLS lokal

**Kosten:** keine – alles läuft im Dev Container. Der Cluster `net` hat einen Node und braucht mit allen Pods rund 1,5 GB Arbeitsspeicher; läuft der Cluster `pf` aus Termin 3 noch, ihn bei Bedarf mit `k3d cluster stop pf` anhalten.

```bash
./gateway-up.sh      # beim ersten Mal 3–5 Minuten
curl --cacert ../.state/course-ca.crt --resolve placefinder.test:8443:127.0.0.1 \
  "https://placefinder.test:8443/places?q=Erfurt"
./gateway-down.sh
```

`gateway-up.sh` baut die Demo aus Termin 4 nach und ist mehrfach aufrufbar:

1. Cluster `net` mit k3d; Port 8443 des Dev Containers führt auf Port 443 des Clusters.
2. `k8s/traefik-gw.yaml` schaltet den Gateway-API-Provider des Traefik ein, den k3s mitbringt; Traefik legt die GatewayClass `traefik` an.
3. PlaceFinder mit dem Manifest aus Termin 3 (`deploy/k8s/` im Repository `placefinder`); fehlt das Image, baut es `../t03-container/build-image.sh`.
4. cert-manager mit Helm, Gateway-API-Unterstützung über `k8s/cert-manager-values.yaml`.
5. Eine eigene Kurs-CA in `../.state/course-ca.crt` (30 Tage gültig, wird danach neu angelegt) als Secret für den ClusterIssuer `k8s/issuer.yaml`.
6. Gateway (`k8s/gateway.yaml`) und HTTPRoute (`k8s/route.yaml`); cert-manager legt das Zertifikat `pf-tls` von selbst an.
7. Eine Anfrage über HTTPS, geprüft gegen die Kurs-CA.

`--resolve` ersetzt den DNS-Eintrag für `placefinder.test` (die Endung `.test` ist für Tests reserviert), `--cacert` vertraut der Kurs-CA. Ohne `--cacert` bricht `curl` mit einem Zertifikatsfehler ab; `curl --verbose` zeigt Handshake, Zertifikat und Aussteller.

```bash
kubectl get gatewayclass,gateway,httproute
kubectl describe certificate pf-tls       # ausgestellt von course-ca, Laufzeit, Erneuerung
openssl x509 -in ../.state/course-ca.crt -noout -subject -enddate
```

**NetworkPolicies:**

```bash
kubectl apply --filename k8s/networkpolicies.yaml
curl --cacert ../.state/course-ca.crt --resolve placefinder.test:8443:127.0.0.1 \
  "https://placefinder.test:8443/places?q=Erfurt"          # geht weiter: über das Gateway
kubectl run test --rm --stdin --tty --image=busybox:1.37 -- \
  wget --timeout 3 --quiet --output-document - http://placefinder   # blockiert
kubectl delete --filename k8s/networkpolicies.yaml
```

`default-deny` verbietet allen Pods im Namespace `default` eingehenden Verkehr, `placefinder-from-gateway` erlaubt PlaceFinder Port 8000 aus dem Namespace `kube-system`, in dem Traefik läuft. k3s setzt NetworkPolicies mit einem eingebauten Controller durch.

**Typische Probleme**

- Keine GatewayClass `traefik` nach vier Minuten: `kubectl --namespace kube-system get pods` – läuft Traefik nach dem Neustart wieder?
- Zertifikat nicht `Ready`: `kubectl describe certificate pf-tls` und `kubectl --namespace cert-manager logs deployment/cert-manager`.
- `curl` erreicht nichts: Läuft der Befehl im Terminal des Dev Containers? Port 8443 gibt es nur dort.

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Netz | VPC, regional | Virtual Network, regional | VPC, global |
| Subnetz | eine Zone | alle Zonen der Region | regional |
| Reservierte Adressen je Subnetz | 5 | 5 | 4 |
| Firewall | Security Groups, Network ACLs | Network Security Groups | Firewall-Regeln mit Netzwerk-Tags |
| Ausgehend ohne öffentliche Adresse | NAT-Gateway | NAT-Gateway | Cloud NAT |
| Zugang ohne Bastion-Host | Session Manager | Azure Bastion | Identity-Aware Proxy (IAP) |
