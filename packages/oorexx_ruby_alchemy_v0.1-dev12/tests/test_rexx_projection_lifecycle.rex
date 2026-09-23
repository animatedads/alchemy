/* dev12: repeated reverse projection interns identity and retain counts. */
o=.Counter~new
p1=RubyAlchemyProjectRexx(o)
p2=RubyAlchemyProjectRexx(o)
if p1 \== p2 then exit 101

/* Two projections mean two retains. One release must not revoke the proxy. */
if RubyAlchemyReleaseRexxProjection(p1) \== 1 then exit 102
r=RubyAlchemyTryCallToken(p2,"next",.array~new)
if r["kind"] \== "value" then exit 103
if r["value"] \== 1 then exit 104

/* Explicit revocation rejects future invocation deterministically. */
if RubyAlchemyRevokeRexxProjection(p2) \== 1 then exit 105
bad=RubyAlchemyTryCallToken(p2,"next",.array~new)
if bad["kind"] \== "raised" then exit 106
if bad["class"] \== "RuntimeError" then exit 107
if pos("revoked ooRexx projection",bad["message"]) == 0 then exit 108
call RubyAlchemyReleaseFailure bad["failureId"]

/* Final release is accepted once and stale token release is idempotently false. */
if RubyAlchemyReleaseRexxProjection(p2) \== 1 then exit 109
if RubyAlchemyReleaseRexxProjection(p2) \== 0 then exit 110
say "PASS dev12 reverse projection identity retain/revoke lifecycle"
exit 0

::class Counter
::method init
  expose n; n=0
::method next
  expose n; n=n+1; return n

::routine RubyAlchemyProjectRexx external "LIBRARY ruby_alchemy RubyAlchemyProjectRexx"
::routine RubyAlchemyReleaseRexxProjection external "LIBRARY ruby_alchemy RubyAlchemyReleaseRexxProjection"
::routine RubyAlchemyRevokeRexxProjection external "LIBRARY ruby_alchemy RubyAlchemyRevokeRexxProjection"
::routine RubyAlchemyTryCallToken external "LIBRARY ruby_alchemy RubyAlchemyTryCallToken"
::routine RubyAlchemyReleaseFailure external "LIBRARY ruby_alchemy RubyAlchemyReleaseFailure"
