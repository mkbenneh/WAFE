#!/usr/bin/env python3
"""Discover files from common catalogues and download them with Bash."""
import argparse
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, timedelta
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

CMR_URL = "https://cmr.earthdata.nasa.gov/search/granules.json"


def parse_args():
    p = argparse.ArgumentParser(description="Download observation files from catalogue or URL sources.")
    source = p.add_mutually_exclusive_group(required=True)
    source.add_argument("--cmr", action="store_true", help="Search NASA's CMR catalogue")
    source.add_argument("--url-list", metavar="FILE", help="One direct data URL per line")
    source.add_argument("--template", help="URL template; requires --granule-list")
    source.add_argument("--source", help="Named source in --config")
    p.add_argument("--config", help="YAML source-profile file")
    p.add_argument("--short-name", help="CMR collection short name (required with --cmr)")
    p.add_argument("--version", help="CMR collection version")
    p.add_argument("--provider", help="Optional CMR provider ID, e.g. LAADS or ASDC")
    p.add_argument("--start", help="Start date, YYYY-MM-DD (inclusive)")
    p.add_argument("--end", help="End date, YYYY-MM-DD (inclusive)")
    p.add_argument("--granule-list", metavar="FILE", help="Filenames used with --template")
    p.add_argument("--product", default="", help="Value for {PRODUCT} in a template")
    p.add_argument("--bbox", help="STAC bounding box: west,south,east,north")
    p.add_argument("--asset", help="STAC asset key to download (default: all downloadable assets)")
    p.add_argument("--outdir", default="downloads", help="Destination directory")
    p.add_argument("--concurrency", type=int, default=4, help="Parallel transfers (default: 4)")
    p.add_argument("--netrc-file", help="Earthdata .netrc file (recommended)")
    p.add_argument("--username", help="Earthdata user; password from --password or environment")
    p.add_argument("--password", help="Earthdata password; prefer a .netrc file")
    p.add_argument("--dry-run", action="store_true", help="Print resolved URLs without downloading")
    return p.parse_args()


def source_config(filename, name):
    if yaml is None:
        raise ValueError("YAML profiles require PyYAML: pip install pyyaml")
    with open(filename, encoding="utf-8") as stream:
        config = yaml.safe_load(stream) or {}
    sources = config.get("sources", {})
    if name not in sources:
        raise ValueError(f"source {name!r} is not defined in {filename}")
    profile = sources[name]
    if not isinstance(profile, dict) or "type" not in profile:
        raise ValueError(f"source {name!r} needs a type")
    return {**profile, "_base_dir": str(Path(filename).resolve().parent)}


def profile_path(profile, value):
    path = Path(value)
    return str(path if path.is_absolute() else Path(profile["_base_dir"]) / path)


def read_lines(filename):
    with open(filename, encoding="utf-8") as stream:
        return [x.strip() for x in stream if x.strip() and not x.lstrip().startswith("#")]


def days(start, end):
    if not start or not end:
        raise ValueError("--start and --end are required")
    first, last = date.fromisoformat(start), date.fromisoformat(end)
    if last < first:
        raise ValueError("--end must not precede --start")
    while first <= last:
        yield first
        first += timedelta(days=1)


def template_urls(template, product, names, start, end):
    urls = []
    for day in days(start, end):
        fields = {"PRODUCT": product, "YYYY": day.strftime("%Y"), "MM": day.strftime("%m"),
                  "DD": day.strftime("%d"), "YYYYMMDD": day.strftime("%Y%m%d")}
        urls.extend(template.format(**fields, FNAME=name) for name in names)
    return urls


def cmr_urls(short_name, version, start, end, provider=None):
    if not short_name:
        raise ValueError("--short-name is required with --cmr")
    # Full days avoid excluding observations acquired late on the end date.
    params = {"short_name": short_name, "temporal": f"{start}T00:00:00Z,{end}T23:59:59Z",
              "page_size": "2000", "page_num": "1"}
    if version:
        params["version"] = version
    if provider:
        params["provider"] = provider
    urls, seen = [], set()
    while True:
        request = urllib.request.Request(CMR_URL + "?" + urllib.parse.urlencode(params),
                                         headers={"User-Agent": "calipso-downloader/1.0"})
        with urllib.request.urlopen(request, timeout=60) as response:
            entries = json.load(response)["feed"].get("entry", [])
        for entry in entries:
            for link in entry.get("links", []):
                href = link.get("href", "")
                if href.startswith(("https://", "http://")) and "data#" in link.get("rel", "") and href not in seen:
                    seen.add(href)
                    urls.append(href)
        if len(entries) < int(params["page_size"]):
            return urls
        params["page_num"] = str(int(params["page_num"]) + 1)


def stac_urls(endpoint, collections, start, end, bbox=None, asset=None):
    """Query a STAC API /search endpoint and return file assets."""
    if not endpoint or not collections:
        raise ValueError("a STAC source needs endpoint and collections")
    search_url = endpoint.rstrip("/") + "/search"
    body = {"collections": collections, "datetime": f"{start}T00:00:00Z/{end}T23:59:59Z", "limit": 100}
    if bbox:
        try:
            body["bbox"] = [float(value) for value in bbox.split(",")]
        except ValueError as error:
            raise ValueError("--bbox must be west,south,east,north") from error
        if len(body["bbox"]) != 4:
            raise ValueError("--bbox must have four values")
    urls, next_url = [], search_url
    while next_url:
        payload = json.dumps(body).encode() if next_url == search_url else None
        request = urllib.request.Request(next_url, data=payload, method="POST" if payload else "GET",
                                         headers={"Content-Type": "application/json", "User-Agent": "obs-downloader/1.0"})
        with urllib.request.urlopen(request, timeout=60) as response:
            page = json.load(response)
        for feature in page.get("features", []):
            for key, value in feature.get("assets", {}).items():
                href = value.get("href", "")
                if (asset is None or key == asset) and href.startswith(("https://", "http://")):
                    urls.append(href)
        next_url = next((link["href"] for link in page.get("links", []) if link.get("rel") == "next"), None)
        body = None
    return list(dict.fromkeys(urls))


def urls_from_profile(profile, args):
    kind = profile["type"]
    if kind == "cmr":
        start, end = args.start or profile.get("start"), args.end or profile.get("end")
        list(days(start, end))
        return cmr_urls(args.short_name or profile.get("short_name"), args.version or profile.get("version"), start, end,
                        args.provider or profile.get("provider"))
    if kind == "url_list":
        return read_lines(profile_path(profile, profile["path"]))
    if kind == "template":
        start, end = args.start or profile.get("start"), args.end or profile.get("end")
        names = read_lines(profile_path(profile, profile["granule_list"]))
        return template_urls(profile["url_template"], args.product or profile.get("product", ""), names, start, end)
    if kind == "stac":
        start, end = args.start or profile.get("start"), args.end or profile.get("end")
        list(days(start, end))
        collections = profile.get("collections", [])
        if isinstance(collections, str):
            collections = [collections]
        return stac_urls(profile.get("endpoint"), collections, start, end, args.bbox or profile.get("bbox"), args.asset or profile.get("asset"))
    raise ValueError(f"unsupported source type: {kind}; use cmr, stac, url_list, or template")


def command_for(url, args):
    command = [str(Path(__file__).with_name("download_file.sh")), url, args.outdir]
    if args.netrc_file:
        command += ["--netrc-file", args.netrc_file]
    user = args.username or os.environ.get("EARTHDATA_USERNAME")
    password = args.password or os.environ.get("EARTHDATA_PASSWORD")
    if user and password:
        command += ["--username", user, "--password", password]
    return command


def main():
    args = parse_args()
    if args.concurrency < 1:
        raise ValueError("--concurrency must be at least 1")
    if args.template and not args.granule_list:
        raise ValueError("--template requires --granule-list")
    if args.granule_list and not args.template:
        raise ValueError("--granule-list requires --template")
    if args.source:
        if not args.config:
            raise ValueError("--source requires --config")
        urls = urls_from_profile(source_config(args.config, args.source), args)
    elif args.cmr:
        # Validate date strings before sending the CMR request.
        list(days(args.start, args.end))
        urls = cmr_urls(args.short_name, args.version, args.start, args.end, args.provider)
    elif args.url_list:
        urls = read_lines(args.url_list)
    else:
        urls = template_urls(args.template, args.product, read_lines(args.granule_list), args.start, args.end)
    if not urls:
        print("No granules found.", file=sys.stderr)
        return 1
    print(f"Resolved {len(urls)} file(s).")
    if args.dry_run:
        print("\n".join(urls))
        return 0
    Path(args.outdir).mkdir(parents=True, exist_ok=True)
    failures = 0
    with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        pending = {pool.submit(subprocess.run, command_for(url, args), text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE): url for url in urls}
        for future in as_completed(pending):
            url, result = pending[future], future.result()
            if result.returncode:
                failures += 1
                print(f"FAILED: {url}\n{result.stderr.strip()}", file=sys.stderr)
            else:
                print(f"OK: {url}")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, urllib.error.URLError, json.JSONDecodeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(2)
