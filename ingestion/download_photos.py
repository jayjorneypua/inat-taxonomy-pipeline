import gzip
import time
from email.utils import parsedate_to_datetime
from pathlib import Path

import requests

PHOTOS_URL = "https://inaturalist-open-data.s3.amazonaws.com/photos.csv.gz"


def load_observation_uuids(observations_path):
    observation_uuids = set()

    with gzip.open(observations_path, "rt", encoding="utf-8") as observations_file:
        column_names = observations_file.readline().rstrip("\n").split("\t")
        uuid_position = column_names.index("observation_uuid")

        for line in observations_file:
            observation_uuids.add(line.split("\t", uuid_position + 1)[uuid_position])

    return observation_uuids


def download_photos(observations_dir="data/raw/observations", out_dir="data/raw/photos"):
    with requests.get(PHOTOS_URL, stream=True, timeout=60) as response:
        response.raise_for_status()

        # the dump is regenerated monthly, last-modified tells us which snapshot this is
        snapshot_date = parsedate_to_datetime(response.headers["Last-Modified"]).date()
        target_path = Path(out_dir) / f"snapshot_date={snapshot_date}" / "photos.csv.gz"

        if target_path.exists():
            print(f"snapshot {snapshot_date} already downloaded, nothing to do")
            return {"snapshot_date": str(snapshot_date), "skipped": True}

        # photos are filtered by the observations of the same snapshot
        observations_path = (
            Path(observations_dir) / f"snapshot_date={snapshot_date}" / "observations.csv.gz"
        )
        if not observations_path.exists():
            raise FileNotFoundError(
                f"observations snapshot {snapshot_date} not found, load observations first"
            )

        print(f"loading observation uuids from {observations_path}")
        observation_uuids = load_observation_uuids(observations_path)
        print(f"{len(observation_uuids):,} observation uuids loaded")

        target_path.parent.mkdir(parents=True, exist_ok=True)
        temp_path = target_path.with_suffix(".tmp")

        lines_scanned = 0
        lines_kept = 0
        lines_malformed = 0
        start_time = time.time()

        print(f"streaming {PHOTOS_URL}")
        with gzip.open(response.raw, "rt", encoding="utf-8") as source_file, \
                gzip.open(temp_path, "wt", encoding="utf-8") as output_file:

            header_line = source_file.readline()
            output_file.write(header_line)
            column_names = header_line.rstrip("\n").split("\t")
            uuid_position = column_names.index("observation_uuid")
            expected_tab_count = len(column_names) - 1

            for line in source_file:
                lines_scanned += 1

                if line.count("\t") != expected_tab_count:
                    lines_malformed += 1
                    continue

                observation_uuid = line.split("\t", uuid_position + 1)[uuid_position]

                if observation_uuid in observation_uuids:
                    output_file.write(line)
                    lines_kept += 1

                if lines_scanned % 50_000_000 == 0:
                    elapsed_seconds = time.time() - start_time
                    print(f"{lines_scanned:,} scanned, {lines_kept:,} kept, {elapsed_seconds:.0f}s")

    # an empty result means something is wrong, never save it as a snapshot
    if lines_kept == 0:
        temp_path.unlink()
        raise RuntimeError("no photos matched the observations, check the inputs")

    # only replace the real file once the scan is complete
    temp_path.replace(target_path)

    summary = {
        "snapshot_date": str(snapshot_date),
        "observation_uuids": len(observation_uuids),
        "lines_scanned": lines_scanned,
        "lines_kept": lines_kept,
        "lines_malformed": lines_malformed,
        "seconds": round(time.time() - start_time),
    }
    print(f"saved to {target_path}: {summary}")
    return summary


if __name__ == "__main__":
    download_photos()