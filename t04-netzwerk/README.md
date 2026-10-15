# T04 – Virtual Network mit öffentlichem und privaten Subnetzen

**Ziel:** Der Netzentwurf aus der Übung von Termin 4 wird als Azure Virtual Network angelegt: `10.20.0.0/16` mit einem öffentlichen, einem Anwendungs- und einem Datenbank-Subnetz, jeweils mit eigener Network Security Group (NSG).

**Kosten:** Virtual Network, Subnetze und NSGs sind kostenlos. Die optionale Test-VM ist in den kostenlosen Diensten enthalten, ihre öffentliche IP-Adresse kostet wenige Cent pro Tag. Das optionale **NAT-Gateway kostet ca. 0,05 USD pro Stunde plus Datenmenge** – am selben Tag wieder löschen.

## Aufbau

| Subnetz | CIDR | Standard-Internetzugang | NSG erlaubt eingehend |
|---|---|---|---|
| public | 10.20.0.0/24 | ja | 443 aus dem Internet (mit `--with-vm`: 22 von der eigenen IP) |
| app | 10.20.10.0/24 | nein (mit `--with-nat`: über NAT-Gateway) | 8000 nur aus `public` |
| db | 10.20.20.0/24 | nein | 5432 nur aus `app` |

Azure-Subnetze reichen über alle Availability Zones einer Region; eine Aufteilung nach Zonen wie bei AWS ist nicht nötig. Jede NSG enthält Standardregeln, darunter `AllowVnetInBound` mit Priorität 65000, die jeden Verkehr innerhalb des Virtual Network erlaubt. Die Regeln `deny-other-vnet` (Priorität 4000) schließen diese Lücke für `app` und `db`.

Seit dem 31. März 2026 haben neue Virtual Networks standardmäßig keinen impliziten Internetzugang mehr („Default Outbound Access“). Das Skript setzt dies für `app` und `db` ausdrücklich, damit das Verhalten unabhängig von der API-Version gleich ist.

## Schritte

```bash
./create-vnet.sh                      # nur das Netz
./create-vnet.sh --with-vm            # zusätzlich Test-VM im öffentlichen Subnetz
./create-vnet.sh --with-vm --with-nat # zusätzlich NAT-Gateway für "app" (kostet!)
```

## Prüfen

```bash
az network nsg rule list --resource-group rg-pf-<owner>-t04 --nsg-name nsg-db --include-default --output table
az network vnet subnet list --resource-group rg-pf-<owner>-t04 --vnet-name pf-<owner>-vnet --output table
ssh azureuser@<ip-der-test-vm>        # mit --with-vm
./diagnose.sh www.openstreetmap.org
```

`diagnose.sh` zeigt nacheinander DNS-Antworten, die Delegation ab der Root-Zone (`dig +trace`), Verbindungsaufbau und TLS-Handshake (`curl --verbose`) und die Zertifikatskette (`openssl s_client`).

## Aufräumen

```bash
./destroy-vnet.sh
```

## Fragen zum Weiterdenken

- Warum braucht es bei Azure ausdrückliche Deny-Regeln, damit die Datenbank nur aus `app` erreichbar ist?
- Was ist der Unterschied zwischen einer NSG am Subnetz und einer NSG an der Netzwerkkarte?
- Wie würde eine VM im Subnetz `app` ohne NAT-Gateway an Updates kommen?
- Wozu dienen Application Security Groups?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Netz | VPC, regional | Virtual Network, regional | VPC, global |
| Subnetz | eine Zone | alle Zonen der Region | regional |
| Reservierte Adressen je Subnetz | 5 | 5 | 4 |
| Firewall | Security Groups, Network ACLs | Network Security Groups | Firewall-Regeln mit Netzwerk-Tags |
