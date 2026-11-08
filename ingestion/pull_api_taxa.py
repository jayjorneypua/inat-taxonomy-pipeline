import json
import time
from datetime import datetime, timezone
from pathlib import Path

import requests

API_URL = "https://api.inaturalist.org/v1/taxa/{taxon_ids}"
IDS_PER_REQUEST = 30  # the api's maximum for this endpoint
MIN_SECONDS_BETWEEN_REQUESTS = 1.0
MAX_ATTEMPTS = 5
USER_AGENT = "inat-taxonomy-pipeline (github.com/jayjorneypua/inat-taxonomy-pipeline)"
KEPT_FIELDS = [
    "id", "name", "rank", "rank_level", "ancestry",
    "is_active", "parent_id", "preferred_common_name",
]


def get_taxa_batch(session, taxon_ids):
    url = API_URL.format(taxon_ids=",".join(str(taxon_id) for taxon_id in taxon_ids))

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response = session.get(url, params={"per_page": IDS_PER_REQUEST}, timeout=60)
        except (requests.ConnectionError, requests.Timeout) as error:
            print(f"attempt {attempt} failed ({type(error).__name__}), retrying in {2 ** attempt}s")
            time.sleep(2 ** attempt)
            continue

        if response.status_code == 429 or response.status_code >= 500:
            print(f"attempt {attempt} got {response.status_code}, retrying in {2 ** attempt}s")
            time.sleep(2 ** attempt)
            continue

        response.raise_for_status()
        return response.json()["results"]

    raise RuntimeError(f"giving up after {MAX_ATTEMPTS} attempts")


def pull_taxa(taxon_ids, out_dir="data/raw/api_taxa"):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    taxon_ids = sorted(set(taxon_ids))

    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT

    fetched_taxa = []
    last_request_started_at = None

    for batch_start in range(0, len(taxon_ids), IDS_PER_REQUEST):
        if last_request_started_at is not None:
            seconds_since_last_request = time.monotonic() - last_request_started_at
            if seconds_since_last_request < MIN_SECONDS_BETWEEN_REQUESTS:
                time.sleep(MIN_SECONDS_BETWEEN_REQUESTS - seconds_since_last_request)
        last_request_started_at = time.monotonic()

        batch_ids = taxon_ids[batch_start:batch_start + IDS_PER_REQUEST]
        for taxon in get_taxa_batch(session, batch_ids):
            fetched_taxa.append({field: taxon.get(field) for field in KEPT_FIELDS})

    if fetched_taxa:
        file_name = f"taxa_{datetime.now(timezone.utc):%Y%m%dT%H%M%S%fZ}.json"
        target_path = out_dir / file_name
        temp_path = target_path.with_suffix(".tmp")
        with open(temp_path, "w", encoding="utf-8") as output_file:
            for taxon in fetched_taxa:
                output_file.write(json.dumps(taxon) + "\n")
        temp_path.replace(target_path)

    print(f"asked for {len(taxon_ids)} taxa, received {len(fetched_taxa)}")
    return fetched_taxa


if __name__ == "__main__":
    pull_taxa([20978, 27427])