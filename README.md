# OpenSnitch RPMs for Fedora

Signed dnf repo with [OpenSnitch](https://github.com/evilsocket/opensnitch), the interactive application firewall, built for Fedora 44. Fedora does not package it.

## Install

```sh
sudo dnf config-manager addrepo --from-repofile=https://celso-alexandre.github.io/opensnitch-rpm/opensnitch.repo
sudo dnf install opensnitch opensnitch-ui
sudo systemctl enable --now opensnitch.service
```

Then start **OpenSnitch** from the menu. The daemon allows unknown connections until the UI connects and you decide; once your usual apps have rules, switch *Preferences → Nodes → Default action* to *deny*.

## What gets built

- **Source:** a pinned upstream commit (`UPSTREAM`). `prepare-source.sh` refuses to build unless that commit carries a valid signature from the maintainer key in `keys/upstream-maintainer.asc` (fingerprint pinned in `UPSTREAM`).
- **Go modules:** vendored at build time and checked against upstream's `go.sum` and the Go checksum database.
- **eBPF modules:** compiled against the Fedora `kernel-devel` series pinned in `UPSTREAM` (`KERNEL_SERIES`); the RPM release carries it (`…-1.k7.3.fc44`).
- **UI:** upstream's Python UI, with dependencies from Fedora's own repos (no pip).
- The service is not enabled on install.
- One patch on top of upstream (`patches/`): with *Disable pop-ups* checked, the UI denies unknown connections right away (this attempt only) instead of opening a prompt. Upstream saves that setting but never applies it.

## Updates

Weekly, `check-update.yml` looks for a newer upstream commit signed by the maintainer key and for a new Fedora kernel series. Either one opens a PR on `auto/update-upstream`; the Build workflow builds and install-tests the RPMs and merges the PR when they pass. Merging publishes a GitHub release with the signed RPMs and refreshes the dnf repo on Pages.

## Signing

RPMs and repo metadata are signed with this repo's own key (`KEY.gpg` on the Pages site), held only in the `PKG_GPG_PRIVATE_KEY` / `PKG_GPG_KEY_ID` Actions secrets.

## Building locally

```sh
podman run --rm -v "$PWD:/w:Z" -w /w registry.fedoraproject.org/fedora:44 ./build.sh dist
podman run --rm -v "$PWD:/w:Z" -w /w registry.fedoraproject.org/fedora:44 bash -c 'dnf install -y file && tests/test-rpms.sh dist'
```

OpenSnitch is GPL-3.0-or-later; this packaging is too.
