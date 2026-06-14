#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
cd "$repo_root"

timeout=${DNS_TIMEOUT:-8}
rc=0

while IFS=$'\t' read -r domain file line_no; do
  [[ -z "$domain" ]] && continue

  json=$(curl -sS --connect-timeout "$timeout" \
    "https://cloudflare-dns.com/dns-query?name=${domain}&type=A" \
    -H 'accept: application/dns-json') || {
      print -u2 "dns-query-failed: $domain ($file:$line_no)"
      rc=1
      continue
    }

  result=$(ruby -rjson -e '
    j = JSON.parse(STDIN.read)
    status = j["Status"]
    answers = (j["Answer"] || []).length
    print "#{status}\t#{answers}"
  ' <<< "$json") || {
    print -u2 "dns-json-parse-failed: $domain ($file:$line_no)"
    rc=1
    continue
  }

  dns_status=${result%%$'\t'*}
  answers=${result#*$'\t'}

  if [[ "$dns_status" != "0" || "$answers" == "0" ]]; then
    print -u2 "dns-suspect-domain: $domain ($file:$line_no) status=$dns_status answers=$answers"
    rc=1
  fi
done < <(
  ruby - <<'RUBY'
    Dir.glob('{Abroad,Common,Russia}/*.list').sort.each do |file|
      File.readlines(file, chomp: true).each_with_index do |line, idx|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        next unless line =~ /^DOMAIN,([^,\s]+)$/

        puts "#{$1}\t#{file}\t#{idx + 1}"
      end
    end
RUBY
)

exit "$rc"
