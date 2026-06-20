# Enterprise VPN coexistence on macOS

This note covers a common macOS setup where a personal proxy/VPN client runs
at the same time as an enterprise VPN client such as Cisco Secure Client /
AnyConnect.

The important split is:

- outer path: traffic from the Mac to the public enterprise VPN gateway;
- inner path: traffic from the Mac to private corporate networks after the
  enterprise tunnel is connected.

For example, a router policy may send the public Cisco gateway through a home
OpenVPN client, while macOS must still send `10.0.0.0/8`, `172.16.0.0/12`, and
`192.168.0.0/16` corporate destinations through the Cisco `utun` interface.

## Rule of thumb

Keep RFC1918 private networks out of the proxy engine, but do not exclude them
from the TUN route when another VPN must own them.

Recommended enterprise coexistence model:

| Client | Proxy bypass | TUN route exclusion |
| --- | --- | --- |
| Stash | keep `10/8`, `172.16/12`, `192.168/16` in `Skip Proxy` | remove `10/8`, `172.16/12`, `192.168/16` from `Skip Tunnel Route` |
| Shadowrocket | keep `10/8`, `172.16/12`, `192.168/16` in `skip-proxy` | remove `10/8`, `172.16/12`, `192.168/16` from `tun-excluded-routes` |
| Clash Verge Rev / Mihomo | keep direct rules for private CIDRs | make sure `tun.route-exclude-address` does not exclude corporate private CIDRs |

For local home LAN access, exclude only the exact local subnet, for example
`192.168.50.0/24`, not the whole `192.168.0.0/16` range.

## Stash

For Cisco coexistence on macOS:

- `Include All Networks`: on
- `Include Local Networks`: on
- `Skip Proxy`: keep `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- `Skip Tunnel Route`: remove `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- Optional home LAN exclusion: add only the local subnet, such as
  `192.168.50.0/24`, to `Skip Tunnel Route`

Stash stores these UI settings in app preferences, not in the portable YAML
profile. Do not publish raw app preference files because they can contain device
names, local state, cached tiles, and secrets.

## Shadowrocket

Equivalent Shadowrocket settings:

```ini
skip-proxy = 192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,localhost,*.local,captive.apple.com
tun-excluded-routes = 100.64.0.0/10,127.0.0.0/8,169.254.0.0/16,192.0.0.0/24,192.0.2.0/24,192.88.99.0/24,198.51.100.0/24,203.0.113.0/24,224.0.0.0/4,255.255.255.255/32,239.255.255.250/32
```

If local LAN devices must stay outside the TUN route, add the narrow home subnet
to `tun-excluded-routes`, for example `192.168.50.0/24`.

## Clash Verge Rev / Mihomo

Mihomo exposes TUN route control in YAML. Avoid putting corporate private CIDRs
in `tun.route-exclude-address` when Cisco should route those networks.

Direct rules are still useful:

```yaml
rules:
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
```

These rules decide the outbound policy after traffic reaches the client. They
are not the same as excluding the networks from the TUN route.

## Corporate split DNS

## Failure pattern

A corporate host can work initially and later open a public website when all of
the following are true:

1. the corporate hostname has a different public DNS answer;
2. the proxy client uses public DNS over HTTPS in `fake-ip` mode;
3. a broad public suffix rule matches the corporate subdomain and sends it to a
   proxy instead of the enterprise VPN.

`fake-ip-filter` alone is not sufficient. It changes whether the client returns
a synthetic address, but does not select the correct corporate DNS server or
routing policy.

## Portable profile pattern

Keep real company suffixes in a private local rule-set that is not published by
this repository. A Stash/Mihomo profile can load that file as a local static
provider:

```yaml
rule-providers:
  corporate-local:
    behavior: classical
    format: text
    path: ./rules/private/corporate-local.list

rules:
  # This rule-set must precede broader public-domain or service bundles.
  - RULE-SET,corporate-local,DIRECT
```

The private file contains the actual `DOMAIN` / `DOMAIN-SUFFIX` entries. The
earlier `RULE-SET` keeps the resulting private destination on the Cisco route
instead of a general proxy group. Corporate split DNS should remain owned by the
enterprise VPN or by a separate private local DNS configuration; do not copy
company suffixes or DNS addresses into public examples.

Do not publish real corporate domains, DNS addresses, credentials, provider
URLs, or full managed profiles in reusable examples.

## Native macOS DNS verification

Use the native macOS resolver when checking application behavior:

```sh
scutil --dns
dscacheutil -q host -a name app.corp.example
route -n get app.corp.example
curl -skS -o /dev/null -D - https://app.corp.example/
```

`dig` and `nslookup` query DNS independently and can therefore disagree with
Safari, Chrome, and other applications that use the native resolver.

## Verification

Use the helper script from this repository:

```sh
TARGET_IP=10.10.10.10 EXPECTED_IFACE=utun8 CHECK_STASH_LIVE=1 scripts/check-enterprise-vpn-coexistence.zsh
```

For file checks:

```sh
SHADOWROCKET_CONF="$HOME/Library/Mobile Documents/iCloud~com~liguangming~Shadowrocket/Documents/sr_nonru_basic.conf" \
CLASH_CONFIG="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Clash Verge/Abroad.yaml" \
scripts/check-enterprise-vpn-coexistence.zsh
```

## Terms

`RFC1918`, Request for Comments 1918, private IPv4 networks. These are
`10.0.0.0/8`, `172.16.0.0/12`, and `192.168.0.0/16`; many enterprise VPNs use
them for internal networks.

`CIDR`, Classless Inter-Domain Routing, prefix notation such as `/16` or `/24`.
IPv4 has 32 bits. A `/16` fixes the first 16 bits and leaves the last 16 bits
variable, so `192.168.0.0/16` covers `192.168.0.0` through
`192.168.255.255`.

`TUN excluded routes`, routes that a client asks macOS to keep out of its TUN
interface. If a corporate network is excluded here, macOS may send it to Wi-Fi
instead of to the enterprise VPN interface.

## Sources

- Mihomo TUN docs: https://wiki.metacubex.one/en/config/inbound/tun/
- Clash Verge Rev bypass docs: https://www.clashverge.dev/guide/bypass.html
- Stash conflict with other VPNs: https://stash.wiki/en/faq/conflict-with-vpn
- Apple Network Extension `includeAllNetworks`: https://developer.apple.com/documentation/NetworkExtension/NEVPNProtocol/includeAllNetworks
- Apple Network Extension `excludeLocalNetworks`: https://developer.apple.com/documentation/NetworkExtension/NEVPNProtocol/excludeLocalNetworks
- RFC 1918 private address allocation: https://datatracker.ietf.org/doc/html/rfc1918
- Cisco DNS and split-DNS behavior: https://www.cisco.com/c/en/us/support/docs/security/anyconnect-secure-mobility-client/116016-technote-AnyConnect-00.html
- Mihomo DNS configuration and `nameserver-policy`: https://wiki.metacubex.one/en/config/dns/
- Cisco Community report of macOS corporate DNS falling back to public DNS: https://community.cisco.com/t5/vpn/vpn-and-dns-split-tunnels-with-anyconnect-on-macos/td-p/4411399
- Apple Community report of browser/native-resolver and `dig` disagreement: https://discussions.apple.com/thread/253766142
