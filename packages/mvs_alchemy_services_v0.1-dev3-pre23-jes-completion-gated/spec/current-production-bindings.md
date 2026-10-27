# Current production binding targets — 2026-10-24

This is the reviewed dependency inventory for MVS Alchemy Services PRE23. It is provenance and compatibility evidence, not a claim that ED209Z has live-qualified these production providers.

## Connection / RPC

- ConnectSelector `oorexx_connect_selector_v0.1-dev6.zip`, SHA-256 `6ea919552264a8d50db77b2a513990226a869ebbf3ed930e98c055c8175184ae`, API `oorexx.connect_selector/0.1`. It owns route admission/selection, no-fallback-after-uncertain-execution, optional JMS bridging, RTO2 continuity admission, and observation hooks.
- RPC portfolio `oorexx_rpc_portfolio_v0.1-dev1.zip`, SHA-256 `c07d87ebfdaf988ad9a4c2a4e52a8927da29b4e40365fbc7bd0fd544fa7a66fc`. RpcServiceCore dev1 owns allowlisted service/operation registration and dispatch. The portfolio records shared-object SOAP/JSON qualification; gRPC dev3 remains bounded by its recorded HTTP/2/streaming limitations.
- SerializationSelector v0.5 is the current reviewed encoding authority, SHA-256 `410c152e2771d55ce567cb79d76ca48e49190c39fa580767252d5d9d5a5ada37`. MAS does not select JSON/XML/protobuf/BSON codecs.
- PRE23 uses ConnectSelector dev6's `ConnectRpcDispatchAdapter` for local RpcServiceCore dispatch and no longer carries a duplicate MAS connector implementation.

## Instrumentation

- Instrumentation Mesh `oorexx_instrumentation_mesh_v0.1-dev8.zip`, SHA-256 `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`.
- PRE23's existing metric/snapshot API is compatible with dev8. Dev8 additionally supports explicit source-provided correlation, causation and context references; MAS must not infer those from timestamps, hosts or payload content.
- Logging v0.7 remains separate correlated qualification/audit evidence.

## Database / DB2 personality

- NoSQLServer current delivered development candidate: `nosqlserver_v0.91_sqlite_guarded_read_write_candidate.zip`, SHA-256 `d4a276007029e66512611ea7e836ca7ab30209b80ac7d46ecf1fba61121f02d0`.
- v0.91 is a candidate, not a fresh production certification. NoSQLServer owns SQL/DB2 semantics, transactions, mutation guards and result materialisation; MAS owns the MVS session/authority/wire boundary.

## IMAP

- The last MAS-reviewed IMAP service binding remains dev12. No newer complete IMAP delivery was established in this reconciliation. MAS therefore does not silently relabel an older GitHub source as current.

## SMTP

- SMTP Secure Stack `oorexx_smtp_secure_stack_v0.1-dev11.zip`, SHA-256 `95bf988357505e2ab59ec3264d702e9179c99be530cb55248647cf23ac3229bc`.
- Production MAILSIGN/MAILSEND continue to require host-attributed principal authority; guest VERIFIED/AUTHORIZED/EGRESS fields never grant authority. SMTP owns secure relay/routing/durable delivery and its RPC-over-SMTP carrier semantics.

## Identity

- LDAP Identity current source candidate: `oorexx_ldap_identity_v0.1-dev19.zip`, SHA-256 `14d41d9c1cd339ccd99bc1a344b182fdb86ef2b5c30ee6454dd2fbfe1525d8ec`.
- dev19 is explicitly a development candidate and is not claimed as freshly runtime-qualified. MAS may consume its authority model only through an explicit host identity binding.

## Qualification boundary

PRE23 retains bounded qualification providers for the carrier IVP. Production packages above are not silently substituted. The current dependency reconciliation does not change the live mainframe truth: PRE12 remains the last recorded ED209Z execution attempt and failed at X'75'; PRE23 is NOT_RUN live until submitted unchanged through JES.
