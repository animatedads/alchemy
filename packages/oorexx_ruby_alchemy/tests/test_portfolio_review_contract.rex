/* dev16 - 2026-09-27 portfolio-review alignment.
 *
 * Exercises review-standard boundary cases without inventing semantics that
 * the checkpoint did not establish: empty queue, malformed identity, repeated
 * release, passive state inspection, and explicit revocation.
 */
if RubyAlchemyPumpCallbacks(1) \== 0 then exit 171

bad='@RUBY:not-a-handle'
if RubyAlchemyReleaseToken(bad) \== 0 then exit 172
if RubyAlchemyReleaseRexxProjection(bad) \== 0 then exit 173

o=.ReviewCounter~new
p=RubyAlchemyProjectRexx(o)
state=RubyAlchemyRexxProjectionState(p)
if state["LIVE"] \== .true then exit 174
if state["RETAINS"] \== 1 then exit 175
if state["ACTIVE_CALLS"] \== 0 then exit 176
if state["REVOKED"] \== .false then exit 177

if RubyAlchemyRevokeRexxProjection(p) \== 1 then exit 178
state2=RubyAlchemyRexxProjectionState(p)
if state2["LIVE"] \== .true then exit 179
if state2["REVOKED"] \== .true then exit 180

if RubyAlchemyReleaseRexxProjection(p) \== 1 then exit 181
if RubyAlchemyReleaseRexxProjection(p) \== 0 then exit 182

say "PASS dev17 portfolio review boundary contract"
exit 0

::class ReviewCounter
::method value
  return 1

::routine RubyAlchemyPumpCallbacks external "LIBRARY ruby_alchemy RubyAlchemyPumpCallbacks"
::routine RubyAlchemyReleaseToken external "LIBRARY ruby_alchemy RubyAlchemyReleaseToken"
::routine RubyAlchemyProjectRexx external "LIBRARY ruby_alchemy RubyAlchemyProjectRexx"
::routine RubyAlchemyReleaseRexxProjection external "LIBRARY ruby_alchemy RubyAlchemyReleaseRexxProjection"
::routine RubyAlchemyRevokeRexxProjection external "LIBRARY ruby_alchemy RubyAlchemyRevokeRexxProjection"
::routine RubyAlchemyRexxProjectionState external "LIBRARY ruby_alchemy RubyAlchemyRexxProjectionState"
