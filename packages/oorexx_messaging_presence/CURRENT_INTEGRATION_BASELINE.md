# Messaging & Presence current integration baseline — 2026-10-24

This document records current external integration authorities without changing the released Messaging & Presence v0.1-dev4 semantic API.

## Current authorities

- Socket Provider v0.1-dev16
  - SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`
- Instrumentation Mesh v0.1-dev8
  - SHA-256 `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- BOSH released baseline v0.1-dev5
  - SHA-256 `072555ee2fd1ac8d02ede22d280015d0904b2db805a05d49a51c5e2c0eeebd67`
  - GitHub source reconciliation continues as dev6.
- XMPP/BOSH adapter v0.1-dev2
  - SHA-256 `5101f283dab036c18574ae90d03480ecc634c90d4e478f1458fac0481943525b`
- Network Transport Intentions v0.1-dev3
  - SHA-256 `d90dc49e4799f929761e75b302ab141a3bab481efdf951cdd508491a9b18c64b`
- XTP v0.1-dev25 is current development context for lower transport composition; Messaging & Presence does not depend on XTP.

## Source-publication caveat

The Library and current consumers identify Socket Provider dev16 as the shared authority, but the first-class GitHub source tree at `packages/oorexx_socket_provider/` still identifies itself as dev14. Messaging & Presence therefore treats dev16 as an external qualification authority and does not infer dev16 implementation details from the stale source tree.

The same rule applies to Instrumentation Mesh dev8: use exact dev8 source when performing fresh qualification; do not reconstruct it from older vendored copies.

## XMPP STARTTLS

The current evidence does not establish a generic same-stream STARTTLS upgrade method in the shared SocketProvider API. XMPP therefore remains fail-closed before SASL on an unprotected connection. Protocol-specific SMTP/LDAP secure-upgrade implementations do not transfer authority into SocketProvider.

## BOSH

BOSH remains a lower HTTP-carried logical stream. XEP-0206 remains a separate adapter. Applications and intentions do not request BOSH by name.

A concrete generic HTTP/HTTPS exchange-provider qualification, including a real HTTPS-over-XTP composition, remains open. No first-class generic HTTP client API was identified in the current repository review, so no local substitute is introduced here.
