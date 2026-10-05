"""Azure Functions app (Python v2 programming model) for the daily
GeoNames update.

- geonames_daily: timer trigger, every day at 05:30 UTC
- geonames_manual: HTTP trigger for tests, POST /api/sync?date=YYYY-MM-DD

The function writes with its managed identity into the blob container
DATA_CONTAINER of the storage account DATA_ACCOUNT_URL.
"""

import json
import logging
import os

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import ContainerClient

from geonames_sync import parse_day, run

app = func.FunctionApp()


def blob_store():
    container = ContainerClient(
        account_url=os.environ["DATA_ACCOUNT_URL"],
        container_name=os.environ.get("DATA_CONTAINER", "data"),
        credential=DefaultAzureCredential(),
    )

    def store(key: str, data: bytes) -> None:
        container.upload_blob(key, data, overwrite=True)

    return store


@app.timer_trigger(schedule="0 30 5 * * *", arg_name="timer", run_on_startup=False)
def geonames_daily(timer: func.TimerRequest) -> None:
    if timer.past_due:
        logging.warning("Timer is late, running now")
    run(blob_store())


@app.route(route="sync", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def geonames_manual(req: func.HttpRequest) -> func.HttpResponse:
    result = run(blob_store(), parse_day(req.params.get("date")))
    return func.HttpResponse(json.dumps(result), mimetype="application/json")
