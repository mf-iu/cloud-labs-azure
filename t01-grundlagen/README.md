# T01 – Konto absichern, CLI und Budget-Alarm

**Ziel:** Ein kostenloses Azure-Konto mit Multi-Faktor-Authentifizierung, eine funktionierende Azure CLI im Dev Container, registrierte Ressourcenanbieter und ein Budget-Alarm, der vor unerwarteten Kosten warnt.

**Kosten:** keine.

## 1. Konto anlegen (Browser)

1. Auf <https://azure.microsoft.com/free> ein kostenloses Konto anlegen. Die Kreditkarte dient nur der Identitätsprüfung. Das Konto bekommt ein Startguthaben für **30 Tage** und eine Ausgabengrenze: Ist das Guthaben verbraucht, werden die Dienste gestoppt, aber nichts berechnet.
2. Multi-Faktor-Authentifizierung für das Microsoft-Konto einrichten (*Sicherheit* → *Erweiterte Sicherheitsoptionen*), z. B. mit der Authenticator-App oder einem Passkey.
3. Im Portal das Abonnement „Azure subscription 1“ bzw. „Kostenlose Testversion“ prüfen: *Subscriptions* → Name und ID notieren.

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
