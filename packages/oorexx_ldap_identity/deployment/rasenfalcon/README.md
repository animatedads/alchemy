# Rasen Falcon LDAP identity deployment contribution

This closes the LDAP daemon side of RF-011/B105 without inventing a second
deployment engine. General ooRexx Deployment remains staging/install authority;
Rasen Falcon delivery remains activation/acceptance authority.

The contribution uses only existing owned LDAP Identity APIs already present in
the current GitHub package line: durable NoSQL directory recovery, Secret Broker
simple-bind authentication, directory ACL authority, the native LDAP wire
server, and OpenSSL/Foreign Runtime TLS.

Delivered:

- `bin/rasenfalcon_ldap_service.rex` — owned LDAP server bootstrap.
- `rasenfalcon-ldap.service` — non-root hardened systemd unit.
- `ldap.env.example` — deployment configuration without credentials.
- `ldap-secrets.map.example` — secretRef to environment-variable-name mapping.
- `tests/deployment/test_rasenfalcon_deployment_contract.sh` — fail-closed
  static deployment contract qualification.

The bootstrap refuses to start unless the durable directory already contains an
ACTIVE `resource:directory`. Startup does not create people, ACLs, credentials,
keys or service identities. It requires TLS certificate/private-key material and
runs the owned LDAP wire server in implicit-TLS mode. There is no `slapd`
substitution and no plaintext production fallback.

The Rasen Falcon identity role still requires real target-host evidence:
`ready:ldap_bind`, `e2e:ldap_revoke`, and the separately owned
`e2e:sign_verify_revoke`. Source delivery is not a live-service PASS.
