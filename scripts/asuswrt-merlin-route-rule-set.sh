#!/bin/sh

# Maintain source-and-destination ip rules from exact DOMAIN entries in a
# policy-free rule-set. Intended for Asuswrt-Merlin with an existing VPN
# Director/OpenVPN routing table such as ovpnc2.

set -u

CONFIG_FILE=${CONFIG_FILE:-/jffs/configs/ru-restricted-services.conf}

if [ ! -r "$CONFIG_FILE" ]; then
  logger -t ru-restricted-routes "missing config: $CONFIG_FILE"
  exit 1
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

: "${RULESET_URL:?RULESET_URL is required}"
: "${SOURCE_CIDR:?SOURCE_CIDR is required}"
: "${ROUTE_TABLE:?ROUTE_TABLE is required}"

RULE_PRIORITY=${RULE_PRIORITY:-10100}
DNS_SERVERS=${DNS_SERVERS:-${DNS_SERVER:-127.0.0.1}}
CACHE_FILE=${CACHE_FILE:-/jffs/configs/ru-restricted-services.list}
STATE_FILE=${STATE_FILE:-/tmp/ru-restricted-services.ips}
STATUS_MAP_FILE=${STATUS_MAP_FILE:-/tmp/ru-restricted-services.map}
STATUS_JS=${STATUS_JS:-/www/user/ru-restricted-services-status.js}
LOCK_DIR=${LOCK_DIR:-/tmp/ru-restricted-services.lock}
TMP_PREFIX=/tmp/ru-restricted-services.$$

cleanup() {
  rm -f "$TMP_PREFIX.rules" "$TMP_PREFIX.domains" "$TMP_PREFIX.ips" \
    "$TMP_PREFIX.answers" "$TMP_PREFIX.map" "$TMP_PREFIX.status.js"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  logger -t ru-restricted-routes "another refresh is already running"
  exit 0
fi
trap cleanup EXIT HUP INT TERM

download_rules() {
  if which curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 30 "$RULESET_URL" -o "$TMP_PREFIX.rules"
  else
    wget -q -T 30 -O "$TMP_PREFIX.rules" "$RULESET_URL"
  fi
}

if download_rules && grep -q '^DOMAIN,[A-Za-z0-9._-][A-Za-z0-9._-]*$' "$TMP_PREFIX.rules"; then
  cp "$TMP_PREFIX.rules" "$CACHE_FILE"
elif [ -r "$CACHE_FILE" ]; then
  cp "$CACHE_FILE" "$TMP_PREFIX.rules"
  logger -t ru-restricted-routes "download failed; using cached rule-set"
else
  logger -t ru-restricted-routes "download failed and no cache is available"
  exit 1
fi

awk -F, '$1 == "DOMAIN" && NF == 2 { print $2 }' "$TMP_PREFIX.rules" \
  | sort -u > "$TMP_PREFIX.domains"

if [ ! -s "$TMP_PREFIX.domains" ]; then
  logger -t ru-restricted-routes "rule-set has no exact DOMAIN entries"
  exit 1
fi

: > "$TMP_PREFIX.ips"
: > "$TMP_PREFIX.map"
while IFS= read -r domain; do
  : > "$TMP_PREFIX.answers"
  for dns_server in $DNS_SERVERS; do
    nslookup "$domain" "$dns_server" 2>/dev/null \
      | awk '/^Name:/ { answer = 1; next } answer && /^Address [0-9]+: / { print $3 }' \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
      >> "$TMP_PREFIX.answers"
  done
  sort -u "$TMP_PREFIX.answers" -o "$TMP_PREFIX.answers"
  while IFS= read -r ip; do
    [ -n "$ip" ] || continue
    printf '%s\t%s\n' "$domain" "$ip" >> "$TMP_PREFIX.map"
    printf '%s\n' "$ip" >> "$TMP_PREFIX.ips"
  done < "$TMP_PREFIX.answers"
done < "$TMP_PREFIX.domains"

sort -u "$TMP_PREFIX.ips" -o "$TMP_PREFIX.ips"
sort -u "$TMP_PREFIX.map" -o "$TMP_PREFIX.map"

if [ ! -s "$TMP_PREFIX.ips" ]; then
  logger -t ru-restricted-routes "DNS returned no IPv4 addresses; keeping existing rules"
  exit 1
fi

[ -r "$STATE_FILE" ] || : > "$STATE_FILE"
SOURCE_IP=${SOURCE_CIDR%/32}

while IFS= read -r ip; do
  if grep -qxF "$ip" "$STATE_FILE" \
    && ip rule show | grep -qF "from $SOURCE_IP to $ip lookup $ROUTE_TABLE"; then
    continue
  fi
  ip rule add priority "$RULE_PRIORITY" from "$SOURCE_CIDR" to "$ip/32" table "$ROUTE_TABLE" \
    || logger -t ru-restricted-routes "failed to add route for $ip"
done < "$TMP_PREFIX.ips"

while IFS= read -r ip; do
  [ -n "$ip" ] || continue
  grep -qxF "$ip" "$TMP_PREFIX.ips" && continue
  ip rule del priority "$RULE_PRIORITY" from "$SOURCE_CIDR" to "$ip/32" table "$ROUTE_TABLE" 2>/dev/null \
    || logger -t ru-restricted-routes "failed to remove stale route for $ip"
done < "$STATE_FILE"

cp "$TMP_PREFIX.ips" "$STATE_FILE"
cp "$TMP_PREFIX.map" "$STATUS_MAP_FILE"

write_status_js() {
  [ -d "${STATUS_JS%/*}" ] || return 0

  checked_at=$(date '+%Y-%m-%d %H:%M:%S %Z')
  route_iface=$(ip route show table "$ROUTE_TABLE" 2>/dev/null \
    | awk '/^default / { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
  tunnel_state=down
  if [ -n "$route_iface" ] && ip link show "$route_iface" 2>/dev/null | grep -q 'UP'; then
    tunnel_state=up
  fi

  active_rules=0
  while IFS= read -r ip; do
    if ip rule show | grep -qF "from $SOURCE_IP to $ip lookup $ROUTE_TABLE"; then
      active_rules=$((active_rules + 1))
    fi
  done < "$STATE_FILE"

  {
    printf 'window.ruRestrictedStatus = {'
    printf '"checkedAt":"%s",' "$checked_at"
    printf '"sourceCidr":"%s",' "$SOURCE_CIDR"
    printf '"routeTable":"%s",' "$ROUTE_TABLE"
    printf '"routeInterface":"%s",' "$route_iface"
    printf '"tunnelState":"%s",' "$tunnel_state"
    printf '"activeRules":%s,' "$active_rules"
    printf '"resolvedIps":%s,' "$(wc -l < "$STATE_FILE" | tr -d ' ')"
    printf '"domains":['
    first_domain=1
    while IFS= read -r domain; do
      [ -n "$domain" ] || continue
      [ "$first_domain" -eq 1 ] || printf ','
      first_domain=0
      printf '{"name":"%s","ips":[' "$domain"
      first_ip=1
      awk -F '\t' -v domain="$domain" '$1 == domain { print $2 }' "$STATUS_MAP_FILE" \
        | while IFS= read -r ip; do
            [ "$first_ip" -eq 1 ] || printf ','
            first_ip=0
            printf '"%s"' "$ip"
          done
      printf ']}'
    done < "$TMP_PREFIX.domains"
    printf ']};\n'
  } > "$TMP_PREFIX.status.js" && mv "$TMP_PREFIX.status.js" "$STATUS_JS"
}

write_status_js || logger -t ru-restricted-routes "failed to update web status"
logger -t ru-restricted-routes "active IPv4 routes: $(wc -l < "$STATE_FILE" | tr -d ' ')"
