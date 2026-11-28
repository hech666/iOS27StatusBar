#!/bin/sh
set -eu
cd "$(dirname "$0")"
SCHEME=${1:-roothide}
[ "$SCHEME" = roothide ] || { echo "Only the roothide package scheme is supported" >&2; exit 2; }
: "${THEOS:?THEOS must point to the Roothide Theos checkout}"
export THEOS_PACKAGE_SCHEME=roothide
export ARCHS=arm64e
VERSION=${PACKAGE_VERSION:-1.4.0~ios16native2+reconstructed.1}
case "$VERSION" in *[!A-Za-z0-9.+:~_-]*) echo "Invalid Debian version characters" >&2; exit 2;; esac
make clean THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64e DEBUG=0 FINALPACKAGE=1
make package THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64e DEBUG=0 FINALPACKAGE=1 PACKAGE_VERSION="$VERSION"
python3 scripts/verify-package.py
