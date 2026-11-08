import gzip
import shutil
import zipfile
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

import requests

ARCHIVE_URL = "https://www.inaturalist.org/taxa/inaturalist-taxonomy.dwca.zip"
NAMES_FILE_SUFFIX = "VernacularNames-english.csv"


def download_vernacular_names(out_dir="data/raw/vernacular_names"):
    with requests.get(ARCHIVE_URL, stream=True, timeout=120) as response:
        response.raise_for_status()

        # the archive is regenerated monthly, last-modified tells us which snapshot this is
        last_modified = response.headers.get("Last-Modified")
        snapshot_date = (
            parsedate_to_datetime(last_modified).date()
            if last_modified
            else datetime.now(timezone.utc).date()
        )
        target_path = Path(out_dir) / f"snapshot_date={snapshot_date}" / "vernacular_names_english.csv.gz"

        if target_path.exists():
            print(f"snapshot {snapshot_date} already downloaded, nothing to do")
            return {"snapshot_date": str(snapshot_date), "skipped": True}

        target_path.parent.mkdir(parents=True, exist_ok=True)
        archive_path = target_path.parent / "archive.zip.tmp"

        print(f"downloading {ARCHIVE_URL}")
        with open(archive_path, "wb") as archive_file:
            shutil.copyfileobj(response.raw, archive_file, length=1024 * 1024)

    # keep only the english names file, gzipped like the other raw files
    temp_path = target_path.with_suffix(".tmp")
    with zipfile.ZipFile(archive_path) as archive:
        names_file_name = next(name for name in archive.namelist() if name.endswith(NAMES_FILE_SUFFIX))
        with archive.open(names_file_name) as names_file, gzip.open(temp_path, "wb") as output_file:
            shutil.copyfileobj(names_file, output_file, length=1024 * 1024)

    archive_path.unlink()
    temp_path.replace(target_path)
    print(f"saved to {target_path}")
    return {"snapshot_date": str(snapshot_date), "skipped": False}


if __name__ == "__main__":
    download_vernacular_names()