#!/usr/bin/env bash
# Sign the RPMs and assemble the GitHub Pages site:
#   rpm/<N>/          dnf metadata for Fedora N; the .rpm files stay on the GitHub release (xml:base)
#   rpm/              the Fedora 44 metadata again, for repo files from before rpm/<N> existed
#   opensnitch.repo   drop into /etc/yum.repos.d/ (baseurl uses $releasever)
#   KEY.gpg           the signing key
# <dist-dir> holds one rpm-fc<N>/ directory per Fedora release. The RPMs are signed in
# place, so upload them to the release after this runs.
# Usage: ./site.sh <dist-dir> <release-tag> <gpg-key-id> <out-dir>
# Needs: gpg with the secret key imported, rpm-sign, createrepo_c; GITHUB_REPOSITORY.
set -euo pipefail

DIST=$(realpath "$1") TAG=$2 KEY=$3 OUT=$(realpath -m "$4")
OWNER=${GITHUB_REPOSITORY%%/*} NAME=${GITHUB_REPOSITORY#*/}
SITE="https://$OWNER.github.io/$NAME"
RELEASE="https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/"
LEGACY_RELEASE=44

shopt -s nullglob
RELEASES=()
for d in "$DIST"/rpm-fc*/; do
    d=${d%/}
    RELEASES+=("${d##*/rpm-fc}")
done
[ ${#RELEASES[@]} -gt 0 ] || { echo "no rpm-fc<N>/ directories in $DIST" >&2; exit 1; }
[ -d "$DIST/rpm-fc$LEGACY_RELEASE" ] || { echo "missing rpm-fc$LEGACY_RELEASE (served at rpm/ too)" >&2; exit 1; }

for f in "$DIST"/rpm-fc*/*~*.rpm; do
    mv "$f" "${f//\~/_}"
done
rm -rf "$OUT" && mkdir -p "$OUT/rpm"
gpg --batch --armor --export "$KEY" >"$OUT/KEY.gpg"

rpmsign --define "_gpg_name $KEY" --addsign "$DIST"/rpm-fc*/*.rpm
rpm --import "$OUT/KEY.gpg"
rpm -K "$DIST"/rpm-fc*/*.rpm

repo() { # <rpm dir> <metadata out dir>
    createrepo_c --baseurl "$RELEASE" --outputdir "$2" "$1"
    gpg --batch --yes --armor --detach-sign -u "$KEY" "$2/repodata/repomd.xml"
}
for n in "${RELEASES[@]}"; do
    mkdir -p "$OUT/rpm/$n"
    repo "$DIST/rpm-fc$n" "$OUT/rpm/$n"
done
repo "$DIST/rpm-fc$LEGACY_RELEASE" "$OUT/rpm"

cat >"$OUT/opensnitch.repo" <<REPO
[opensnitch-$OWNER]
name=OpenSnitch ($GITHUB_REPOSITORY, built from signed upstream commits)
baseurl=$SITE/rpm/\$releasever
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$SITE/KEY.gpg
metadata_expire=6h
REPO

du -sh "$OUT"/* "$OUT"/rpm/*/
