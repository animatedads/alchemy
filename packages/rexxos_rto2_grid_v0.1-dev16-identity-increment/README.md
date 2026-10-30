# RexxOS RTO2 Grid v0.1-dev16 identity increment

Source increment over `rexxos_rto2_grid_v0.1-dev15` adding a fail-closed authorization seam from the read-only Grid estate service to the owned ooRexx Identity Directory / LDAP line.

It does not implement LDAP Bind, TLS, credentials, transport choice or serialization. It consumes an already attributed principal and asks `IdentityDirectory~aclDecision()` for the exact Grid service action. Authentication remains distinct from authorization, and directory authorization remains distinct from Grid/placement authority.

This is intentionally a small source increment rather than another bundled runtime closure. Vendored dependencies, compiled binaries, initramfs images, keys and certificates are excluded.

See `docs/LDAP_IDENTITY_DEV16.md`.
