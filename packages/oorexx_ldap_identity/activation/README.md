# Rasen Falcon LDAP activation rehearsal

This is the pre-install qualification seam for the owned Rasen Falcon LDAP
service. It composes existing Identity Directory, native LDAP wire/TLS,
NoSQL durability and Access Permissions tests; it does not introduce a second
directory or deployment authority.

The rehearsal fails NOT_RUN when the real ooRexx/dependency closure is absent.
It exercises:
- separate human, CHATGPT and CLAUDE principal authority;
- immediate denial after principal revocation;
- native LDAP bind/search/operation authority;
- NoSQL restart/failover recovery;
- STARTTLS and LDAPS using the owned TLS provider;
- the Access Permissions adapter used by website/mail consumers.

Production installation and private certificate issuance remain operator-gated.
