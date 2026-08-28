"""Offline tests for CALIOP L2 URL construction and file validation."""

from pathlib import Path
from subprocess import CompletedProcess

import obs_download


def test_urls_for_constructs_asdc_urls_from_virtual_directory(monkeypatch):
    page = '''<a href="CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf">file</a>
    <a href="ignore.txt">ignore</a>'''
    monkeypatch.setattr(
        obs_download.subprocess,
        "run",
        lambda *args, **kwargs: CompletedProcess(args, 0, stdout=page),
    )

    assert obs_download.urls_for("2023-05-15") == [
        "https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/"
        "CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf"
    ]


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
