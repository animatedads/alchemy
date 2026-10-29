# Rasen Falcon LDAP identity deployment contribution — dev23

This directory supplies the owned production LDAP daemon boundary without
inventing a second deployment engine. General ooRexx Deployment remains staging
and install authority; Rasen Falcon delivery remains activation/acceptance authority.

Delivered:
- `bin/rasenfalcon_ldap_service.rex`: persistent Identity Directory + NoSQLServer
  + Secret Broker + mandatory LDAPS bootstrap.
- `rasenfalcon-ldap.service`: non-root hardened systemd unit.
- `ldap.env.example`: configuration shape with no credentials.
- `ldap-secrets.map.example`: secret-reference to environment-variable mapping;
  raw secret values are forbidden.
- `activation/ldap_service_rehearsal.sh`: pre-install runtime rehearsal covering
  native listener, persistence/restart, STARTTLS/LDAPS, Access Permissions and
  principal revocation/admission.

The bootstrap fails closed unless durable state already contains ACTIVE
`resource:directory`; startup never provisions people, ACLs, credentials or
service accounts. Production is LDAPS-only; no slapd or plaintext fallback.

SOURCE/DEPLOYMENT-CONTRACT DELIVERED. Production install, service start, private
certificate issuance and live bind/revoke acceptance remain NOT_RUN / operator-gated.
