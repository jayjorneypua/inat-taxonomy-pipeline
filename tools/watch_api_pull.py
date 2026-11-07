import json
import sys
import time
from datetime import datetime
from pathlib import Path

import requests
from databricks.sdk import WorkspaceClient

# reuse the loader's scope so the watcher always counts the same thing
sys.path.append(str(Path(__file__).resolve().parent.parent / "ingestion"))
from pull_api_observations import API_URL, PAGE_SIZE, SCOPE_PARAMETERS, USER_AGENT

PROFILE = "dbc-609647e1-c073"
STATE_PATH = "/Volumes/inat/raw/files/_state/api_observations.json"
POLL_SECONDS = 30


def read_state(workspace_client):
    download = workspace_client.files.download(STATE_PATH)
    return json.loads(download.contents.read())


def count_remaining(updated_since, last_id):
    params = {
        **SCOPE_PARAMETERS,
        "updated_since": updated_since,
        "id_above": last_id,
        "per_page": 0,
    }
    response = requests.get(
        API_URL, params=params, timeout=60, headers={"User-Agent": USER_AGENT}
    )
    response.raise_for_status()
    return response.json()["total_results"]


def watch():
    workspace_client = WorkspaceClient(profile=PROFILE)
    previous_pages_written = None
    previous_check_time = None
    saw_a_run = False

    print(f"watching {STATE_PATH}, checking every {POLL_SECONDS}s, ctrl+c to stop")

    while True:
        check_time = time.time()
        clock = datetime.now().strftime("%H:%M:%S")
        state = read_state(workspace_client)
        current_run = state["current_run"]

        if current_run is None:
            if saw_a_run:
                print(f"{clock}  run finished, new watermark {state['watermark']}")
                break
            print(f"{clock}  no run in progress, watermark {state['watermark']}")
            time.sleep(POLL_SECONDS)
            continue

        saw_a_run = True
        pages_written = current_run["pages_written"]
        remaining_observations = count_remaining(
            current_run["updated_since"], current_run["last_id"]
        )
        pages_left = -(-remaining_observations // PAGE_SIZE)

        progress_line = (
            f"{clock}  page {pages_written:,}"
            f"  last id {current_run['last_id']:,}"
            f"  ~{remaining_observations:,} left (~{pages_left:,} pages)"
        )

        if previous_pages_written is not None:
            new_pages = pages_written - previous_pages_written
            minutes_since_last_check = (check_time - previous_check_time) / 60

            if new_pages == 0:
                progress_line += "  no new pages since last check"
            else:
                pages_per_minute = new_pages / minutes_since_last_check
                minutes_left = pages_left / pages_per_minute
                progress_line += f"  {pages_per_minute:.0f} pages/min, ~{minutes_left:.0f} min left"

        print(progress_line)
        previous_pages_written = pages_written
        previous_check_time = check_time
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    watch()