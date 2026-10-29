# Rasen Falcon LDAP identity deployment contribution — dev22

This directory closes the LDAP side of RF-011/B105 without inventing a second
deployment engine. General ooRexx Deployment remains staging/install authority;
the Rasen Falcon delivery role remains activation/acceptance authority.

Delivered here:

- `bin/rasenfalcon_ldap_service.rex`: owned LDAP server bootstrap over the
  persistent Identity Directory, NoSQLServer, Secret Broker and mandatory LDAPS.
- `rasenfalcon-ldap.service`: non-root hardened systemd unit.
- `ldap.env.example`: configuration shape with no credentials.
- `ldap-secrets.map.example`: secret-reference to environment-variable mapping;
  raw secret values are forbidden.

The bootstrap fails closed unless the durable directory already contains an
ACTIVE `resource:directory`. It does not provision people, ACLs, credentials or
service accounts at startup; provisioning is semantic authority and must have a
separate reviewed transaction/evidence path.

The production service is LDAPS-only. TLS certificate/private-key paths are
mandatory and use the package's OpenSSL/Foreign Runtime TLS provider. There is no
plaintext production fallback and no `slapd` dependency.

## Rasen Falcon role integration

A role builder should install the complete sealed LDAP dependency namespace
under `/opt/rasenfalcon/ldap`, the unit at
`/etc/systemd/system/rasenfalcon-ldap.service`, `ldap.env` and the secret map
under `/etc/rasenfalcon`, and persistent state under
`/var/lib/rasenfalcon-ldap`.

The existing Rasen Falcon `identity` role already requires:

- `rasenfalcon-ldap.service`
- `ready:ldap_bind`
- `e2e:ldap_revoke`
- `e2e:sign_verify_revoke`

This package supplies the daemon side only. Those live protocol tests must use a
real provisioned test identity and actual private-CA/TLS material; they must not
be replaced by fixture PASS scripts. Signing remains Crypto/PKI authority, not
LDAP authority.

## State claim

SOURCE/DEPLOYMENT-CONTRACT DELIVERED. Installation, service start and live
qualification are not claimed by this source artifact. Autobuilder is not
required for this contribution and was not invoked.
