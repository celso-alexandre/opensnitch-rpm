#!/usr/bin/env bash
# Build the RPMs. Runs inside a Fedora container (CI) or locally:
#   podman run --rm -v "$PWD:/w:Z" -w /w registry.fedoraproject.org/fedora:44 ./build.sh dist
# Usage: ./build.sh <out-dir>
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(realpath -m "$1")
. "$HERE/UPSTREAM"

if [ "$(id -u)" = 0 ]; then
    dnf install -y --setopt=install_weak_deps=False \
        git gnupg2 golang protobuf-compiler rpm-build \
        gcc clang llvm make kernel-devel libnetfilter_queue-devel libpcap-devel \
        systemd-rpm-macros python3-devel python3-setuptools python3-wheel python3-pip \
        pyproject-rpm-macros desktop-file-utils
fi

TOP=$(mktemp -d)
trap 'rm -rf "$TOP"' EXIT
mkdir -p "$TOP"/{SOURCES,SPECS}
"$HERE/prepare-source.sh" "$TOP/SOURCES"

rpmbuild -bb "$HERE/opensnitch.spec" \
    --define "_topdir $TOP" \
    --define "commit $UPSTREAM_COMMIT" \
    --define "snapdate $UPSTREAM_DATE" \
    --define "upstream_version $UPSTREAM_VERSION" \
    --define "pkgrel $PACKAGE_RELEASE" \
    --define "kernel_series $KERNEL_SERIES"

mkdir -p "$OUT"
find "$TOP/RPMS" -name '*.rpm' -exec cp -t "$OUT" {} +
ls -l "$OUT"
