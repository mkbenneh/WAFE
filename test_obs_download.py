#!/usr/bin/env python3
"""Test suite for obs_download module."""
import pytest
from datetime import date, timedelta
from unittest.mock import patch, MagicMock
import sys
import os

# Add Ba_Sing_Se to path so we can import obs_download
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "Ba_Sing_Se"))

import obs_download


class TestDaysGenerator:
    """Test the days() generator function."""

    def test_days_single_day(self):
        """Test days generator for a single day."""
        result = list(obs_download.days("2010-06-07", "2010-06-07"))
        assert result == [date(2010, 6, 7)]

    def test_days_range(self):
        """Test days generator for a date range."""
        result = list(obs_download.days("2010-06-07", "2010-06-09"))
        expected = [date(2010, 6, 7), date(2010, 6, 8), date(2010, 6, 9)]
        assert result == expected

    def test_days_missing_start(self):
        """Test that missing start date raises ValueError."""
        with pytest.raises(ValueError, match="--start and --end are required"):
            list(obs_download.days(None, "2010-06-07"))

    def test_days_missing_end(self):
        """Test that missing end date raises ValueError."""
        with pytest.raises(ValueError, match="--start and --end are required"):
            list(obs_download.days("2010-06-07", None))

    def test_days_end_before_start(self):
        """Test that end date before start date raises ValueError."""
        with pytest.raises(ValueError, match="--end must not precede --start"):
            list(obs_download.days("2010-06-09", "2010-06-07"))


class TestTemplateUrls:
    """Test the template_urls() function."""

    def test_template_urls_single_day(self):
        """Test URL template expansion for a single day."""
        template = "https://example.com/{YYYY}/{MM}/{DD}/{FNAME}"
        result = obs_download.template_urls(template, "", ["file.hdf"], "2010-06-07", "2010-06-07")
        assert result == ["https://example.com/2010/06/07/file.hdf"]

    def test_template_urls_with_product(self):
        """Test URL template expansion with product placeholder."""
        template = "https://example.com/{PRODUCT}/{YYYYMMDD}/{FNAME}"
        result = obs_download.template_urls(template, "CALIPSO", ["test.h5"], "2010-06-07", "2010-06-07")
        assert result == ["https://example.com/CALIPSO/20100607/test.h5"]

    def test_template_urls_multiple_files(self):
        """Test URL template expansion with multiple files."""
        template = "https://example.com/{YYYY}/{MM}/{DD}/{FNAME}"
        result = obs_download.template_urls(template, "", ["file1.hdf", "file2.hdf"], "2010-06-07", "2010-06-07")
        assert result == [
            "https://example.com/2010/06/07/file1.hdf",
            "https://example.com/2010/06/07/file2.hdf"
        ]


class TestDirectoryLinks:
    """Test the DirectoryLinks HTML parser."""

    def test_directory_links_parser(self):
        """Test parsing HTML links from a directory page."""
        html = '''
        <html>
            <body>
                <a href="file1.hdf">file1.hdf</a>
                <a href="file2.hdf">file2.hdf</a>
                <a href="../">Parent Directory</a>
            </body>
        </html>
        '''
        parser = obs_download.DirectoryLinks()
        parser.feed(html)
        assert "file1.hdf" in parser.hrefs
        assert "file2.hdf" in parser.hrefs
        assert "../" in parser.hrefs

    def test_directory_links_empty_href(self):
        """Test parser ignores empty href attributes."""
        html = '<html><a href="">Empty Link</a><a href="real.hdf">Real</a></html>'
        parser = obs_download.DirectoryLinks()
        parser.feed(html)
        assert parser.hrefs == ["real.hdf"]


class TestCommandFor:
    """Test the command_for() function."""

    def test_command_for_basic(self):
        """Test basic command generation."""
        args = MagicMock(
            outdir="downloads",
            netrc_file=None,
            username=None,
            password=None
        )
        with patch.dict(os.environ, {}, clear=True):
            result = obs_download.command_for("https://example.com/file.hdf", args)
            assert "https://example.com/file.hdf" in result
            assert "downloads" in result

    def test_command_for_with_netrc(self):
        """Test command generation with netrc file."""
        args = MagicMock(
            outdir="downloads",
            netrc_file="~/.netrc",
            username=None,
            password=None
        )
        with patch.dict(os.environ, {}, clear=True):
            result = obs_download.command_for("https://example.com/file.hdf", args)
            assert "--netrc-file" in result
            assert "~/.netrc" in result

    def test_command_for_with_credentials(self):
        """Test command generation with username and password."""
        args = MagicMock(
            outdir="downloads",
            netrc_file=None,
            username="user",
            password="pass"
        )
        with patch.dict(os.environ, {}, clear=True):
            result = obs_download.command_for("https://example.com/file.hdf", args)
            assert "--username" in result
            assert "--password" in result
            assert "user" in result
            assert "pass" in result


class TestMainValidation:
    """Test validation logic in main()."""

    def test_concurrency_must_be_positive(self):
        """Test that concurrency must be at least 1."""
        args = MagicMock(
            concurrency=0,
            netrc_file=None,
            template=None,
            granule_list=None,
            source=None,
            cmr=True,
            url_list=None
        )
        with pytest.raises(ValueError, match="--concurrency must be at least 1"):
            obs_download.main()

    def test_template_requires_granule_list(self):
        """Test that --template requires --granule-list."""
        args = MagicMock(
            concurrency=1,
            netrc_file=None,
            template="https://example.com/{YYYYMMDD}/{FNAME}",
            granule_list=None,
            source=None,
            cmr=False,
            url_list=None
        )
        with pytest.raises(ValueError, match="--template requires --granule-list"):
            obs_download.main()

    def test_granule_list_requires_template(self):
        """Test that --granule-list requires --template."""
        args = MagicMock(
            concurrency=1,
            netrc_file=None,
            template=None,
            granule_list="files.txt",
            source=None,
            cmr=False,
            url_list=None
        )
        with pytest.raises(ValueError, match="--granule-list requires --template"):
            obs_download.main()


class TestProfilePath:
    """Test the profile_path() function."""

    def test_profile_path_absolute(self):
        """Test that absolute paths are returned unchanged."""
        profile = {"_base_dir": "/some/base"}
        result = obs_download.profile_path(profile, "/absolute/path/file.txt")
        assert result == "/absolute/path/file.txt"

    def test_profile_path_relative(self):
        """Test that relative paths are joined with base directory."""
        profile = {"_base_dir": "/base/dir"}
        result = obs_download.profile_path(profile, "relative/path/file.txt")
        assert result == "/base/dir/relative/path/file.txt"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
