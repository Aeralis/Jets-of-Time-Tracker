#!/usr/bin/env bash

# This script is used for building a zip file suitable for PopTracker/Emotracker.
# 
# It builds a zip file which abides excluding files per .gitattributes (like git archive)
# but dereferences all symlinks (making copies of their linked files).

set -euo pipefail

CWD="$(builtin pwd)"
GIT_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")"/.. && builtin pwd)"

function cleanup {
  ret=$?
  if [[ -z "${SKIP_CLEANUP:-}" ]]; then
    if [[ -n "${TEMP_DIR:-}" ]]; then 
      rm -rf "${TEMP_DIR}"
    fi
  else
    if [[ -n "${TEMP_DIR:-}" ]]; then 
      echo "Skipping cleanup of temporary files in ${TEMP_DIR}"
    fi
  fi
  exit $ret
}

trap cleanup EXIT

function preflight {
  # assure that tools used by this script are installed
  commands=(git tar zip unzip)
  for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" > /dev/null; then
      >&2 echo "This script requires $cmd!"
      exit 1
    fi
  done 

  if [[ -z "${RELEASE_ZIP}" ]]; then
    # if no specified name, generate a zip name
    RELEASE_ZIP="Jets-of-Time-Tracker-$(git rev-parse --short HEAD).zip"
    export RELEASE_ZIP
  fi

  # check if release zip already exists and prompt to overwrite
  if [[ -e "${RELEASE_ZIP}" ]]; then
    if [[ -n "${YES}" ]]; then
      echo "Overwriting existing ${RELEASE_ZIP}"
    else
      read -p "Overwrite existing ${RELEASE_ZIP}? [y/N] " -n 1 -r
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then exit 0; fi
      echo
    fi
  fi
}

function build_release {
  echo "Building release ${RELEASE_ZIP}"

  TEMP_DIR="${TEMP_DIR:-$(mktemp -d)}"
  export TEMP_DIR
  echo "* Building in ${TEMP_DIR}"

  # create an archive just to get a list of files that abides .gitattributes
  echo "* Creating git archive"
  cd "$GIT_ROOT" || (echo "Can't change to $GIT_ROOT directory!" && exit 1)
  git archive HEAD --format=tar -o "${TEMP_DIR}/archive.tar"

  # use list of non-directory files from initial archive tarball to produce a new tar
  # with symlinks dereferenced into copies, so can with EmoTracker
  echo "* Creating dereferenced tarball"
  tar -tf "${TEMP_DIR}/archive.tar" | grep -v '/$' > "${TEMP_DIR}/files.txt"
  tar -chf "${TEMP_DIR}/release.tar.gz" -T "${TEMP_DIR}/files.txt"

  # extract the new tar and zip it up
  echo "* Building release zip"
  cd "${TEMP_DIR}"
  rm -rf zip
  mkdir zip
  cd zip
  tar -xf ../release.tar.gz
  zip -q -r ../release.zip .
  cd "${CWD}"
  cp "${TEMP_DIR}/release.zip" "${RELEASE_ZIP}"

  # verify zip
  echo "* Verifying release zip"
  unzip -qt "${RELEASE_ZIP}" > /dev/null

  echo "Created release: ${RELEASE_ZIP}"
}

function usage {
  echo "./tools/release.sh [-o] [-y]"
  echo
  echo "-h     print this help"
  echo "-o     output zip filename to use"
  echo "-y     do not prompt (overwrites release zip)"
}

RELEASE_ZIP="${RELEASE_ZIP:-}"
YES="${YES:-}"
while getopts 'ho:y' flag; do
  case "${flag}" in
    h)
      usage
      exit 0
      ;;
    o)
      RELEASE_ZIP="${OPTARG}"
      ;;
    y)
      YES=1
      ;;
    *)
      usage
      exit 1
  esac
done
export RELEASE_ZIP YES
export YES

preflight
build_release
