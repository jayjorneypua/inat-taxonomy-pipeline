import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
from databricks.sdk import WorkspaceClient

# reuse the loader's scope so the watcher always counts the same thing
sys.path.append(str(Path(__file__).resolve().parent.parent / "ingestion"))
from pull_api_observations import (
    API_URL,
    PAGE_SIZE,
    SCOPE_PARAMETERS,
    TIMESTAMP_FORMAT,
    USER_AGENT,
)

PROFILE = "dbc-609647e1-c073"
JOB_NAME = "inat_taxonomy_pipeline"
API_TASK_KEY = "pull_api_observations"
STATE_PATH = "/Volumes/inat/raw/files/_state/api_observations.json"
POLL_SECONDS = 10
POLLS_BETWEEN_PROGRESS_LINES = 3
FINISHED_RUN_STATES = {"TERMINATED", "SKIPPED", "INTERNAL_ERROR"}
FAILED_TASK_STATES = {"FAILED", "TIMEDOUT", "INTERNAL_ERROR"}
FRIENDLY_STATUS_NAMES = {
    "QUEUED": "queued, waiting for compute",
    "PENDING": "starting",
}


def clock():
    return datetime.now().strftime("%H:%M:%S")


def local_clock(utc_text):
    utc_time = datetime.strptime(utc_text, TIMESTAMP_FORMAT).replace(tzinfo=timezone.utc)
    return utc_time.astimezone().strftime("%H:%M:%S")


def find_job_id(workspace_client):
    for job in workspace_client.jobs.list(name=JOB_NAME):
        return job.job_id
    raise RuntimeError(f"job {JOB_NAME} not found, deploy the bundle first")


def wait_for_active_run(workspace_client, job_id):
    print(f"{clock()}  waiting for a {JOB_NAME} run to start")
    while True:
        for run in workspace_client.jobs.list_runs(job_id=job_id, active_only=True):
            return run.run_id
        time.sleep(POLL_SECONDS)


def task_status(task):
    if task.state is None or task.state.life_cycle_state is None:
        return "PENDING"
    life_cycle_state = task.state.life_cycle_state.value
    if life_cycle_state == "TERMINATED" and task.state.result_state is not None:
        return task.state.result_state.value
    return life_cycle_state


def display_status(task, statuses_by_task):
    status = statuses_by_task[task.task_key]
    if status == "BLOCKED":
        # list only the upstream tasks that have not finished yet
        unfinished_dependencies = [
            dependency.task_key
            for dependency in task.depends_on or []
            if statuses_by_task.get(dependency.task_key) != "SUCCESS"
        ]
        return "waiting for " + ", ".join(unfinished_dependencies) if unfinished_dependencies else "waiting"
    return FRIENDLY_STATUS_NAMES.get(status, status)


def first_error_line(workspace_client, task):
    # the real error is in the task output, the task state only says "workload failed"
    try:
        error_text = workspace_client.jobs.get_run_output(task.run_id).error
    except Exception:
        error_text = None
    error_text = error_text or task.state.state_message or "no error message"
    return error_text.strip().splitlines()[0][:300]


def read_state(workspace_client):
    download = workspace_client.files.download(STATE_PATH)
    return json.loads(download.contents.read())


def print_new_events(state, last_seen_sequence):
    for event in state.get("recent_events", []):
        if event["sequence"] > last_seen_sequence:
            print(f"{local_clock(event['logged_at'])}  {API_TASK_KEY}: {event['message']}")
            last_seen_sequence = event["sequence"]
    return last_seen_sequence


def count_remaining(updated_since, last_id):
    parameters = {
        **SCOPE_PARAMETERS,
        "updated_since": updated_since,
        "id_above": last_id,
        "per_page": 0,
    }
    response = requests.get(
        API_URL, params=parameters, timeout=60, headers={"User-Agent": USER_AGENT}
    )
    response.raise_for_status()
    return response.json()["total_results"]


def watch():
    workspace_client = WorkspaceClient(profile=PROFILE)
    job_id = find_job_id(workspace_client)
    run_id = wait_for_active_run(workspace_client, job_id)
    print(f"{clock()}  watching run {run_id}, checking every {POLL_SECONDS}s, ctrl+c to stop")

    last_seen_sequence = read_state(workspace_client).get("last_event_sequence", 0)
    displayed_statuses = {}
    poll_count = 0
    previous_pages_written = None
    previous_check_time = None

    while True:
        run = workspace_client.jobs.get_run(run_id)
        tasks = run.tasks or []

        # api pull events first (pages, retries, failures), they carry their own timestamps
        state = read_state(workspace_client)
        last_seen_sequence = print_new_events(state, last_seen_sequence)

        # then every task whose status changed since the last check
        statuses_by_task = {task.task_key: task_status(task) for task in tasks}
        for task in tasks:
            status_text = display_status(task, statuses_by_task)
            if displayed_statuses.get(task.task_key) != status_text:
                displayed_statuses[task.task_key] = status_text
                status_line = f"{clock()}  {task.task_key}: {status_text}"
                if statuses_by_task[task.task_key] in FAILED_TASK_STATES:
                    status_line += f"  {first_error_line(workspace_client, task)}"
                print(status_line)

        # api pull progress, every few checks while it runs
        current_run = state["current_run"]
        if statuses_by_task.get(API_TASK_KEY) == "RUNNING" and current_run is not None:
            if poll_count % POLLS_BETWEEN_PROGRESS_LINES == 0:
                check_time = time.time()
                pages_written = current_run["pages_written"]
                remaining_observations = count_remaining(
                    current_run["updated_since"], current_run["last_id"]
                )
                pages_left = -(-remaining_observations // PAGE_SIZE)
                progress_line = (
                    f"{clock()}  {API_TASK_KEY}: progress page {pages_written:,}"
                    f", ~{remaining_observations:,} left (~{pages_left:,} pages)"
                )
                if previous_pages_written is not None and pages_written > previous_pages_written:
                    pages_per_minute = (pages_written - previous_pages_written) / (
                        (check_time - previous_check_time) / 60
                    )
                    progress_line += f", {pages_per_minute:.0f} pages/min, ~{pages_left / pages_per_minute:.0f} min left"
                print(progress_line)
                previous_pages_written = pages_written
                previous_check_time = check_time

        # stop once the whole run is over
        run_life_cycle_state = run.state.life_cycle_state.value
        if run_life_cycle_state in FINISHED_RUN_STATES:
            run_result = run.state.result_state.value if run.state.result_state else run_life_cycle_state
            print(f"{clock()}  run finished: {run_result}")
            break

        poll_count += 1
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    watch()