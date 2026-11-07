import gzip
import time
from email.utils import parsedate_to_datetime
from pathlib import Path

import requests

OBSERVATIONS_URL = "https://inaturalist-open-data.s3.amazonaws.com/observations.csv.gz"

# project scope: california bounding box, research grade, observed since 2025
MIN_LATITUDE, MAX_LATITUDE = 32.5, 42.0
MIN_LONGITUDE, MAX_LONGITUDE = -124.5, -114.1
MIN_OBSERVED_ON = "2025-01-01"


def is_in_scope(columns, column_index):
    latitude_text = columns[column_index["latitude"]]
    longitude_text = columns[column_index["longitude"]]

    if not latitude_text or not longitude_text:
        return False

    return (
        columns[column_index["quality_grade"]] == "research"
        and columns[column_index["observed_on"]] >= MIN_OBSERVED_ON
        and MIN_LATITUDE <= float(latitude_text) <= MAX_LATITUDE
        and MIN_LONGITUDE <= float(longitude_text) <= MAX_LONGITUDE
    )


def download_observations(out_dir="data/raw/observations"):
    with requests.get(OBSERVATIONS_URL, stream=True, timeout=60) as response:
        response.raise_for_status()

        # the dump is regenerated monthly, last-modified tells us which snapshot this is
        snapshot_date = parsedate_to_datetime(response.headers["Last-Modified"]).date()
        target_path = Path(out_dir) / f"snapshot_date={snapshot_date}" / "observations.csv.gz"

        if target_path.exists():
            print(f"snapshot {snapshot_date} already downloaded, nothing to do")
            return {"snapshot_date": str(snapshot_date), "skipped": True}

        target_path.parent.mkdir(parents=True, exist_ok=True)
        temp_path = target_path.with_suffix(".tmp")

        lines_scanned = 0
        lines_kept = 0
        lines_malformed = 0
        start_time = time.time()

        print(f"streaming {OBSERVATIONS_URL}")
        with gzip.open(response.raw, "rt", encoding="utf-8") as source_file, \
                gzip.open(temp_path, "wt", encoding="utf-8") as output_file:

            header_line = source_file.readline()
            output_file.write(header_line)
            column_names = header_line.rstrip("\n").split("\t")
            column_index = {name: position for position, name in enumerate(column_names)}

            for line in source_file:
                lines_scanned += 1
                columns = line.rstrip("\n").split("\t")

                if len(columns) != len(column_names):
                    lines_malformed += 1
                    continue

                if is_in_scope(columns, column_index):
                    output_file.write(line)
                    lines_kept += 1

                if lines_scanned % 25_000_000 == 0:
                    elapsed_seconds = time.time() - start_time
                    print(f"{lines_scanned:,} scanned, {lines_kept:,} kept, {elapsed_seconds:.0f}s")

    # an empty result means the filter is broken, never save it as a snapshot
    if lines_kept == 0:
        temp_path.unlink()
        raise RuntimeError("no observations matched the scope, check the filter")

    # only replace the real file once the scan is complete
    temp_path.replace(target_path)

    summary = {
        "snapshot_date": str(snapshot_date),
        "lines_scanned": lines_scanned,
        "lines_kept": lines_kept,
        "lines_malformed": lines_malformed,
        "seconds": round(time.time() - start_time),
    }
    print(f"saved to {target_path}: {summary}")
    return summary


if __name__ == "__main__":
    download_observations()