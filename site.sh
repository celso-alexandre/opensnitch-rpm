#!/usr/bin/env bash
# Sign the RPMs and assemble the GitHub Pages site:
#   rpm/              dnf metadata; the .rpm files stay on the GitHub release (xml:base)
#   opensnitch.repo   drop into /etc/yum.repos.d/
#   KEY.gpg           the signing key
# The RPMs in <dist> are signed in place, so upload them to the release after this runs.
# Usage: ./site.sh <dist-dir> <release-tag> <gpg-key-id> <out-dir>
# Needs: gpg with the secret key imported, rpm-sign, createrepo_c; GITHUB_REPOSITORY.
set -euo pipefail

DIST=$(realpath "$1") TAG=$2 KEY=$3 OUT=$(realpath -m "$4")
OWNER=${GITHUB_REPOSITORY%%/*} NAME=${GITHUB_REPOSITORY#*/}
SITE="https://$OWNER.github.io/$NAME"
RELEASE="https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/"

for f in "$DIST"/*~*.rpm; do
    [ -e "$f" ] && mv "$f" "${f//\~/_}"
done
rm -rf "$OUT" && mkdir -p "$OUT/rpm"
gpg --batch --armor --export "$KEY" >"$OUT/KEY.gpg"

rpmsign --define "_gpg_name $KEY" --addsign "$DIST"/*.rpm
rpm --import "$OUT/KEY.gpg"
rpm -K "$DIST"/*.rpm
createrepo_c --baseurl "$RELEASE" --outputdir "$OUT/rpm" "$DIST"
gpg --batch --yes --armor --detach-sign -u "$KEY" "$OUT/rpm/repodata/repomd.xml"
cat >"$OUT/opensnitch.repo" <<EOF
[opensnitch-$OWNER]
name=OpenSnitch ($GITHUB_REPOSITORY, built from signed upstream commits)
baseurl=$SITE/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$SITE/KEY.gpg
metadata_expire=6h
EOF

du -sh "$OUT"/*
