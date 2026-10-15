# T11 – Modell als Service

**Ziel:** Das Modell zur Einwohnerschätzung aus Termin 11 wird als Endpunkt `/estimate` von PlaceFinder bereitgestellt. MLflow speichert Experimente lokal und Artefakte im Blob Storage; das freigegebene Modell liegt unter `models/` im selben Container. Die Container App liest es mit ihrer Managed Identity (Rolle *Storage Blob Data Reader*).

**Kosten:** Container App mit 0,5 vCPU und 1 GiB im Freikontingent, solange sie wenig genutzt wird und auf null skaliert. Managed-ML-Plattformen (Azure Machine Learning) werden nur vorgestellt, weil Rechenressourcen und Endpunkte dort schnell Kosten verursachen.

## Schritte

```bash
cd ..
tools/tofu.sh t11-ml/infra apply           # Speicherkonto, Container App mit Image :t11, Rollen
tools/tofu.sh t11-ml/infra output
```

MLflow lokal mit Artefakten im Blob Storage:

```bash
account=$(tools/tofu.sh t11-ml/infra output -raw storage_account)
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name "$account" --output tsv)
uvx --with azure-storage-blob --with azure-identity mlflow server \
  --backend-store-uri sqlite:///.state/mlflow.db \
  --artifacts-destination "$(tools/tofu.sh t11-ml/infra output -raw mlflow_artifacts_destination)" \
  --port 5000
```

Training im Notebook von Termin 11 mit `mlflow.set_tracking_uri("http://localhost:5000")`. Das beste Modell exportieren und hochladen:

```bash
t11-ml/upload-model.sh model.joblib       # startet eine neue Revision, die das Modell lädt
curl "$(tools/tofu.sh t11-ml/infra output -raw service_url)/estimate?lat=50.98&lon=11.03"
```

PlaceFinder liest beim Start `MODEL_URI` (die HTTPS-Adresse des Blobs) mit der Managed Identity. `upload-model.sh` setzt dazu eine Umgebungsvariable mit dem Zeitpunkt des Uploads, wodurch eine neue Revision startet. Diese Änderung kennt OpenTofu nicht; das nächste `apply` zeigt sie als Abweichung.

## Aufräumen

```bash
tools/tofu.sh t11-ml/infra destroy
```

## Fragen zum Weiterdenken

- Welche Informationen braucht man, um ein Modell später nachvollziehen zu können (Daten, Code, Parameter, Metriken)?
- Wie würde man mit zwei Revisionen ein neues Modell schrittweise ausrollen und mit dem alten vergleichen?
- Was bietet Azure Machine Learning zusätzlich (Registry, Pipelines, Online-Endpunkte), und was kostet das?

## Andere Anbieter

| | AWS | Azure | Google Cloud |
|---|---|---|---|
| ML-Plattform | SageMaker AI | Azure Machine Learning | Vertex AI |
| Modell-Endpunkt hier | ECS Express Mode | Container Apps | Cloud Run |
| Rechte des Dienstes | Task Role | Managed Identity | Service Account |
