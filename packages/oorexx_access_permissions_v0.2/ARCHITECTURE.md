# Access Permissions v0.2 architecture

## Authority layers

### Authentication attribution

`AuthenticationAssertion` proves provenance and integrity for exact bytes bound to a sealed `AccessPrincipal`. It does not grant Access Control and it does not grant method Permission.

The authority using the assertion must also bind the attributed principal to the request subject. v0.2 enforces this explicitly in both `AccessControlAuthority` and `PermissionAuthority`.

### Access Control — enter the building

`AccessControlAuthority` evaluates a sealed `AccessControlRequest` against a sealed `AccessControlPolicy`.

The request binds:

- request id;
- principal id;
- domain id;
- entry point;
- intended time;
- snapshotted contextual attributes.

Rules match subject/domain/entry plus zero or more `requireAttribute` predicates. Highest numeric priority wins. At equal priority DENY wins; same-action ties use lexical rule id. Default action is DENY.

### Permissions — use this exact method on this exact object

`PermissionAuthority` evaluates an exact `PermissionRequest` over:

- principal id;
- exact object id;
- object class;
- method;
- Security Effect disposition;
- exact Security Effect policy identity;
- Security Effect trace identity;
- retained Security Effect constraints.

The request cannot be sealed without a valid Security Effect assessment bound to the same principal, object id and method.

### Security Manager — enforcement

`AlchemyPermissionPolicyAdapter` implements the existing `AlchemySecurityManager` policy contract for METHOD checkpoints. The adapter resolves Security Effect, constructs a Permission request, obtains a Permission decision, retains the cryptographic decision envelope, and returns an `AlchemySecurityDecision`. Security Manager remains the component that blocks execution.

## Executable composition

v0.2 adds:

`attributed principal -> AlchemyAccessControlledDomain -> Access Control -> admitted session -> Alchemy Security Manager -> Permission -> protected method`

`AlchemyAccessControlledDomain~enter(request, principal, assertion)` fails closed unless:

1. request and principal are sealed;
2. request principal equals attributed principal;
3. request domain equals the domain object;
4. the exact authentication assertion verifies;
5. Access Control returns ALLOW;
6. by default, the Access Control ALLOW contains a cryptographic proof.

A successful entry creates `AlchemyAccessControlledSession`. The session retains the Access Control decision envelope and owns a Security Manager wired to a Permission adapter. The session does **not** convert the Access Control receipt into method authority.

The canonical regression sequence is:

1. Bob authenticates and is allowed to enter TREASURY.
2. TREASURY's Permission policy grants no methods.
3. Bob calls a protected method.
4. Security Manager receives METHOD.
5. Permission returns DENY.
6. Method body does not execute.
7. A second session with an exact object/method Permission ALLOW executes the same method.

This proves the two authority layers are operationally distinct, not merely documented as distinct.

## Cryptographic evidence

`AccessPermissionsSigner` produces trusted-key-ring MAC proofs for Access Control and Permission decisions. `AuthorizationDecisionEnvelope~verifyProof` verifies that the proof kind and artifact identity match the retained decision before checking the MAC.

The protected-domain composition requires Access Control proof presence by default. A caller can deliberately disable that requirement only through the explicit constructor argument; the default is fail closed.

Proof is evidence, not a bearer capability. Current enforcement still requires the domain gate or Security Manager path.

## Immutability

Policies and rules cannot be modified after `seal`.

v0.2 additionally snapshots `AccessControlRequest` attribute values to strings at insertion time. A mutable caller-owned object cannot later change request matching or canonical identity after the request is sealed.

Returned Access Control rule requirement maps are defensive copies.

## Exact object identity

The Alchemy adapter uses `alchemyObjectId` when available, otherwise `identityHash`. A class-wide Permission exists only if policy deliberately uses a wildcard object selector. Tests authorize one object and prove a second instance of the same class is denied.

## Runtime enforcement caveat

Security Manager can enforce only checkpoints actually emitted by the interpreter. A method intended to be governed here must remain `PROTECTED`, or carry its own independent local gate. Public method exposure is an enforcement-boundary decision, not a Permission rule.

## Session scope

`AlchemyAccessControlledSession` is an in-process composition object and audit identity. v0.2 does not define durable session serialization, delegation, renewal, cross-process bearer tokens, or long-lived replay semantics. Re-entry is performed through a new Access Control request/assertion and a new session.
