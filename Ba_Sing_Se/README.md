# Observation downloader

The downloader is provider-neutral: Python discovers URLs and schedules work;
`download_file.sh` does the resumable HTTPS/SFTP transfer. Supported discovery modes:

- NASA CMR (`--cmr`) for Earth-observation collections such as CALIPSO.
- STAC API source profiles.
- A manifest of direct URLs.
- A date/filename URL template for predictable archive layouts.

Install the Python dependency before using YAML source profiles:

```bash
python3 install_dependencies.py
```

Copy `config_template.yaml` to a local `config.yaml`, define a source, then run:

```bash
python3 obs_download.py --config config.yaml --source asdc_calipso_l1 \
  --start 2020-01-01 --end 2020-01-02 --dry-run
```

The same profile downloads with:

```bash
python3 obs_download.py --config config.yaml --source asdc_calipso_l1 \
  --start 2020-01-01 --end 2020-01-02 --netrc-file ~/.netrc \
  --outdir downloads/calipso --concurrency 3
```

The template includes three provider profiles:

- `laads` for a LAADS DAAC collection (replace its placeholder short name).
- `asdc_calipso_l1` for NASA Langley ASDC CALIPSO Level 1 data.
- `asdc_calipso_l0_virtual_directory` for CALIPSO L0 using CMR's daily
  virtual-directory listing and collection ID `C3880519029-LARC_CLOUD`.
- `icare_calipso` for a manifest of ICARE HTTPS/SFTP archive links. ICARE
  account access and a selected-file manifest are required; the downloader does
  not guess private archive paths.

For a one-off NASA collection, skip the config:

```bash
python3 obs_download.py --cmr --short-name CAL_LID_L1-Standard-V4-51 \
  --start 2020-01-01 --end 2020-01-02 --dry-run
```

Earthdata credentials may be stored locally as:

```text
machine urs.earthdata.nasa.gov login YOUR_USERNAME password YOUR_PASSWORD
```

Use `chmod 600 ~/.netrc`. If a macOS framework Python reports
`CERTIFICATE_VERIFY_FAILED`, run that Python installation's bundled
`Install Certificates.command`, or use a Python environment with current CA
certificates.
