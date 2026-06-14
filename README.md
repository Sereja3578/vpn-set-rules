# vpn-set-rules

Shared rule-set bundles for Clash Verge Rev, Stash, and Shadowrocket.

This repository is the source of truth for service/domain matching lists only.
Client profiles decide where matched traffic goes.

## Core rule

Bundle files must not contain routing policy.

Correct bundle:

```text
DOMAIN-SUFFIX,ozon.ru
DOMAIN-SUFFIX,ozonusercontent.com
```

Correct client profile usage:

```yaml
- RULE-SET,ozon,RU-SITES
```

```text
RULE-SET,https://raw.githubusercontent.com/Sereja3578/vpn-set-rules/main/Abroad/ozon.list,RU-PROXY
```

Why: one bundle answers "what service/domain do we match?", while each client
profile answers "where should this matched traffic go?". The same `ozon.list`
can be routed to a Russian proxy while abroad, but to `DIRECT` while in Russia.

## Layout

- `Abroad/` - Russian services that may need a Russian route while abroad.
- `Russia/` - services that may need a non-Russian route while in Russia.
- `Common/` - reusable service lists that can be routed differently per profile.
- `docs/` - integration examples and compatibility notes.

## Format

Files use Shadowrocket-style classical text rules:

```text
DOMAIN,example.com
DOMAIN-SUFFIX,example.com
DOMAIN-KEYWORD,example
IP-CIDR,203.0.113.0/24
```

Prefer exact `DOMAIN` or scoped `DOMAIN-SUFFIX` rules. Use `DOMAIN-KEYWORD`
only when there is no reasonable suffix/domain alternative, because it can
duplicate narrower rules and match unrelated domains.

This format is usable as:

- `behavior: classical`, `format: text` in Clash/Mihomo.
- `behavior: classical`, `format: text` in Stash.
- `RULE-SET,<raw-url>,<policy>` in Shadowrocket.

Use narrower bundles before broader bundles in client configs, because routing
rules are evaluated top to bottom and the first match wins.

Do not use broad Russia anti-block bundles as Abroad Russian-service bundles.
If a broad source contains useful entries, extract only the needed service niche
into a narrow bundle. See `docs/legiz-ru-abroad-audit.md`.

Before committing bundle changes, run:

```sh
scripts/check-bundles.zsh
scripts/check-dns-sanity.zsh
```

`check-dns-sanity.zsh` checks exact `DOMAIN,<host>` rules for live DNS answers.
It intentionally does not check `DOMAIN-SUFFIX` rules: a root domain can have
no A record while its subdomains still work. This helps catch stale renamed
hosts before they become hard-to-debug fake-IP failures in VPN clients.

## Sources checked

- Mihomo rule-provider docs: https://wiki.metacubex.one/en/config/rule-providers/
- Mihomo rule-provider content docs: https://wiki.metacubex.one/en/config/rule-providers/content/
- Stash rule-set docs: https://stash.wiki/en/rules/rule-set
- Stash rule types docs: https://stash.wiki/en/rules/rule-types
- Shadowrocket App Store feature list: https://apps.apple.com/app/shadowrocket/id932747118
- Shadowrocket list practice: https://github.com/blackmatrix7/ios_rule_script/tree/master/rule/Shadowrocket
