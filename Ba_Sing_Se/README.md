# CALIOP L2 aerosol-profile downloader

Downloads every available `CAL_LID_L2_05kmAPro-Standard-V4-51` HDF granule for
one UTC day. Python reads the L2 CMR virtual directory, constructs protected
ASDC data URLs, writes them into `caliop_fetch.sh`'s URL block, and launches the
script's existing Earthdata download flow.

Generated URLs use this protected ASDC format:

```text
https://data.asdc.earthdata.nasa.gov/asdc-prod-protected/CALIPSO/CAL_LID_L2_05kmAPro-Standard-V4-51_V4-51/YYYY.MM/FILENAME.hdf
```

## Requirements

- Python 3.10 or later
- `curl`
- An Earthdata Login with access to ASDC CALIPSO data

## Download a day

Run from `Ba_Sing_Se`:

```bash
python3 obs_download.py --day 2023-05-15 --outdir downloads/caliop-l2
```

The script updates the `fetch_urls <<'EDSCEOF'` block in `caliop_fetch.sh`
with the L2 URLs for that day and downloads files into the selected output
directory. When run in a terminal, the bash script prompts for Earthdata
credentials.

Preview constructed URLs without modifying the bash script or downloading:

```bash
python3 obs_download.py --day 2023-05-15 --dry-run
```

## Jupyter notebook

Open `obs_download.ipynb`, set `DAY`, `OUTDIR`, and `DRY_RUN`, then run its
single code cell. It prompts for your Earthdata username and hidden password;
those values are passed to the bash process through standard input and are not
saved in the notebook or on disk.

## Download validation

After downloading, Python checks each file’s HDF4/HDF5 signature. A login page
or other HTML response saved with an `.hdf` name is reported as an error rather
than treated as data. Delete any such invalid files before retrying.

## Tests

Run the offline test suite with:

```bash
python3 -m pytest
```
