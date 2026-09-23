/* dev4 cross-native-call retained Rexx identity + generation/revoke */
cb = .Callback~new

/* Native call #1 roots the exact Rexx object and returns. */
token = AlchemyTclRetainRexx(cb)
if token = "RETAIN_FAILED" then call fail "retain", token
say "token="token

/* Native call #2 is a later call.  It uses a fresh Rexx context to invoke
 * the globally-rooted exact object.
 */
r = AlchemyTclInvokeRetained(token, "21")
if r \== "42" then call fail "later invocation", r

/* Native call #3 releases bridge ownership. */
released = AlchemyTclReleaseRetained(token)
if \released then call fail "release", released

/* Generation/revocation fence: old token can no longer resolve. */
r = AlchemyTclInvokeRetained(token, "22")
if r \== "STALE_OR_REVOKED" then call fail "stale fence", r

/* Exactly once release. */
released = AlchemyTclReleaseRetained(token)
if released then call fail "double release accepted", released

say "PASS retained exact Rexx identity across native calls; generation fence; revoke/release"
exit 0

fail:
  use arg what, got
  say "FAIL" what "got="got
  exit 1

::class Callback
::method call
  use strict arg value
  return value * 2

::requires "alchemy_tcl" LIBRARY
