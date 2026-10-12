# T01 – Konto absichern, CLI und Budget-Alarm

**Ziel:** Ein kostenloses Azure-Konto mit Multi-Faktor-Authentifizierung, eine funktionierende Azure CLI im Dev Container, registrierte Ressourcenanbieter und ein Budget-Alarm, der vor unerwarteten Kosten warnt.

**Kosten:** keine.

## 1. Konto anlegen (Browser)

Zeitbedarf ca. 15 Minuten. Bereithalten: ein Microsoft-Konto (oder eine E-Mail-Adresse, um eines anzulegen), ein Mobiltelefon, eine Kredit- oder Debitkarte (keine Prepaid-Karte) und die Authenticator-App oder einen Passkey. Pro Person gibt es nur ein kostenloses Konto.

### 1.1 Microsoft-Konto absichern

Das Azure-Konto hängt an einem Microsoft-Konto; wer dieses kennt, kann über das Azure-Guthaben verfügen. Deshalb zuerst auf <https://account.microsoft.com/security> die **zweistufige Überprüfung** einschalten, z. B. mit der Authenticator-App oder einem Passkey. Azure verlangt MFA ohnehin: für das Portal seit 2024, für Azure CLI und PowerShell seit Oktober 2025.

### 1.2 Registrieren

1. <https://azure.microsoft.com/free> öffnen und *Kostenlos testen* bzw. *Try Azure for free* wählen.
2. Mit dem Microsoft-Konto anmelden.
3. Im Profil **Land/Region Deutschland** wählen – das Land bestimmt die Währung des Abonnements (Euro) und lässt sich später nicht ändern. Name, E-Mail-Adresse und Telefonnummer eintragen.
4. Die Telefonnummer bestätigen (Code per SMS oder Anruf).
5. Die Karte eingeben. Sie dient der Identitätsprüfung; berechnet wird nichts, die Bank zeigt eventuell eine vorübergehende Vormerkung von rund 1 Euro.
6. Den Vertrag akzeptieren und *Registrieren* wählen. Danach öffnet sich das Portal <https://portal.azure.com>.
7. Prüfen: *Abonnements* (*Subscriptions*) zeigt „Azure subscription 1“ mit dem Angebot *Kostenlose Testversion* (*Free Trial*). Name und Abonnement-ID notieren. Das Restguthaben zeigt *Cost Management* → *Guthaben* (*Credits*).

### 1.3 Was das kostenlose Konto bedeutet

- **Guthaben:** 200 USD (in Euro umgerechnet) für die ersten **30 Tage**; dazu ausgewählte Dienste 12 Monate lang und mehr als 65 Dienste dauerhaft im kostenlosen Umfang.
- **Ausgabengrenze:** Das Konto kann nichts berechnen. Ist das Guthaben verbraucht oder sind 30 Tage um, wird das Abonnement deaktiviert: VMs werden angehalten, Daten in Speicherkonten sind nur noch lesbar.
- **Nach 30 Tagen:** Der Kurs dauert länger. Um weiterzuarbeiten, das Konto auf **Pay-as-you-go** umstellen, sobald Azure dazu auffordert (Portal: *Abonnements* → *Upgrade*). Nicht vorher: Bei der Umstellung entfällt die Ausgabengrenze, ab dann kostet alles Geld, was über die kostenlosen Mengen hinausgeht. Spätestens dann sind der Budget-Alarm (Abschnitt 3) und das Aufräumen nach jeder Übung unverzichtbar.
- **Azure for Students:** Wer an einer Hochschule eingeschrieben ist, kann stattdessen <https://azure.microsoft.com/free/students> nutzen: 100 USD für 12 Monate, ohne Kreditkarte, mit der Hochschul-E-Mail-Adresse. Das Guthaben ist eine harte Grenze. Allerdings unterstützt Cost Management dieses Angebot nicht, `create-budget.sh` funktioniert dort also nicht; das Restguthaben zeigt im Portal der *Education*-Hub.

Für die tägliche Arbeit genügt bei Azure das eigene Konto mit MFA. In Unternehmen arbeitet man mit eigenen Benutzern in Microsoft Entra ID und vergibt Rollen (Azure RBAC) pro Abonnement oder Ressourcengruppe.

## 2. CLI anmelden (Dev Container)

Im Terminal des Dev Containers (siehe [README](../README.md#arbeitsumgebung-dev-container)):

```bash
cd /workspaces/cloud-labs-azure/t01-grundlagen   # Ordner dieser Übung
cp -i ../config.example.env ../config.env        # OWNER, ALERT_EMAIL usw. eintragen
az login --use-device-code
./check-cli.sh
./register-providers.sh                          # einmalig, dauert einige Minuten
```

`cp -i` fragt nach, falls `config.env` schon existiert (z. B. aus der Einrichtung im [README](../README.md#einrichtung)); dann mit `n` antworten und die vorhandene Datei behalten.

`az login --use-device-code` zeigt einen Code und eine URL; die Anmeldung erfolgt im Browser auf dem Notebook. Bei mehreren Abonnements das gewünschte in `config.env` (`AZURE_SUBSCRIPTION`) eintragen.

Azure-Dienste gehören zu **Ressourcenanbietern** (z. B. `Microsoft.App` für Container Apps). Ein neues Abonnement muss jeden Anbieter einmal registrieren; das Skript erledigt das für alle Dienste des Kurses.

### SSH-Schlüssel für die VMs

Ab Termin 2 melden sich die Skripte per SSH an den VMs an. Den Schlüssel am besten gleich jetzt anlegen – **im Ubuntu-Terminal von WSL, nicht im Terminal des Containers.**

Warum: Der Ordner `~/.ssh` gehört zu WSL. Der Dev Container bindet ihn nur ein, damit die Schlüssel einen Neubau des Containers überstehen; im Container scheitert `ssh-keygen` daran. In WSL gehört der Ordner dem eigenen Benutzer, dort funktioniert es.

1. Das Ubuntu-Terminal öffnen: im Startmenü von Windows *Ubuntu* bzw. *Ubuntu 24.04* oder ein neues Ubuntu-Fenster im Windows-Terminal. Die Eingabeaufforderung zeigt `<benutzer>@<rechner>:~$`, nicht `vscode ➜ /workspaces/…`.
2. Den Schlüssel anlegen:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
   ```

   Die Passphrase darf leer bleiben (zweimal Enter). Gibt es den Schlüssel schon, fragt `ssh-keygen`, ob er überschrieben werden soll – dann mit `n` antworten und den vorhandenen verwenden.
3. Zurück im Container: Der Schlüssel liegt dort sofort unter `/home/vscode/.ssh/id_ed25519`, ein Neustart ist nicht nötig. Prüfen mit `ls ~/.ssh` im Terminal des Containers. `SSH_PUBLIC_KEY` in `config.env` zeigt bereits auf `~/.ssh/id_ed25519.pub`.

## 3. Budget-Alarm

```bash
./create-budget.sh      # Monatsbudget BUDGET_AMOUNT aus config.env, Standard 10
```

Azure schickt eine E-Mail auf Deutsch an `ALERT_EMAIL`, wenn die tatsächlichen Kosten 50 % und 80 % des Budgets überschreiten oder die Prognose 100 % erreicht. Der Betrag gilt in der Währung des Abonnements. Die Azure CLI hat keinen vollständigen Befehl für Budgets mit Benachrichtigungen; das Skript ruft deshalb die REST-API von Cost Management mit `az rest` auf – ein gutes Beispiel dafür, dass jede CLI letztlich nur eine REST-API bedient.

Kontrolle im Portal: *Cost Management* → *Budgets*. Ein zweiter Aufruf ändert nichts; zum Ändern erst `./delete-budget.sh`, dann wieder `./create-budget.sh`. Endgültig löschen erst am Kursende.

## Fragen zum Weiterdenken

- Was passiert nach 30 Tagen mit dem Konto, und was ändert sich bei der Umstellung auf Pay-as-you-go?
- Warum ist ein Budget-Alarm keine Kostenbremse?
- Wie unterscheiden sich Microsoft Entra ID (Identitäten) und Azure RBAC (Rechte auf Ressourcen)?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Anmeldung der CLI | `aws login` | `az login` | `gcloud auth login` |
| Budget | AWS Budgets | Cost Management Budgets | Cloud Billing Budgets |
| Gruppierung | Konto, Tags | Abonnement, Ressourcengruppe | Projekt, Labels |
