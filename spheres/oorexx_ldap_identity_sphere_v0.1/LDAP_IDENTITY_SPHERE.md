# ooRexx LDAP Identity Gopher sphere v0.1

Durable semantic context for the ooRexx LDAP / Identity Directory line.

This sphere records the architectural authority boundaries, current dev19 recovery work,
qualification status and continuation seams. It does not duplicate the complete LDAP source tree.

Profile:

    ./gopher --profile ldap-identity context ldap-identity
    ./gopher --profile ldap-identity open ldap-identity.current
    ./gopher --profile ldap-identity search 'same epoch holder' --sphere ldap-identity
    ./gopher --profile ldap-identity search 'XTP transport ACK' --sphere ldap-identity

Current source candidate:

    oorexx_ldap_identity_v0.1-dev19.zip
    SHA-256 14d41d9c1cd339ccd99bc1a344b182fdb86ef2b5c30ee6454dd2fbfe1525d8ec

Important qualification truth: dev19 is not presently claimed as a fresh runtime-qualified release.
The available build container had no ooRexx executable. A direct standards-enforcer run on the
archive reported 1 ERROR and 136 WARNINGS; the error is in the new authority-recovery regression
handler, not evidence that the semantic recovery design is accepted. See qualification evidence.
