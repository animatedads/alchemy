# LDAP Identity activation rehearsal — dev22

This is the P0 Rasen Falcon LDAP activation increment for CX-03 / ALCH-05.
It turns the existing native directory/listener/TLS/persistence tests into one
host-oriented rehearsal and adds an explicit cross-service identity admission test.

It does **not** install a production daemon and contains no production secrets.
The owned Rasen Falcon Deployment service remains the installation authority.

`ldap_service_rehearsal.sh` requires the real package roots and fails with
`NOT_RUN` when the complete dependency/runtime closure is absent. It exercises:

1. distinct human, CHATGPT and CLAUDE principals and non-crossing ACL grants;
2. immediate admission denial after principal revocation;
3. the native LDAP wire listener and bind/search/operation authority path;
4. NoSQL directory persistence/restart and peer failover recovery;
5. native STARTTLS and LDAPS through Foreign Runtime/OpenSSL;
6. the Access Permissions adapter used by website/mail consumers.

`LDAP_SERVICE_INSTALL.json` is the dependency/secret/consumer contract for the
`rasenfalcon-ldap.service` staging lane. Authentication, signature and EMAIL_SEND
remain three distinct decisions.
