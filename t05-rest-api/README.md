# T05 – Neue API-Version ausrollen, testen und absichern

**Ziel:** Der Stand `t05` von PlaceFinder – die REST-API v1 mit GeoJSON, Paginierung, ETags und Fehlern nach RFC 9457 – läuft als neue Revision der Container App aus Termin 3. Ein Smoke-Test prüft die HTTP-Eigenschaften aus Termin 5 gegen die Cloud. Optional steht Azure API Management mit Abonnementschlüssel und Rate Limit davor.

| Skript | Aufgabe |
|---|---|
| `update-service.sh` | Image `t05` per Digest als neue Revision ausrollen, warten, bis sie bereit ist, Smoke-Test starten; ohne Container App aus Termin 3 legt es sie an |
| `smoke-test.sh` | REST-API prüfen: Suche, Filter, Paginierung, ETag und 304, Problem Details, CORS, veraltete Version 0 – gegen jede URL, auch lokal |
| `create-api-gateway.sh`, `destroy-api-gateway.sh` | API Management mit Rate Limit vor der App anlegen und wieder löschen |
| `rate-limit-test.sh` | viele Anfragen gleichzeitig senden und die Antworten zählen: 200 und 429 |

**Kosten:** Container App wie in Termin 3, im Freikontingent. API Management im Tarif Consumption: 1 Million Aufrufe im Monat kostenlos.

## Voraussetzungen

- Image `$PLACEFINDER_IMAGE:t05` auf ghcr.io, öffentlich. Im Terminal des Dev Containers:
  ```bash
  cd /workspaces/placefinder
  git fetch upstream --tags                # Tag t05 der Musterlösung holen
  git switch --detach t05                  # oder den eigenen Stand verwenden
  ../cloud-labs-azure/t03-container/build-image.sh --push --tag t05
  git switch master
  ```
  `build-image.sh` lädt `placefinder:0.5.0` und `placefinder:t05` hoch; `upstream` einrichten: siehe [t02-vm](../t02-vm/README.md#container-und-compose).
- Die Container App aus [t03-container](../t03-container/README.md) (Teil 2) darf noch laufen. Wurde sie gelöscht, legt `update-service.sh` sie neu an.

## Schritte

```bash
cd /workspaces/cloud-labs-azure/t05-rest-api
./update-service.sh                      # wenige Minuten, endet mit dem Smoke-Test
./smoke-test.sh                          # jederzeit wieder; ohne URL: die App aus Termin 3
./smoke-test.sh http://localhost:8000    # dieselben Prüfungen gegen den lokalen Server
```

**Digest statt Tag:** `update-service.sh` rollt `ghcr.io/<github-user>/placefinder@sha256:…` aus, nicht `…:t05`. Ein Tag lässt sich später auf ein anderes Image setzen, der Digest benennt genau dieses eine. So bleibt nachvollziehbar, welche Version läuft, und jede neue Replik startet dasselbe Image. Außerdem legt Container Apps nur bei einer Änderung des Templates eine neue Revision an – ein neu hochgeladenes `:t05` unter demselben Namen käme sonst nicht an.

**Revisionen:** Jede Änderung des Images ergibt eine neue **Revision**. Im Modus *Single* leitet Container Apps den Verkehr vollständig auf sie um, sobald sie bereit ist, und deaktiviert die alte. Im Modus *Multiple* ließe sich der Verkehr aufteilen, etwa 90 % alt und 10 % neu (Canary). Die App skaliert auf null; die erste Anfrage nach einer Pause dauert einige Sekunden.

**Smoke-Test:** Die Ausgabe zeigt je Prüfung `OK` oder `FAIL` mit dem erwarteten Wert, am Ende ein Beispiel für Problem Details. Geprüft werden Medientyp `application/geo+json`, Länge vor Breite, Umkreis und Bounding Box um Erfurt, der Link `next` im Header `Link` und im Body, `ETag` mit `304 Not Modified`, Fehler als `application/problem+json`, CORS für die Karte auf `http://localhost:5173` und die Header `Deprecation` und `Sunset` der Version 0.

**Karte mit den Daten aus der Cloud:** In PlaceFinder `python3 -m http.server 5173 --directory frontend` starten und `http://localhost:5173/?api=<SERVICE_URL>` öffnen. Die API erlaubt diese Herkunft über CORS (`CORS_ORIGINS`).

### Optional: API Management mit Rate Limit

```bash
./create-api-gateway.sh         # einige Minuten
./smoke-test.sh --gateway       # dieselben Prüfungen über API Management, mit Schlüssel
./rate-limit-test.sh            # 60 Anfragen, je 10 gleichzeitig: 200 und 429
./destroy-api-gateway.sh
```

Das Skript legt eine API-Management-Instanz im Tarif Consumption an, eine API mit dem Pfad `/placefinder` und je eine Wildcard-Operation (`/*`) für GET, POST, PUT und DELETE, die alle Anfragen an die Container App weiterreichen.

- **Abonnementschlüssel:** Die API verlangt einen Schlüssel im Header `Ocp-Apim-Subscription-Key`; ohne ihn antwortet API Management mit 401. Das Skript legt ein Abonnement für die API an und speichert den Schlüssel in `../.state/t05.env`; `--gateway` sendet ihn mit.
- **Rate Limit:** Die Richtlinie `rate-limit` erlaubt je Abonnement 30 Aufrufe in 60 Sekunden (gleitendes Fenster) und antwortet darüber mit `429 Too Many Requests` und `Retry-After`. Die Header `X-RateLimit-Limit` und `X-RateLimit-Remaining` zeigen den Stand. Richtlinien sind XML-Dokumente; im Portal stehen sie unter *APIs* → *PlaceFinder* → *All operations* → *Inbound processing*. Die az CLI hat keinen Befehl dafür, deshalb ruft das Skript die REST-API von Azure Resource Manager mit `az rest` auf.
- **Links hinter einem Präfix:** Die Links von PlaceFinder beginnen mit `/v1/…`. Hinter API Management fehlt ihnen das Präfix `/placefinder` – der Smoke-Test hängt sie an die Basis-URL an, ein Browser würde sie aber auf `https://<name>.azure-api.net/v1/…` auflösen.

Gelöschte API-Management-Instanzen bleiben 48 Stunden reserviert (Soft Delete). Wer denselben Namen sofort wieder braucht, löscht sie endgültig mit `az apim deletedservice purge`.

## Typische Probleme

- `Cannot pull … without login`: Das Image fehlt auf ghcr.io oder ist privat – siehe Voraussetzungen.
- Smoke-Test meldet Version 0.1.x und viele `FAIL`: Die App läuft noch mit dem Stand von Termin 3. Image mit `--tag t05` bauen, dann `./update-service.sh`.
- Revision wird nicht bereit: `az containerapp revision list --resource-group rg-pf-<owner>-t03 --name pf-<owner>-placefinder --output table` und `az containerapp logs show … --follow`.
- `429` im Smoke-Test über API Management: kurz nach `rate-limit-test.sh` – eine Minute warten.

## Aufräumen

```bash
./destroy-api-gateway.sh       # falls angelegt
../t03-container/destroy.sh
```

## Fragen zum Weiterdenken

- Welche Aufgaben übernimmt API Management, die sonst in der Anwendung stünden?
- Wie ließe sich mit zwei aktiven Revisionen eine neue API-Version risikoarm ausprobieren, und wie käme man zurück?
- Wie könnte PlaceFinder hinter einem Präfix richtige Links erzeugen (`X-Forwarded-Prefix`, `--root-path` von Uvicorn)?
- Wie kommt die Client-IP-Adresse durch API Management und Container Apps bis zur Anwendung (`X-Forwarded-For`)?
- Warum gehört der Abonnementschlüssel in einen Header und nicht in die URL?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| Neue Version | Canary-Deployment mit automatischem Rollback | neue Revision | neue Revision, Traffic Splitting |
| API-Gateway | API Gateway (HTTP API) | API Management (Consumption) | API Gateway |
| Rate Limit | Throttling je Stage oder Route, für alle Clients zusammen | Richtlinie `rate-limit` je Abonnement | Kontingent je Projekt des API-Keys |
| Schlüssel | API-Keys nur bei REST APIs | Abonnementschlüssel im Header `Ocp-Apim-Subscription-Key` | API-Key, hier im Header `x-api-key` |
