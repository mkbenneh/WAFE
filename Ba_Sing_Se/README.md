# Observation downloader

This tool discovers observation files, then uses `download_file.sh` for
resumable HTTPS or SFTP transfers. It supports NASA CMR, CMR virtual
directories, STAC APIs, direct URL manifests, and predictable archive URLs.

## Install

```bash
cd Ba_Sing_Se
python3 install_dependencies.py
```

## Earthdata credentials

Earthdata credentials are required to download the protected CALIPSO L0 files.
To authenticate, either create a local
`~/.netrc` entry:

```text
machine urs.earthdata.nasa.gov
login YOUR_USERNAME
password YOUR_PASSWORD
```

Protect it with `chmod 600 ~/.netrc`. Do not put credentials in YAML files or
notebooks. Pass its path with `--netrc-file ~/.netrc` for the CLI, or set
`EARTHDATA_USERNAME` and `EARTHDATA_PASSWORD` in the environment before
launching the notebook.

## CALIPSO L0: automatic CMR virtual-directory download

The `asdc_calipso_l0_virtual_directory` source is preconfigured for collection
`C3880519029-LARC_CLOUD`. You only provide the date range; it builds each
`YYYY/MM/DD` virtual-directory URL, finds the HDF files, and downloads them.
The profile explicitly selects `.hdf` CALIPSO L0 granules such as
`CAL_LID_L0-Standard-V1-00.2010-06-07T00-00-00Z.hdf`. No file-name list or
manual URL template is required.

Preview the files first:

```bash
python3 obs_download.py --config config_template.yaml \
  --source asdc_calipso_l0_virtual_directory \
  --start 2010-06-07 --end 2010-06-07 --dry-run
```

During real downloads, files are processed one at a time. Each transfer shows
curl's native progress bar, and the downloader prints a `Downloading n/total`
counter before it starts the next file.

## Slow or large downloads

Files stream directly to disk; they are not held in memory. Downloads resume
from the partial local file after a retry. By default, a connection has 30
seconds to open and is only retried after transferring less than one byte per
second for five minutes. Adjust these values for a slower connection without
changing the script:

```bash
export DOWNLOAD_CONNECT_TIMEOUT=60
export DOWNLOAD_LOW_SPEED_LIMIT=1
export DOWNLOAD_LOW_SPEED_TIME=600
```

`DOWNLOAD_LOW_SPEED_TIME` is the grace period for an effectively idle
connection. The defaults favour completing very large files while still
recovering from stalled transfers.

To download, remove `--dry-run` and provide credentials:

```bash
python3 obs_download.py --config config_template.yaml \
  --source asdc_calipso_l0_virtual_directory \
  --start 2010-06-07 --end 2010-06-07 \
  --netrc-file ~/.netrc --outdir downloads/calipso-l0
```

## Jupyter notebook

Open `obs_download.ipynb` and edit only the final code cell:

```python
SOURCE = 'asdc_calipso_l0_virtual_directory'
START = '2010-06-07'
END = '2010-06-07'
OUTDIR = 'downloads/calipso-l0'
CONCURRENCY = 1  # Downloads are processed one at a time.
NETRC_FILE = True  # Use ~/.netrc for protected CALIPSO L0 downloads.
DRY_RUN = True
```

Set `DRY_RUN = False` to perform the downloads. The notebook calls the same
CLI workflow, so it automatically discovers the daily L0 files.

For sources that require authentication, `NETRC_FILE` accepts three safe forms:

- `True`: use `~/.netrc`.
- `"/absolute/path/to/.netrc"`: use that credential file.
- `None`: do not use a netrc file; set `EARTHDATA_USERNAME` and
  `EARTHDATA_PASSWORD` in the environment instead.

The notebook and command-line tool validate the selected netrc file before a
download begins and show a clear error if it is missing.

## Other supplied source profiles

- `laads`: LAADS DAAC via CMR. Replace its placeholder collection short name.
- `asdc_calipso_l1`: NASA Langley ASDC CALIPSO Level 1 via CMR.
- `icare_calipso`: HTTPS/SFTP URL manifest exported from ICARE. ICARE account
  access is required.
- `stac_example`, `supplied_urls`, and `archive_template`: examples for STAC,
  direct URL lists, and regular archive paths.

For a one-off CMR collection without a source profile:

```bash
python3 obs_download.py --cmr --short-name COLLECTION_SHORT_NAME \
  --start YYYY-MM-DD --end YYYY-MM-DD --dry-run
```

If macOS Python reports `CERTIFICATE_VERIFY_FAILED` while querying CMR, run
that Python installation's `Install Certificates.command`, or use a Python
environment with current CA certificates.
