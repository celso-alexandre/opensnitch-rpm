#!/usr/bin/env bash
# Move the pins in UPSTREAM to the newest upstream commit signed by the pinned
# maintainer key and to the newest Fedora kernel series. Prints a one-line summary.
# Exit 0: UPSTREAM changed. Exit 3: nothing new.
# Runs in a Fedora container (needs dnf, git, gpg).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/UPSTREAM"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export GNUPGHOME=$WORK/gnupg
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import "$HERE/keys/upstream-maintainer.asc"

git init -q "$WORK/src"
git -C "$WORK/src" fetch -q --depth 200 "$UPSTREAM_REPO" HEAD

signed_by_maintainer() {
    local raw
    raw=$(git -C "$WORK/src" verify-commit --raw "$1" 2>&1) || return 1
    [ "$(awk '/VALIDSIG/{print $NF}' <<<"$raw")" = "$UPSTREAM_KEY_FINGERPRINT" ]
}

NEW_COMMIT=
for commit in $(git -C "$WORK/src" rev-list FETCH_HEAD); do
    [ "$commit" = "$UPSTREAM_COMMIT" ] && break
    if signed_by_maintainer "$commit"; then NEW_COMMIT=$commit; break; fi
done

NEW_KERNEL_SERIES=$(dnf -q repoquery --latest-limit 1 --qf '%{version}\n' kernel-devel | cut -d. -f1-2)
[ -n "$NEW_KERNEL_SERIES" ] || { echo "could not read the kernel-devel version" >&2; exit 1; }

SUMMARY=()
if [ -n "$NEW_COMMIT" ]; then
    DATE=$(git -C "$WORK/src" show -s --format=%cd --date=format:%Y%m%d "$NEW_COMMIT")
    VERSION=$(git -C "$WORK/src" show "$NEW_COMMIT:ui/opensnitch/version.py" | sed -nE "s/^version = '([^']+)'.*/\1/p")
    [ -n "$VERSION" ] || { echo "could not read the upstream version" >&2; exit 1; }
    sed -i -e "s/^UPSTREAM_COMMIT=.*/UPSTREAM_COMMIT=$NEW_COMMIT/" \
        -e "s/^UPSTREAM_DATE=.*/UPSTREAM_DATE=$DATE/" \
        -e "s/^UPSTREAM_VERSION=.*/UPSTREAM_VERSION=$VERSION/" \
        -e "s/^PACKAGE_RELEASE=.*/PACKAGE_RELEASE=1/" "$HERE/UPSTREAM"
    SUMMARY+=("opensnitch $VERSION~${DATE}git${NEW_COMMIT:0:7}")
fi
if [ "$NEW_KERNEL_SERIES" != "$KERNEL_SERIES" ]; then
    sed -i "s/^KERNEL_SERIES=.*/KERNEL_SERIES=$NEW_KERNEL_SERIES/" "$HERE/UPSTREAM"
    SUMMARY+=("kernel $NEW_KERNEL_SERIES")
fi

[ ${#SUMMARY[@]} -gt 0 ] || exit 3
(IFS=,; echo "${SUMMARY[*]}" | sed 's/,/, /g')
