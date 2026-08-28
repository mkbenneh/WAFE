"""Offline tests for CALIOP L2 URL construction and file validation."""

from pathlib import Path
from subprocess import CompletedProcess

import obs_download


def test_urls_for_constructs_asdc_urls_from_virtual_directory(monkeypatch):
    page = '''<a href="CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf">file</a>
    <a href="ignore.txt">ignore</a>'''
    calls = []

    def fake_run(*args, **kwargs):
        calls.append(args[0])
        return CompletedProcess(args, 0, stdout=page)

    monkeypatch.setattr(obs_download.subprocess, "run", fake_run)

    assert obs_download.urls_for("2023-05-15") == [
        "https://data.asdc.earthdata.nasa.gov/asdc-prod-protected/CALIPSO/"
        "CAL_LID_L2_05kmAPro-Standard-V4-51_V4-51/2023.05/"
        "CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf"
    ]
    assert calls == [[
        "curl", "--fail", "--location", "--silent",
        "https://cmr.earthdata.nasa.gov/virtual-directory/collections/"
        "C3880521383-LARC_CLOUD/temporal/2023/05/15",
    ]]


def test_is_hdf_recognizes_hdf4_and_hdf5(tmp_path):
    hdf4, hdf5 = tmp_path / "a.hdf", tmp_path / "b.hdf"
    hdf4.write_bytes(b"\x0e\x03\x13\x01payload")
    hdf5.write_bytes(b"\x89HDF\r\n\x1a\npayload")

    assert obs_download.is_hdf(hdf4)
    assert obs_download.is_hdf(hdf5)


def test_is_hdf_rejects_html(tmp_path):
    response = Path(tmp_path / "login.hdf")
    response.write_text("<!DOCTYPE html><title>Sign In</title>", encoding="utf-8")

    assert not obs_download.is_hdf(response)
