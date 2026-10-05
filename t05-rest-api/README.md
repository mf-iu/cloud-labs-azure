# T05 – API-Version ausrollen, testen und absichern

**Ziel:** Die REST-API aus Termin 5 (Stand `t05`: GeoJSON, Paginierung, ETags, Fehler nach RFC 9457) läuft als neue Revision der Container App aus Termin 3. Ein Smoke-Test prüft die wichtigsten HTTP-Eigenschaften. Optional steht Azure API Management davor.

**Kosten:** Container App wie in Termin 3 (im Freikontingent). API Management im Tarif Consumption: die erste Million Aufrufe pro Monat kostenlos.

## Voraussetzungen

- Container App aus [t03-container](../t03-container/README.md)
- Image `$PLACEFINDER_IMAGE:t05` (öffentlich auf ghcr.io)

## Schritte

```bash
./update-service.sh          # neues Image, neue Revision
./smoke-test.sh <service-url>
```

Container Apps legt bei jeder Änderung des Images eine neue **Revision** an und leitet den Verkehr im Modus *Single* vollständig auf sie um, sobald sie bereit ist. Im Modus *Multiple* ließe sich der Verkehr aufteilen, etwa 90 % alt und 10 % neu (Canary). Die URL steht in `../.state/t03.env` (`SERVICE_URL`).

Der Smoke-Test prüft Statuscodes (200, 404, 422), eine bedingte Anfrage mit `If-None-Match` (erwartet 304) und zeigt die Fehlerantwort im Format `application/problem+json`.

### Optional: API Management

```bash
./create-api-gateway.sh      # einige Minuten
./smoke-test.sh <apim-url>/placefinder
./destroy-api-gateway.sh
```

Das Skript legt eine API-Management-Instanz im Tarif Consumption an, eine API mit dem Pfad `/placefinder` und je eine Wildcard-Operation (`/*`) für GET, POST, PUT und DELETE, die alle Anfragen an die Container App weiterreichen. Ein Abonnement-Schlüssel ist für die Übung abgeschaltet.

Rate Limits, Authentifizierung mit JWT oder das Umschreiben von Headern sind in API Management **Richtlinien** (XML), die im Portal unter *APIs* → *PlaceFinder* → *All operations* → *Inbound processing* eingetragen werden. Welche Richtlinien im Tarif Consumption verfügbar sind, steht in der Richtlinienreferenz.

Gelöschte API-Management-Instanzen bleiben 48 Stunden reserviert (Soft Delete). Wer denselben Namen sofort wieder braucht, löscht sie endgültig mit `az apim deletedservice purge`.

## Aufräumen

```bash
./destroy-api-gateway.sh       # falls angelegt
../t03-container/destroy.sh
```

## Fragen zum Weiterdenken

- Welche Aufgaben übernimmt API Management, die sonst in der Anwendung stünden?
- Wie ließe sich mit zwei aktiven Revisionen eine neue API-Version risikoarm ausprobieren?
- Wie kommt die Client-IP-Adresse durch API Management und Container Apps bis zur Anwendung (`X-Forwarded-For`)?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Neue Version | Express Mode, Canary | Revision | Revision, Traffic Splitting |
| API-Gateway | API Gateway (HTTP API) | API Management (Consumption) | API Gateway |
| Rate Limit | Throttling je Stage oder Route | Richtlinie | Kontingente mit API-Keys |
