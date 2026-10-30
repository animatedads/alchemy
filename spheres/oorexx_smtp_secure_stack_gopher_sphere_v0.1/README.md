# ooRexx SMTP Secure Stack Gopher Sphere v0.1

Authoritative engineering sphere for the SMTP Secure Stack currently implemented by `oorexx_smtp_secure_stack_v0.1-dev11.zip`.

This sphere documents the boundaries that matter most for future work:

- cryptographic message authorship, SMTP authentication and `EMAIL_SEND` are independent;
- unsigned mail never becomes relayable merely because the server authenticated the connection;
- Storage Fabric and Queue Fabric provide durability, not authority;
- every outbound dispatch revalidates signature, access authority and egress policy;
- RPC-over-SMTP is an optional durable carrier below the common RPC service framework;
- Instrumentation Mesh receives a deliberately lossy operational projection and no raw private RPC correlation by default.

## Current implementation baseline

- SMTP Secure Stack: `v0.1-dev11`
- delivery SHA-256: `95bf988357505e2ab59ec3264d702e9179c99be530cb55248647cf23ac3229bc`
- ooRexx qualification runtime: 5.3.0 r13196
- runtime SHA-256: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

The implementation is published at `packages/oorexx_smtp_secure_stack/` in this repository. The sphere is documentation/evidence authority; it does not duplicate runtime implementation.


2026-10-29 source note: Git dev7.1 carries the post-DATA cleanup hotfix and LDAP PR #71 authority contract. The sphere retains dev11 as the last complete r13196 qualification baseline; autobuilder is not running, so the hotfix is not represented as a fresh full-runtime qualification.
