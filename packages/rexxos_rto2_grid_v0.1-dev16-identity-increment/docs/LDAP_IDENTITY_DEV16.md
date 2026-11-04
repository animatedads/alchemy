# RexxOS Grid dev16 identity authorization increment

This increment binds the read-only RexxOS Grid service to the owned ooRexx Identity Directory / LDAP line without importing LDAP protocol mechanics into Grid.

## Boundary

The authentication layer must first attribute a principal. LDAP Bind, SASL, TLS and Secret Broker handling remain in LDAP Identity. `RexxOSGridIdentityAuthorization` consumes only the neutral `IdentityDirectory` model and its `aclDecision()` authority.

For the service `rexxos.grid/0.1`, the directory resource reference is:

`rexxos://<GRID_ID>/service/rexxos.grid/0.1`

The resource type is `REXXOS_GRID`. ACL actions currently used by the wrapper are `GRID.ESTATE.READ` and `GRID.MANAGEMENT.READ`.

The authorization evidence fences the decision to the current directory revision plus principal and resource revisions. It does not confer placement, WLU, Storage, Memory, XTP routing, economic or failover authority.

## Service integration

`RexxOSGridAuthorizedServiceEndpoint` wraps the existing dev14+ explicit RpcServiceCore endpoint. Rpc context must contain `principal_id`; missing attribution fails as `UNAUTHENTICATED`, and a failed directory ACL decision returns `PERMISSION_DENIED` with the directory's bounded decision code. Raw LDAP credentials and Bind material never enter the Grid service.

ConnectSelector and RPC/serialization remain separate authorities. A DirectCall binding may provide a trusted attributed context; a remote binding must populate the same context only after its own authenticated session has succeeded.

## Qualification status

Static contract tests and strict ooRexx house-rule scanning are run in this development environment. The exact ooRexx 5.3.0 r13196 executable is not present in this container, so the included runtime `.rex` test is NOT_RUN here and no fresh runtime PASS is claimed.
