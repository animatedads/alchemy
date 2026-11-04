# Odoo CRM Provider dev12 — LDAP actor delta

Exact packaged artifact created 2026-10-29:

- archive: `oorexx_odoo_crm_provider_v0.1-dev12.zip`
- SHA-256: `451d9e5a5f4d4bd361d5c91488d08e34838623b4d724f7fe30b7e0f2fe017e3a`
- base: exact dev11 archive SHA-256 `d27ecf896b551e1923e52be20d990423c6f79cc7093e61ab96e6c5a50d714479`

This directory carries the dev12 source delta needed for review and remote qualification while the generic unpacked package tree is still behind.

Source hashes:
- `OdooRelationshipCRMLdapActor.cls`: `a3af1c115b4fc6574136ad5a1ee032ce609aff7e3338753b0131cfc54c5c2f4f`
- `OdooRelationshipCRMServiceAdapter.cls`: `8c01f82b19085d19b8bb4453918f8effecaa41338840d3f0f9557b1d3484cdbb`
- `test_ldap_actor_adapter.rex`: `82bf543e8889e0eb41bb79f4b09c9d6b0523de191cb7fcb56074de81a9dd056d`

Semantics:
- authenticated LDAP session supplies principal attribution;
- ACTIVE LDAP principal is required;
- CRM actor role comes only from explicit principal/group binding;
- LDAP `principalType` is not treated as authorization;
- unauthenticated, inactive, missing or unbound principals fail closed;
- Odoo provider never handles LDAP credentials.

The exact archive manifest and ZIP integrity passed locally. A fresh ooRexx r13196 runtime qualification is still required.
