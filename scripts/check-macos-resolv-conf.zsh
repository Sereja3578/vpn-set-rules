#!/usr/bin/env zsh
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

if [[ -e /etc/resolv.conf ]]; then
  exit 0
fi

cat >&2 <<'MSG'
macos-resolv-conf-missing: /etc/resolv.conf does not exist.

Some TUN/DNS clients, including Mihomo-based setups, can still read the
legacy resolver file even though macOS applications usually use
SystemConfiguration. Fix it with:

  sudo ln -sf /var/run/resolv.conf /etc/resolv.conf
MSG

exit 1
