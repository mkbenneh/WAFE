#!/bin/bash

GREP_OPTIONS=''

cookiejar=$(mktemp cookies.XXXXXXXXXX)
netrc=$(mktemp netrc.XXXXXXXXXX)
chmod 0600 "$cookiejar" "$netrc"
function finish {
  rm -rf "$cookiejar" "$netrc"
}

trap finish EXIT
WGETRC="$wgetrc"

prompt_credentials() {
    echo "Enter your Earthdata Login or other provider supplied credentials"
    read -p "Username (mkbenneh): " username
    username=${username:-mkbenneh}
    read -s -p "Password: " password
    echo "machine urs.earthdata.nasa.gov login $username password $password" >> $netrc
    echo
}

exit_with_error() {
    echo
    echo "Unable to Retrieve Data"
    echo
    echo $1
    echo
    echo "https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf"
    echo
    exit 1
}

prompt_credentials
  detect_app_approval() {
    approved=`curl -s -b "$cookiejar" -c "$cookiejar" -L --max-redirs 5 --netrc-file "$netrc" https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf -w '\n%{http_code}' | tail  -1`
    if [ "$approved" -ne "200" ] && [ "$approved" -ne "301" ] && [ "$approved" -ne "302" ]; then
        # User didn't approve the app. Direct users to approve the app in URS
        exit_with_error "Please ensure that you have authorized the remote application by visiting the link below "
    fi
}

setup_auth_curl() {
    # Firstly, check if it require URS authentication
    status=$(curl -s -z "$(date)" -w '\n%{http_code}' https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf | tail -1)
    if [[ "$status" -ne "200" && "$status" -ne "304" ]]; then
        # URS authentication is required. Now further check if the application/remote service is approved.
        detect_app_approval
    fi
}

setup_auth_wget() {
    # The safest way to auth via curl is netrc. Note: there's no checking or feedback
    # if login is unsuccessful
    touch ~/.netrc
    chmod 0600 ~/.netrc
    credentials=$(grep 'machine urs.earthdata.nasa.gov' ~/.netrc)
    if [ -z "$credentials" ]; then
        cat "$netrc" >> ~/.netrc
    fi
}

fetch_urls() {
  if command -v curl >/dev/null 2>&1; then
      setup_auth_curl
      while read -r line; do
        # Get everything after the last '/'
        filename="${line##*/}"

        # Strip everything after '?'
        stripped_query_params="${filename%%\?*}"

        curl -f -b "$cookiejar" -c "$cookiejar" -L --netrc-file "$netrc" -g -o $stripped_query_params -- $line && echo || exit_with_error "Command failed with error. Please retrieve the data manually."
      done;
  elif command -v wget >/dev/null 2>&1; then
      # We can't use wget to poke provider server to get info whether or not URS was integrated without download at least one of the files.
      echo
      echo "WARNING: Can't find curl, use wget instead."
      echo "WARNING: Script may not correctly identify Earthdata Login integrations."
      echo
      setup_auth_wget
      while read -r line; do
        # Get everything after the last '/'
        filename="${line##*/}"

        # Strip everything after '?'
        stripped_query_params="${filename%%\?*}"

        wget --load-cookies "$cookiejar" --save-cookies "$cookiejar" --output-document $stripped_query_params --keep-session-cookies -- $line && echo || exit_with_error "Command failed with error. Please retrieve the data manually."
      done;
  else
      exit_with_error "Error: Could not find a command-line downloader.  Please install curl or wget"
  fi
}

fetch_urls <<'EDSCEOF'
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-15T23-26-01ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T01-04-21ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T02-42-46ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T04-21-16ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T05-59-41ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T07-38-07ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T09-16-32ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T10-54-57ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T12-33-22ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T14-11-48ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T15-50-13ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T17-28-38ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T19-07-03ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T20-45-28ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-16T22-23-54ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T00-02-19ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T01-40-44ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T03-19-09ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T04-57-34ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T06-36-00ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T08-14-25ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T09-52-50ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T11-31-15ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T13-09-40ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T14-48-06ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T16-26-31ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T18-04-56ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T19-43-21ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T21-21-46ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-17T23-00-12ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T00-38-37ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T02-17-02ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T03-55-27ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T05-33-52ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T07-12-18ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T08-50-43ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T10-29-08ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T12-07-33ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T13-45-59ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T15-24-24ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T17-02-49ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T18-41-14ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T20-19-39ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T21-58-05ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-18T23-36-30ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T01-14-55ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T02-53-20ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T04-31-45ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T06-10-11ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T07-48-36ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T09-27-01ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T11-05-26ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T12-43-51ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T14-22-17ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T16-00-42ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T17-39-07ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T19-17-32ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-19T20-55-57ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T00-12-48ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T01-51-13ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T03-29-38ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T05-08-03ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T06-46-29ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T08-24-54ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T10-03-19ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T11-41-44ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T13-20-09ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T14-58-35ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T16-37-00ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T18-15-25ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T19-53-50ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T21-32-16ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-20T23-10-41ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T00-49-06ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T02-27-31ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T04-05-56ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T05-44-22ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T07-22-47ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T09-01-12ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T10-39-37ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T12-18-02ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T13-56-28ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T15-34-53ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T17-13-18ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T18-51-43ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T20-30-08ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T22-08-34ZD.hdf
https://asdc.larc.nasa.gov/data/CALIPSO/LID_L2_05kmAPro-Standard-V4-51/2023/05/CAL_LID_L2_05kmAPro-Standard-V4-51.2023-05-21T23-46-59ZD.hdf
EDSCEOF
