import json
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests

API_URL = "https://api.inaturalist.org/v2/observations"

# same scope as the dump: california box, research grade, observed since 2025,
# at least one creative commons photo
SCOPE_PARAMETERS = {
    "swlat": 32.5,
    "swlng": -124.5,
    "nelat": 42.0,
    "nelng": -114.1,
    "quality_grade": "research",
    "d1": "2025-01-01",
    "photo_license": "cc0,cc-by,cc-by-nc,cc-by-sa,cc-by-nd,cc-by-nc-sa,cc-by-nc-nd",
}

FIELDS = ",".join([
    "id",
    "uuid",
    "observed_on",
    "updated_at",
    "quality_grade",
    "location",
    "obscured",
    "positional_accuracy",
    "taxon.id",
    "taxon.preferred_common_name",
    "user.id",
    "user.login",
    "user.name",
    "photos.id",
    "photos.license_code",
    "photos.url",
    "photos.attribution",
])

PAGE_SIZE = 200
MIN_SECONDS_BETWEEN_REQUESTS = 1.0  # never more than 60 requests per minute
MAX_REQUESTS_PER_RUN = 5000  # half of inat's 10,000 requests per day guideline
MAX_ATTEMPTS = 5
MAX_RECENT_EVENTS = 50
WATERMARK_OVERLAP = timedelta(hours=1)
TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%SZ"
USER_AGENT = "inat-taxonomy-pipeline (github.com/jayjorneypua/inat-taxonomy-pipeline)"


def utc_now_text():
    return datetime.now(timezone.utc).strftime(TIMESTAMP_FORMAT)


def read_state(state_path, initial_watermark):
    if state_path.exists():
        return json.loads(state_path.read_text())
    return {"watermark": initial_watermark, "current_run": None}


def write_state(state_path, state):
    # write to a temp file first so a crash never leaves a half written state file
    state_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = state_path.with_suffix(".tmp")
    temp_path.write_text(json.dumps(state, indent=2))
    temp_path.replace(state_path)


def log_event(state, state_path, message):
    # keep the latest events in the state file so the watcher can show them live
    print(message)
    event_sequence = state.get("last_event_sequence", 0) + 1
    state["last_event_sequence"] = event_sequence
    recent_events = state.setdefault("recent_events", [])
    recent_events.append({"sequence": event_sequence, "logged_at": utc_now_text(), "message": message})
    del recent_events[:-MAX_RECENT_EVENTS]
    write_state(state_path, state)


def seconds_to_wait(response, attempt):
    # inat may tell us how long to wait, otherwise back off 2, 4, 8, 16 seconds
    retry_after = response.headers.get("Retry-After") if response is not None else None
    try:
        return int(retry_after)
    except (TypeError, ValueError):
        return 2 ** attempt


def get_page(session, parameters, log):
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response = session.get(API_URL, params=parameters, timeout=60)
        except (requests.ConnectionError, requests.Timeout) as error:
            wait_seconds = seconds_to_wait(None, attempt)
            log(f"attempt {attempt} failed ({type(error).__name__}), retrying in {wait_seconds}s")
            time.sleep(wait_seconds)
            continue

        if response.status_code == 429 or response.status_code >= 500:
            wait_seconds = seconds_to_wait(response, attempt)
            log(f"attempt {attempt} got {response.status_code}, retrying in {wait_seconds}s")
            time.sleep(wait_seconds)
            continue

        # any other error means our request is wrong, retrying will not fix it
        response.raise_for_status()
        return response.json()

    raise RuntimeError(f"giving up after {MAX_ATTEMPTS} attempts")


def check_updated_since(observations, updated_since):
    # stop if the api ignored our watermark, instead of silently pulling everything
    watermark = datetime.strptime(updated_since, TIMESTAMP_FORMAT).replace(tzinfo=timezone.utc)
    for observation in observations:
        updated_at = datetime.fromisoformat(observation["updated_at"])
        if updated_at < watermark:
            raise RuntimeError(
                f"observation {observation['id']} was updated at {observation['updated_at']}, "
                f"before the watermark {updated_since}. the updated_since filter is not being applied"
            )


def write_page(page_path, observations):
    page_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = page_path.with_suffix(".tmp")
    with open(temp_path, "w", encoding="utf-8") as page_file:
        for observation in observations:
            page_file.write(json.dumps(observation) + "\n")
    temp_path.replace(page_path)


def pull_observations(
    out_dir="data/raw/api_observations",
    state_path="data/raw/_state/api_observations.json",
    initial_watermark="2026-10-27T00:00:00Z",
    max_requests=MAX_REQUESTS_PER_RUN,
):
    out_dir = Path(out_dir)
    state_path = Path(state_path)
    state = read_state(state_path, initial_watermark)

    def log(message):
        log_event(state, state_path, message)

    if state["current_run"] is None:
        state["current_run"] = {
            "run_started_at": utc_now_text(),
            "updated_since": state["watermark"],
            "last_id": 0,
            "pages_written": 0,
        }
        log(f"run started, pulling changes since {state['watermark']}")
    else:
        log(f"resuming unfinished run from id {state['current_run']['last_id']}")

    current_run = state["current_run"]
    run_id = current_run["run_started_at"].replace("-", "").replace(":", "")
    run_folder = out_dir / f"run_id={run_id}"

    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT

    requests_made = 0
    observations_written = 0
    finished = False
    last_request_started_at = None

    try:
        while requests_made < max_requests:
            # wait only for what is left of the minimum gap since the last request started
            if last_request_started_at is not None:
                seconds_since_last_request = time.monotonic() - last_request_started_at
                if seconds_since_last_request < MIN_SECONDS_BETWEEN_REQUESTS:
                    time.sleep(MIN_SECONDS_BETWEEN_REQUESTS - seconds_since_last_request)
            last_request_started_at = time.monotonic()

            parameters = {
                **SCOPE_PARAMETERS,
                "updated_since": current_run["updated_since"],
                "order_by": "id",
                "order": "asc",
                "id_above": current_run["last_id"],
                "per_page": PAGE_SIZE,
                "fields": FIELDS,
            }
            page = get_page(session, parameters, log)
            requests_made += 1
            observations = page["results"]

            if not observations:
                finished = True
                break

            check_updated_since(observations, current_run["updated_since"])

            page_number = current_run["pages_written"] + 1
            write_page(run_folder / f"page_{page_number:05d}.json", observations)
            observations_written += len(observations)

            # checkpoint after every page (log writes the state), so a crash loses at most one page
            current_run["last_id"] = observations[-1]["id"]
            current_run["pages_written"] = page_number
            log(f"page {page_number}: {len(observations)} observations, last id {current_run['last_id']:,}")

            if len(observations) < PAGE_SIZE:
                finished = True
                break
    except Exception as error:
        log(f"run failed: {type(error).__name__}: {error}")
        raise

    if finished:
        # overlap a little so nothing slips past while inat's search index catches up
        run_started_at = datetime.strptime(current_run["run_started_at"], TIMESTAMP_FORMAT)
        state["watermark"] = (run_started_at - WATERMARK_OVERLAP).strftime(TIMESTAMP_FORMAT)
        state["current_run"] = None
        log(f"run finished: {observations_written:,} observations, new watermark {state['watermark']}")
    else:
        log(f"stopped at the {max_requests:,} request cap, next run resumes from id {current_run['last_id']:,}")

    summary = {
        "run_id": run_id,
        "finished": finished,
        "requests_made": requests_made,
        "observations_written": observations_written,
        "watermark": state["watermark"],
    }
    return summary


if __name__ == "__main__":
    # local test: only 3 requests, so it stops early and the next run has to resume
    print(pull_observations(max_requests=3))