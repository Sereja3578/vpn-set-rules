#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
icloud_root=${repo_root:h}

clash_repo=${CLASH_CONFIG_REPO:-"$icloud_root/Clash Verge"}
stash_repo=${STASH_CONFIG_REPO:-"$HOME/Library/Mobile Documents/iCloud~ws~stash~icloud/Documents"}
shadowrocket_repo=${SHADOWROCKET_CONFIG_REPO:-"$HOME/Library/Mobile Documents/iCloud~com~liguangming~Shadowrocket/Documents"}

rc=0

fail() {
  print -u2 "$1"
  rc=1
}

require_file() {
  local file=$1
  [[ -f "$file" ]] || fail "missing-client-config: $file"
}

assert_absent() {
  local file=$1 pattern=$2 label=$3
  if [[ -f "$file" ]] && rg -n -- "$pattern" "$file" >/dev/null; then
    fail "$label: $file"
    rg -n -- "$pattern" "$file" >&2 || true
  fi
}

assert_present() {
  local file=$1 pattern=$2 label=$3
  if [[ -f "$file" ]] && ! rg -n -- "$pattern" "$file" >/dev/null; then
    fail "$label: $file"
  fi
}

abroad_yaml=(
  "$clash_repo/Abroad.example.yaml"
  "$stash_repo/Abroad.stash.example.yaml"
)

russia_yaml=(
  "$clash_repo/Russia.example.yaml"
  "$stash_repo/Russia.stash.example.yaml"
)

abroad_sr="$shadowrocket_repo/sr_nonru_basic.example.conf"
russia_sr="$shadowrocket_repo/sr_ru_geo.example.conf"

for file in $abroad_yaml $russia_yaml "$abroad_sr" "$russia_sr"; do
  require_file "$file"
done

for file in $abroad_yaml; do
  assert_absent "$file" 'RULE-SET,ru-bundle,RU' "abroad-broad-ru-bundle-routed-to-ru"
  assert_absent "$file" 'RULE-SET,rknasnblock,RU' "abroad-rknasnblock-routed-to-ru"
  for provider in common-whatsapp common-linkedin common-discord common-twitter-x common-google-ai; do
    assert_present "$file" "RULE-SET,${provider},DIRECT" "abroad-missing-foreign-direct-$provider"
  done
done

for file in $russia_yaml; do
  assert_absent "$file" 'RULE-SET,ru-bundle,DIRECT' "russia-broad-ru-bundle-direct"
  assert_absent "$file" 'RULE-SET,rknasnblock,DIRECT' "russia-rknasnblock-direct"
  assert_present "$file" 'RULE-SET,ru-bundle,PROXY' "russia-missing-ru-bundle-proxy-fallback"
  assert_present "$file" 'RULE-SET,rknasnblock,PROXY,no-resolve' "russia-missing-rknasnblock-proxy-fallback"
  for provider in common-whatsapp common-linkedin common-discord common-twitter-x common-google-ai; do
    assert_present "$file" "RULE-SET,${provider},PROXY" "russia-missing-foreign-proxy-$provider"
  done
done

assert_absent "$abroad_sr" 'ru-bundle.*RU' "shadowrocket-abroad-broad-ru-bundle-routed-to-ru"
for list in whatsapp linkedin discord twitter-x google-ai; do
  assert_present "$abroad_sr" "Common/${list}.list,DIRECT" "shadowrocket-abroad-missing-direct-$list"
  assert_present "$russia_sr" "Common/${list}.list,PROXY" "shadowrocket-russia-missing-proxy-$list"
done
assert_present "$russia_sr" 'Russia/youtube.list,PROXY' "shadowrocket-russia-missing-youtube-proxy"
assert_present "$russia_sr" 'Russia/ru-blocked-or-sensitive.list,PROXY' "shadowrocket-russia-missing-ru-blocked-proxy"

exit "$rc"
