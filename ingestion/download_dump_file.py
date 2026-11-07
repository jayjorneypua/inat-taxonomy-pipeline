import gzip
import shutil
from email.utils import parsedate_to_datetime
from pathlib import Path

import requests

DUMP_BASE_URL = "https://inaturalist-open-data.s3.amazonaws.com"


def download_dump_file(file_name, out_dir):
    file_url = f"{DUMP_BASE_URL}/{file_name}"

    with requests.get(file_url, stream=True, timeout=60) as response:
        response.raise_for_status()

        # the dump is regenerated monthly, last-modified tells us which snapshot this is
        snapshot_date = parsedate_to_datetime(response.headers["Last-Modified"]).date()
        target_path = Path(out_dir) / f"snapshot_date={snapshot_date}" / file_name

        if target_path.exists():
            print(f"{file_name} snapshot {snapshot_date} already downloaded, nothing to do")
            return {"file_name": file_name, "snapshot_date": str(snapshot_date), "skipped": True}

        target_path.parent.mkdir(parents=True, exist_ok=True)
        temp_path = target_path.with_suffix(".tmp")

        print(f"downloading {file_url}")
        # copy the raw bytes as-is, iter_content would unzip the file on the way down
        with open(temp_path, "wb") as temp_file:
            shutil.copyfileobj(response.raw, temp_file, length=1024 * 1024)

    # fail here if the file is not real gzip, so a bad file never gets its final name
    with gzip.open(temp_path, "rt", encoding="utf-8") as check_file:
        check_file.readline()

    # only replace the real file once the download is complete and valid
    temp_path.replace(target_path)
    print(f"saved to {target_path}")
    return {"file_name": file_name, "snapshot_date": str(snapshot_date), "skipped": False}


if __name__ == "__main__":
    download_dump_file("observers.csv.gz", out_dir="data/raw/observers")