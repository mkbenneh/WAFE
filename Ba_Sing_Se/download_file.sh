#!/usr/bin/env bash
# Transfer one Earthdata-protected file with retries and resumability.
# Usage: download_file.sh URL OUTDIR [--netrc-file FILE] [--username USER --password PASS]
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 URL OUTDIR [--netrc-file FILE] [--username USER --password PASS]" >&2
  exit 64
fi
url=$1; outdir=$2; shift 2
netrc_file=; username=; password=
while [[ $# -gt 0 ]]; do
  case $1 in
    --netrc-file) netrc_file=${2:?missing value}; shift 2 ;;
    --username) username=${2:?missing value}; shift 2 ;;
    --password) password=${2:?missing value}; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 64 ;;
  esac
done
if [[ -n $netrc_file && ! -r $netrc_file ]]; then
  echo "Netrc file is missing or unreadable: $netrc_file" >&2
  exit 66
fi
mkdir -p "$outdir"
filename=$(basename "${url%%\?*}")
[[ -n $filename && $filename != / ]] || { echo "URL has no filename: $url" >&2; exit 64; }
target="$outdir/$filename"

if command -v curl >/dev/null 2>&1; then
  # The cookie jar preserves Earthdata's redirect/login session.
  cookie_jar="$outdir/.earthdata-cookies.txt"
  # --progress-bar displays transferred bytes and percentage without flooding the terminal.
  args=(--fail --location --progress-bar --show-error --continue-at - --retry 5
        --retry-delay 3 --connect-timeout 30 --cookie "$cookie_jar" --cookie-jar "$cookie_jar" --output "$target")
  if [[ -n $netrc_file ]]; then
    args+=(--netrc-file "$netrc_file")
  elif [[ -n $username && -n $password ]]; then
    args+=(--user "$username:$password")
  fi
  curl "${args[@]}" "$url"
elif command -v wget >/dev/null 2>&1; then
  args=(--continue --tries=5 --waitretry=3 --output-document="$target")
  [[ -n $username && -n $password ]] && args+=(--http-user="$username" --http-password="$password")
  wget "${args[@]}" "$url"
else
  echo "Neither curl nor wget is installed." >&2
  exit 69
fi
[[ -s $target ]] || { echo "Downloaded file is empty: $target" >&2; exit 1; }
printf 'Saved %s\n' "$target"
