#!/usr/bin/env bash
# Install the built RPMs in a clean Fedora and check what they ship.
# Usage (as root in a Fedora container): tests/test-rpms.sh <dir-with-rpms>
set -euo pipefail

DIR=$(realpath "$1")
dnf install -y "$DIR"/*.rpm

opensnitchd -version
state=$(systemctl is-enabled opensnitch.service 2>/dev/null || true)
[ "$state" != enabled ] || { echo "service must not be enabled on install" >&2; exit 1; }
echo "ok service state on install: $state"

for module in opensnitch opensnitch-dns opensnitch-procs; do
    object=/usr/lib/opensnitchd/ebpf/$module.o
    file "$object" | grep -q 'eBPF'
    echo "ok $object"
done

python3 -I - <<'EOF'
from opensnitch import proto
pb, grpc = proto.import_()
print("ok protobuf module", pb.__name__, grpc.__name__)
import opensnitch.service
print("ok opensnitch.service")
EOF

grep -q '"DefaultAction"' /etc/opensnitchd/default-config.json
[ "$(stat -c %a /etc/opensnitchd/rules)" = 700 ]
rpm -V opensnitch opensnitch-ui
echo "all checks passed"
