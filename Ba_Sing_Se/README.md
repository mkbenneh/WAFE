# CALIOP L2 aerosol-profile downloader

Downloads every available `CAL_LID_L2_05kmAPro-Standard-V4-51` HDF granule for
one UTC day. Python reads the L2 CMR virtual directory, constructs the matching
ASDC data URLs, writes them into `caliop_fetch.sh`'s URL block, and launches the
script's existing Earthdata download flow.

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
with the L2 URLs for that day. The bash script then prompts for Earthdata
credentials and downloads files into the selected output directory.

Preview constructed URLs without modifying the bash script or downloading:

```bash
python3 obs_download.py --day 2023-05-15 --dry-run
```

## Jupyter notebook

Open `obs_download.ipynb`, set `DAY`, `OUTDIR`, and `DRY_RUN`, then run its
single code cell. It prompts for your Earthdata username and hidden password;
those values are passed only to the child download process and are not saved in
the notebook.

## Download validation

After downloading, Python checks each file’s HDF4/HDF5 signature. A login page
or other HTML response saved with an `.hdf` name is reported as an error rather
than treated as data. Delete any such invalid files before retrying.

## Tests

Run the offline test suite with:

```bash
python3 -m pytest
```
