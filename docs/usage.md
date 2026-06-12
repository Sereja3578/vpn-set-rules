# Usage

## Clash Verge Rev / Mihomo

```yaml
rule-providers:
  abroad-ozon:
    type: http
    behavior: classical
    format: text
    path: ./rules/vpn-set-rules/abroad-ozon.list
    url: https://raw.githubusercontent.com/Sereja3578/vpn-set-rules/main/Abroad/ozon.list
    interval: 86400

rules:
  - RULE-SET,abroad-ozon,RU-SITES
```

## Stash

```yaml
rule-providers:
  abroad-ozon:
    type: http
    behavior: classical
    format: text
    path: ./rules/vpn-set-rules/abroad-ozon.list
    url: https://raw.githubusercontent.com/Sereja3578/vpn-set-rules/main/Abroad/ozon.list
    interval: 86400

rules:
  - RULE-SET,abroad-ozon,RU-SITES
```

Stash iOS ignores process-based rules due to Network Extension limitations, so
domain rules must remain the main cross-device routing mechanism.

## Shadowrocket

```text
[Rule]
RULE-SET,https://raw.githubusercontent.com/Sereja3578/vpn-set-rules/main/Abroad/ozon.list,RU-PROXY
FINAL,DIRECT
```

Shadowrocket adds the policy in the profile line. The external `.list` file
contains match rules only.

## Policy stays outside bundles

`policy`, routing policy, is the outbound decision such as `DIRECT`, `PROXY`,
`RU-SITES`, `RU-PROXY`, or `LOW-RESTRICT-FOREIGN`.

Bundle files describe only match criteria:

```text
DOMAIN-SUFFIX,ozon.ru
```

Client profiles decide the route:

```yaml
- RULE-SET,abroad-ozon,RU-SITES
```

This keeps one service list reusable in different profiles. For example, Ozon
can use a Russian route in an abroad profile and direct routing in a Russia
profile without duplicating the domain list.

## Important semantic split

Do not treat anti-block bundles for Russia as "Russian websites abroad" lists.

`legiz-ru` `ru-bundle` includes lists such as `itdoginfo-inside-russia`,
`no-russia-hosts`, `antifilter-community`, and `rknasnblock`. That makes it
useful for Russia anti-block routing, but too broad for an abroad profile where
only specific Russian services should use a Russian route.

If an Abroad profile temporarily keeps a broad anti-block source during
migration, place global-service direct exceptions above it. Example:

```yaml
- RULE-SET,common-instagram-meta,DIRECT
- RULE-SET,abroad-ozon,RU-SITES
- RULE-SET,legacy-ru-bundle,RU-SITES
```

The long-term target is to remove the broad `legacy-ru-bundle` from Abroad and
keep only narrow service bundles there.
