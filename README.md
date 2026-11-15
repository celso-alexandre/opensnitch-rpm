# OpenSnitch RPMs for Fedora

Signed dnf repo with [OpenSnitch](https://github.com/evilsocket/opensnitch), the interactive application firewall, built for Fedora 44 and 45. Fedora does not package it.

## Install

```sh
sudo dnf config-manager addrepo --from-repofile=https://celso-alexandre.github.io/opensnitch-rpm/opensnitch.repo
sudo dnf install opensnitch opensnitch-ui
sudo systemctl enable --now opensnitch.service
```

The repo file points at `rpm/$releasever`, so `dnf system-upgrade` picks up the next release's build by itself. Repo files from before that (`baseurl=…/opensnitch-rpm/rpm`) still get the Fedora 44 build; replace them with the current `opensnitch.repo` before upgrading to Fedora 45.

Then start **OpenSnitch** from the menu. The daemon allows unknown connections until the UI connects and you decide; once your usual apps have rules, switch *Preferences → Nodes → Default action* to *deny*.

## What gets built

- **Source:** a pinned upstream commit (`UPSTREAM`). `prepare-source.sh` refuses to build unless that commit carries a valid signature from the maintainer key in `keys/upstream-maintainer.asc` (fingerprint pinned in `UPSTREAM`).
- **Go modules:** vendored at build time and checked against upstream's `go.sum` and the Go checksum database.
- **eBPF modules:** compiled against the Fedora `kernel-devel` series pinned in `UPSTREAM` (`KERNEL_SERIES`); the RPM release carries it (`…-5.k7.3.fc45`). Every Fedora release is built against the same series, so a kernel series Fedora has not shipped to all of them yet fails the build until it has.
- **UI:** upstream's Python UI, with dependencies from Fedora's own repos (no pip).
- The service is not enabled on install.
- Two patches on top of upstream (`patches/`):
  - The daemon sends `localhost` as the gRPC authority on unix sockets, as current grpc-go does. grpc-go 1.32 sends the socket path, which strict HTTP/2 servers reject.
  - With *Disable pop-ups* checked, the UI denies unknown connections right away (this attempt only) instead of opening a prompt. Upstream saves that setting but never applies it.

## Updates

Weekly, `check-update.yml` looks for a newer upstream commit signed by the maintainer key and for a new Fedora kernel series. Either one opens a PR on `auto/update-upstream`; the Build workflow builds and install-tests the RPMs and merges the PR when they pass. Merging publishes a GitHub release with the signed RPMs and refreshes the dnf repo on Pages.

## Signing

RPMs and repo metadata are signed with this repo's own key (`KEY.gpg` on the Pages site), held only in the `PKG_GPG_PRIVATE_KEY` / `PKG_GPG_KEY_ID` Actions secrets.

## Building locally

For each Fedora release (44, 45):

```sh
podman run --rm -v "$PWD:/w:Z" -w /w registry.fedoraproject.org/fedora:45 ./build.sh dist/rpm-fc45
podman run --rm -v "$PWD:/w:Z" -w /w registry.fedoraproject.org/fedora:45 bash -c 'dnf install -y file && tests/test-rpms.sh dist/rpm-fc45'
```

OpenSnitch is GPL-3.0-or-later; this packaging is too.
