"""Offline unit tests for observation URL discovery helpers."""

import argparse

import pytest

import obs_download


def test_days_includes_both_endpoints():
    assert [str(day) for day in obs_download.days("2010-06-07", "2010-06-08")] == [
        "2010-06-07",
        "2010-06-08",
    ]


def test_days_rejects_reversed_range():
    with pytest.raises(ValueError, match="must not precede"):
        list(obs_download.days("2010-06-08", "2010-06-07"))


def test_template_urls_substitutes_date_and_filename():
    urls = obs_download.template_urls(
        "https://example.test/{YYYY}/{MM}/{DD}/{PRODUCT}-{FNAME}",
        "CALIPSO",
        ["first.hdf", "second.hdf"],
        "2010-06-07",
        "2010-06-07",
    )

    assert urls == [
        "https://example.test/2010/06/07/CALIPSO-first.hdf",
        "https://example.test/2010/06/07/CALIPSO-second.hdf",
    ]


def test_command_for_uses_environment_credentials(monkeypatch):
    monkeypatch.setenv("EARTHDATA_USERNAME", "user")
    monkeypatch.setenv("EARTHDATA_PASSWORD", "password")
    args = argparse.Namespace(outdir="downloads", netrc_file=None, username=None, password=None)

    command = obs_download.command_for("https://example.test/file.hdf", args)

    assert command[-4:] == ["--username", "user", "--password", "password"]
