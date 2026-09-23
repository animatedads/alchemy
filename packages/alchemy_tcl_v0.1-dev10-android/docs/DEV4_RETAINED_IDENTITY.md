# dev4 retained identity

dev4 adopts the ooRexx global-reference technique already used by the qualified Rust Alchemy native work.

`AlchemyTclRetainRexx(object)` requests a global reference and returns an opaque `id:generation` token. The originating native call then returns.

`AlchemyTclInvokeRetained(token,arg)` is a later native call. It resolves the exact globally rooted Rexx object under the registry lock, releases the lock, and invokes the object using the later call's valid Rexx context. No `RexxCallContext *` is persisted.

`AlchemyTclReleaseRetained(token)` removes the generation-bound entry before releasing the global reference. Reuse of the token fails closed as `STALE_OR_REVOKED`; a second release fails.

## Claim boundary

This proves durable exact Rexx identity across native routine returns and generation/revocation/release behavior. It does not yet claim arbitrary Tcl-created thread attachment. Tcl invocation of a retained identity from a later Tcl evaluation will be layered on this registry through a Tcl command invoked on the owning Rexx execution thread.
