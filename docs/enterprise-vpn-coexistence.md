# Enterprise VPN coexistence

Clash/Mihomo or Stash can coexist with Cisco Secure Client, but corporate DNS
and routing exceptions belong in each local client profile, not in shared
service bundles.

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

Keep real company suffixes and DNS addresses in a private/local profile. Replace
the placeholders below with values supplied by the enterprise VPN:

```yaml
dns:
  nameserver-policy:
    "+.corp.example":
      - 10.0.0.53
      - 10.0.0.54

rules:
  # This exception must precede broader public-domain or service bundles.
  - DOMAIN-SUFFIX,corp.example,DIRECT
```

`nameserver-policy` selects the corporate resolver for the suffix. The earlier
`DIRECT` rule keeps the resulting private destination on the Cisco route instead
of a general proxy group. Private DNS addresses must already be reachable through
the enterprise VPN.

Do not publish real corporate domains, DNS addresses, credentials, provider
URLs, or full managed profiles in reusable examples.

## Verification on macOS

Use the native macOS resolver when checking application behavior:

```sh
scutil --dns
dscacheutil -q host -a name app.corp.example
route -n get app.corp.example
curl -skS -o /dev/null -D - https://app.corp.example/
```

`dig` and `nslookup` query DNS independently and can therefore disagree with
Safari, Chrome, and other applications that use the native resolver.

## References

- Cisco DNS and split-DNS behavior: https://www.cisco.com/c/en/us/support/docs/security/anyconnect-secure-mobility-client/116016-technote-AnyConnect-00.html
- Mihomo DNS configuration and `nameserver-policy`: https://wiki.metacubex.one/en/config/dns/
- Cisco Community report of macOS corporate DNS falling back to public DNS: https://community.cisco.com/t5/vpn/vpn-and-dns-split-tunnels-with-anyconnect-on-macos/td-p/4411399
- Apple Community report of browser/native-resolver and `dig` disagreement: https://discussions.apple.com/thread/253766142
