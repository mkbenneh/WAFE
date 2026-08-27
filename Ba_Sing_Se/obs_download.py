#!/usr/bin/env python3
"""Download every CALIOP L2 05 km aerosol-profile granule for one UTC day."""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from datetime import date
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse

CMR_DIRECTORY = "https://cmr.earthdata.nasa.gov/virtual-directory/collections/C3880521383-LARC_CLOUD/temporal/{:%Y/%m/%d}"
FILENAME_PREFIX = "CAL_LID_L2_05kmAPro-Standard-V4-51"
ASDC_DIRECTORY = "https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/{}/{}/"


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hrefs = []

    def handle_starttag(self, tag, attrs):
        if tag == "a" and (href := dict(attrs).get("href")):
            self.hrefs.append(href)


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--day", required=True, help="UTC day: YYYY-MM-DD")
    parser.add_argument("--outdir", default="downloads/calipso-l0")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def urls_for(day):
    directory = CMR_DIRECTORY.format(date.fromisoformat(day))
    page = subprocess.run(["curl", "--fail", "--location", "--silent", directory],
                          text=True, capture_output=True, check=True).stdout
    parser = Links()
    parser.feed(page)
    files = {Path(urlparse(urljoin(directory + "/", href)).path).name for href in parser.hrefs}
    urls = []
    for filename in files:
        if not filename.startswith(FILENAME_PREFIX) or not filename.endswith(".hdf"):
            continue
        match = re.search(r"\.(\d{4})-(\d{2})-\d{2}T", filename)
        if match:
            urls.append(ASDC_DIRECTORY.format(*match.groups()) + filename)
    return sorted(urls)


def run_fetch(urls, outdir):
    script = Path(__file__).with_name("caliop_fetch.sh")
    source = script.read_text(encoding="utf-8")
    marker = "fetch_urls <<'EDSCEOF'\n"
    start, end = source.find(marker), source.find("\nEDSCEOF", source.find(marker))
    if start < 0 or end < 0:
        raise ValueError("caliop_fetch.sh has no EDSCEOF URL block")
    with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as copy:
        copy.write(source[:start + len(marker)] + "\n".join(urls) + source[end:])
        generated = Path(copy.name)
    try:
        generated.chmod(0o700)
        Path(outdir).mkdir(parents=True, exist_ok=True)
        username = os.environ.get("EARTHDATA_USERNAME")
        password = os.environ.get("EARTHDATA_PASSWORD")
        credentials = f"{username}\n{password}\n" if username and password else None
        return subprocess.run([str(generated)], cwd=outdir, input=credentials,
                              text=True, check=False).returncode
    finally:
        generated.unlink(missing_ok=True)


def main():
    args = arguments()
    urls = urls_for(args.day)
    if not urls:
        raise ValueError(f"No L2 granules found for {args.day}")
    if args.dry_run:
        print("\n".join(urls))
        return 0
    return run_fetch(urls, args.outdir)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(2)
