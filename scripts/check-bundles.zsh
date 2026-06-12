#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
cd "$repo_root"

typeset -A seen
rc=0

while IFS= read -r file; do
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" == *,(DIRECT|PROXY|REJECT|RU-SITES|RU-PROXY|LOW-RESTRICT-FOREIGN)(|,*) ]]; then
      print -u2 "policy-in-bundle: $file: $line"
      rc=1
    fi

    if [[ -n ${seen[$line]-} ]]; then
      print -u2 "duplicate-rule: $line"
      print -u2 "  first: ${seen[$line]}"
      print -u2 "  again: $file"
      rc=1
    else
      seen[$line]=$file
    fi
  done < "$file"
done < <(find . -name '*.list' | sort)

while IFS= read -r hit; do
  file=${hit%%:*}
  rest=${hit#*:}
  line_no=${rest%%:*}
  line=${rest#*:}
  keyword=${line#DOMAIN-KEYWORD,}

  if rg -n "^(DOMAIN|DOMAIN-SUFFIX),[^,]*${keyword}[^,]*$" "$file" >/dev/null; then
    print -u2 "keyword-overlap: $file:$line_no: $line"
    print -u2 "  narrower rules in the same file already include '$keyword'"
    rc=1
  fi
done < <(rg -n '^DOMAIN-KEYWORD,' . --glob '*.list' || true)

exit "$rc"
