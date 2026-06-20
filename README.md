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

## Routing model

- Abroad profile: Russian services -> `RU-SITES` / `RU-PROXY`; global services
  -> `DIRECT` unless a service has its own reason to use a foreign proxy.
- Russia profile: Russian services and ordinary Russian TLDs -> `DIRECT`;
  global services restricted in Russia -> `PROXY` / `LOW-RESTRICT-FOREIGN`.
- Broad anti-block sources such as `legiz-ru` `ru-bundle` must never be routed
  to a Russian proxy in Abroad profiles. In Russia profiles, if kept at all,
  place it after direct Russian-service/TLD rules and route it to a foreign
  proxy, because it mostly represents "things that may need anti-block routing
  from inside Russia", not "Russian services".

Before committing bundle changes, run:

```sh
scripts/check-bundles.zsh
scripts/check-dns-sanity.zsh
scripts/check-client-routing.zsh
scripts/check-macos-resolv-conf.zsh
scripts/check-enterprise-vpn-coexistence.zsh
```

`check-dns-sanity.zsh` checks exact `DOMAIN,<host>` rules for live DNS answers.
It intentionally does not check `DOMAIN-SUFFIX` rules: a root domain can have
no A record while its subdomains still work. This helps catch stale renamed
hosts before they become hard-to-debug fake-IP failures in VPN clients.

`check-client-routing.zsh` checks the sibling Clash Verge, Stash, and
Shadowrocket example repositories for the route-order invariants that prevent
foreign services from being sent to a Russian exit in Abroad profiles, and broad
anti-block bundles from being sent direct in Russia profiles.

`check-macos-resolv-conf.zsh` is a local macOS preflight for TUN/DNS clients. If
`/etc/resolv.conf` is missing, Mihomo-based clients can fail DNS resolution even
when normal macOS apps still resolve names. Fix the host with:

```sh
sudo ln -sf /var/run/resolv.conf /etc/resolv.conf
```

This is a system prerequisite, not a portable rule-set entry, so it cannot be
solved inside Clash/Stash/Shadowrocket YAML alone.

For coexistence with an enterprise VPN, including corporate split DNS,
a local `DIRECT` exception ahead of broader public-domain bundles, and correct
handling of private networks by the macOS TUN route, see
`docs/enterprise-vpn-coexistence.md`.

`check-enterprise-vpn-coexistence.zsh` checks this coexistence pattern for
clients running together with enterprise VPNs such as Cisco Secure Client /
AnyConnect. It verifies that corporate private networks are not excluded from
the TUN route while still bypassing the proxy engine.

## Asuswrt-Merlin router status

`scripts/asuswrt-merlin-route-rule-set.sh` can maintain source-and-destination
`ip rule` entries for exact `DOMAIN` rules on an Asuswrt-Merlin router. It also
writes a read-only status snapshot to RAM at
`/www/user/ru-restricted-services-status.js` after each successful refresh.

The optional WebUI files are:

- `scripts/asuswrt-merlin-ru-route-status.asp` - the read-only status page;
- `scripts/asuswrt-merlin-install-ru-route-status.sh` - an idempotent Addons API
  installer that mounts the page as a `Tools` tab.

The page displays the source client, routing table/interface, active rule count,
and the current domain-to-IPv4 mapping. It has no Apply action and does not edit
VPN Director, NVRAM, or OpenVPN client state. Call the installer from
`/jffs/scripts/services-start` so the RAM-backed page is restored after reboot.

## Sources checked

- Mihomo rule-provider docs: https://wiki.metacubex.one/en/config/rule-providers/
- Mihomo rule-provider content docs: https://wiki.metacubex.one/en/config/rule-providers/content/
- Stash rule-set docs: https://stash.wiki/en/rules/rule-set
- Stash rule types docs: https://stash.wiki/en/rules/rule-types
- Shadowrocket App Store feature list: https://apps.apple.com/app/shadowrocket/id932747118
- Shadowrocket list practice: https://github.com/blackmatrix7/ios_rule_script/tree/master/rule/Shadowrocket
- Asuswrt-Merlin Addons API: https://github.com/RMerl/asuswrt-merlin/wiki/Addons-API
