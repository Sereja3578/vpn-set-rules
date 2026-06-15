# legiz-ru ru-bundle audit for Abroad profiles

## Why this audit exists

The Abroad profile must mean: Russian services that need a Russian route while
the user is outside Russia.

The `legiz-ru` `ru-bundle` has a different meaning: domains and IP ranges useful
for anti-block routing from inside Russia. It includes broad lists such as:

- `itdoginfo-inside-russia`
- `no-russia-hosts`
- `antifilter-community`
- `rknasnblock`

Because of that, `ru-bundle` can contain non-Russian services such as Instagram,
Meta, OpenAI, Discord, Twitter/X, and YouTube. In an Abroad profile, routing
those through a Russian route is semantically wrong and can break otherwise
working direct access.

## Migration rule

Do not replace `ru-bundle` in Abroad with another broad bundle.

When a domain from `ru-bundle` is useful for Abroad, extract it into a narrow
service bundle and place that bundle in the correct semantic group:

- Russian service needed abroad: `Abroad/<service>.list`
- Global service that must stay direct abroad: `Common/<service>.list`
- Service blocked from Russia: `Russia/<service>.list`

The policy still stays in the client profile. For example:

```yaml
- RULE-SET,common-instagram-meta,DIRECT
- RULE-SET,abroad-ozon,RU-SITES
```

## Checked source files

The `legiz-ru` repository publishes text/YAML sources next to binary `.mrs`
files, so the bundle can be audited without reversing `.mrs`:

- `ru-bundle/rule.list`
- `ru-bundle/rule.yaml`
- `ru-bundle/itdoginfo-inside-russia.yaml`
- `ru-bundle/no-russia-hosts.yaml`
- `ru-bundle/antifilter-community.yaml`
- `ru-bundle/rknasnblock.list`

## Current observed collision classes

Examples observed in `ru-bundle/rule.list` during the initial audit:

- Instagram / Meta: `instagram.com`, `cdninstagram.com`, `facebook.com`, `fbcdn.net`
- OpenAI: `chatgpt.com`, `openai.com`, `api.openai.com`
- Discord: `discord.com`, `discord.gg`, `discordapp.net`
- Twitter/X: `twitter.com`, `x.com`, `twimg.com`
- YouTube-related CDN: `googlevideo.com`

These are not "Russian services abroad". If a temporary Abroad profile still
keeps any broad external anti-block bundle, these classes need explicit direct
exceptions above it.

## Practical conclusion

For Abroad profiles, prefer our narrow bundles:

- `Abroad/ozon.list`
- `Abroad/yandex.list`
- `Abroad/mailru.list`
- `Abroad/vk.list`
- `Abroad/rutube.list`
- `Abroad/mts.list`
- `Abroad/tbank.list`
- `Common/ru-tlds.list`

Treat `legiz-ru` `ru-bundle` as a Russia anti-block source, not as an Abroad
Russian-services source.

For Russia profiles, do not place `ru-bundle` as `DIRECT` above foreign-service
proxy exceptions. That sends domains such as `whatsapp.net`, `linkedin.com`,
`discord.com`, `x.com`, and `openai.com` directly from Russia, where they are
blocked, restricted, or unsupported. If a Russia profile keeps `ru-bundle`, use
it as a late broad `PROXY` fallback after:

- curated foreign-service bundles (`Common/openai.list`, `Common/whatsapp.list`,
  `Common/linkedin.list`, `Common/discord.list`, `Common/twitter-x.list`, etc.);
- Russian blocked/sensitive exceptions that should use `PROXY`;
- direct Russian service bundles and broad Russian TLD direct rules.
