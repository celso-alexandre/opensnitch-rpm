#!/usr/bin/env bash
# Fetch the pinned upstream commit, refuse it unless the maintainer's key signed it,
# generate the Go gRPC code, vendor the Go modules and pack it all as the RPM source.
# Usage: ./prepare-source.sh <out-dir>
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(realpath -m "$1")
. "$HERE/UPSTREAM"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
NAME=opensnitch-$UPSTREAM_COMMIT
SRC=$WORK/$NAME

git init -q "$SRC"
git -C "$SRC" fetch -q --depth 1 "$UPSTREAM_REPO" "$UPSTREAM_COMMIT"
git -C "$SRC" -c advice.detachedHead=false checkout -q FETCH_HEAD
[ "$(git -C "$SRC" rev-parse HEAD)" = "$UPSTREAM_COMMIT" ]

export GNUPGHOME=$WORK/gnupg
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import "$HERE/keys/upstream-maintainer.asc"
STATUS=$(git -C "$SRC" verify-commit --raw HEAD 2>&1) || { echo "$STATUS"; echo "upstream commit signature does not verify" >&2; exit 1; }
PRIMARY=$(awk '/VALIDSIG/{print $NF}' <<<"$STATUS")
if [ "$PRIMARY" != "$UPSTREAM_KEY_FINGERPRINT" ]; then
    echo "commit signed by $PRIMARY, expected $UPSTREAM_KEY_FINGERPRINT" >&2
    exit 1
fi
echo "upstream $UPSTREAM_COMMIT: good signature from $PRIMARY"

export GOBIN=$WORK/gobin PATH=$WORK/gobin:$PATH GOFLAGS=-mod=mod
PROTOBUF_VERSION=$(awk '$1=="google.golang.org/protobuf"{print $2}' "$SRC/daemon/go.mod")
go install "google.golang.org/protobuf/cmd/protoc-gen-go@$PROTOBUF_VERSION"
go install "google.golang.org/grpc/cmd/protoc-gen-go-grpc@$PROTOC_GEN_GO_GRPC_VERSION"
(cd "$SRC/proto" && protoc -I. ui.proto \
    --go_out=../daemon/ui/protocol/ --go-grpc_out=../daemon/ui/protocol/ \
    --go_opt=paths=source_relative --go-grpc_opt=paths=source_relative)
(cd "$SRC/daemon" && go mod vendor)

rm -rf "$SRC/.git"
mkdir -p "$OUT"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@0" \
    -C "$WORK" -czf "$OUT/$NAME.tar.gz" "$NAME"
echo "$OUT/$NAME.tar.gz"
