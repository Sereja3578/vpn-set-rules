#!/usr/bin/env zsh
set -euo pipefail

private_cidrs=(
  "10.0.0.0/8"
  "172.16.0.0/12"
  "192.168.0.0/16"
)

rc=0

fail() {
  print -u2 "fail: $1"
  rc=1
}

warn() {
  print -u2 "warn: $1"
}

info() {
  print "info: $1"
}

contains_line() {
  local haystack=$1 needle=$2
  print -r -- "$haystack" | rg -q -- "(^|[[:space:],])${needle//./\\.}([[:space:],]|$)"
}

check_route() {
  local target=${TARGET_IP:-}
  [[ -n "$target" ]] || {
    info "TARGET_IP is not set; skipping live route check"
    return
  }

  local output iface
  output=$(route -n get "$target" 2>&1) || {
    fail "route lookup failed for $target: $output"
    return
  }

  iface=$(print -r -- "$output" | awk '/interface:/ {print $2; exit}')
  [[ -n "$iface" ]] || {
    fail "route lookup for $target did not report interface"
    print -u2 -- "$output"
    return
  }

  if [[ -n "${EXPECTED_IFACE:-}" && "$iface" != "$EXPECTED_IFACE" ]]; then
    fail "route for $target uses $iface, expected $EXPECTED_IFACE"
    print -u2 -- "$output"
    return
  fi

  if [[ "$iface" == "en0" || "$iface" == "en1" ]]; then
    warn "route for $target uses Wi-Fi/Ethernet interface $iface; this is suspicious for enterprise VPN private IPs"
    print -u2 -- "$output"
    rc=1
    return
  fi

  info "route for $target uses $iface"
}

plist_print() {
  local plist=$1 key=$2
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

check_stash_prefs() {
  if [[ -z "${CHECK_STASH_LIVE:-}" && -z "${STASH_PREFS:-}" ]]; then
    info "CHECK_STASH_LIVE/STASH_PREFS is not set; skipping Stash live settings"
    return
  fi

  local plist=${STASH_PREFS:-"$HOME/Library/Group Containers/group.ws.stash.app/Library/Preferences/group.ws.stash.app.plist"}
  [[ -f "$plist" ]] || {
    info "Stash preferences not found; skipping Stash live settings"
    return
  }

  local include_all include_local skip_tun skip_proxy
  include_all=$(plist_print "$plist" "group-stash-include-all-networks")
  include_local=$(plist_print "$plist" "group-stash-include-local-networks")
  skip_tun=$(plist_print "$plist" "group-stash-skip-tun-list")
  skip_proxy=$(plist_print "$plist" "group-stash-skip-proxy-list")

  [[ "$include_all" == "true" ]] || fail "Stash Include All Networks is not enabled"
  [[ "$include_local" == "true" ]] || fail "Stash Include Local Networks is not enabled"

  for cidr in $private_cidrs; do
    if contains_line "$skip_tun" "$cidr"; then
      fail "Stash Skip Tunnel Route contains enterprise private CIDR $cidr"
    fi
    if ! contains_line "$skip_proxy" "$cidr"; then
      fail "Stash Skip Proxy does not contain private CIDR $cidr"
    fi
  done

  info "checked Stash enterprise VPN preferences"
}

check_shadowrocket_conf() {
  local file=${SHADOWROCKET_CONF:-}
  [[ -n "$file" ]] || {
    info "SHADOWROCKET_CONF is not set; skipping Shadowrocket config check"
    return
  }
  [[ -f "$file" ]] || {
    fail "Shadowrocket config not found: $file"
    return
  }

  local skip_proxy tun_excluded
  skip_proxy=$(awk -F'=' '/^[[:space:]]*skip-proxy[[:space:]]*=/{print $2; exit}' "$file" | tr -d ' ')
  tun_excluded=$(awk -F'=' '/^[[:space:]]*tun-excluded-routes[[:space:]]*=/{print $2; exit}' "$file" | tr -d ' ')

  for cidr in $private_cidrs; do
    if ! contains_line "$skip_proxy" "$cidr"; then
      fail "Shadowrocket skip-proxy does not contain private CIDR $cidr"
    fi
    if contains_line "$tun_excluded" "$cidr"; then
      fail "Shadowrocket tun-excluded-routes contains enterprise private CIDR $cidr"
    fi
  done

  info "checked Shadowrocket enterprise VPN config: $file"
}

check_clash_config() {
  local file=${CLASH_CONFIG:-}
  [[ -n "$file" ]] || {
    info "CLASH_CONFIG is not set; skipping Clash/Mihomo config check"
    return
  }
  [[ -f "$file" ]] || {
    fail "Clash/Mihomo config not found: $file"
    return
  }

  local in_exclude=0 line
  while IFS= read -r line; do
    if [[ "$line" == "  route-exclude-address:" || "$line" == "  inet4-route-exclude-address:" ]]; then
      in_exclude=1
      continue
    fi

    if (( in_exclude )) && [[ ! "$line" =~ '^    - ' ]]; then
      in_exclude=0
    fi

    if (( in_exclude )); then
      for cidr in $private_cidrs; do
        [[ "$line" == *"$cidr"* ]] && fail "Clash/Mihomo route-exclude-address contains enterprise private CIDR $cidr"
      done
    fi
  done < "$file"

  info "checked Clash/Mihomo enterprise VPN config: $file"
}

check_route
check_stash_prefs
check_shadowrocket_conf
check_clash_config

exit "$rc"
