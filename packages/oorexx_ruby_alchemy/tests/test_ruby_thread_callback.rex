/* dev13: a Ruby-created Thread invokes the retained Rexx object. */
o=.Counter~new
proxy=RubyAlchemyProjectRexx(o)

h=RubyAlchemyEval("x=Object.new; def x.spawn(p); t=Thread.new { p.next }; Thread.pass until t.status == 'sleep'; t; end; x")
ht=RubyAlchemyToken(h)
a=.array~new; a[1]=proxy
thr=RubyAlchemyCallToken(ht,"spawn",a)
/* dev15: the Rexx owner explicitly services callbacks queued by Ruby workers. */
pumped=0
do 10 while pumped=0
  pumped=RubyAlchemyPumpCallbacks(1)
end
if pumped \== 1 then exit 120
/* The worker has completed before Thread#value, so value cannot deadlock. */
r=RubyAlchemyCallToken(thr,"value",.array~new)
if r \== 1 then exit 121
r2=RubyAlchemyCallToken(thr,"value",.array~new)
if r2 \== 1 then exit 122

state=RubyAlchemyRexxProjectionState(proxy)
if state["LIVE"] \== .true then exit 123
if state["ACTIVE_CALLS"] \== 0 then exit 124
if state["RETAINS"] \== 1 then exit 125

call RubyAlchemyReleaseToken thr
if RubyAlchemyReleaseRexxProjection(proxy) \== 1 then exit 126

/* Release may revoke future calls while an already-pinned worker callback is
 * queued.  The queued invocation completes, then the pump performs deferred
 * destruction exactly once on the final unpin. */
o2=.Counter~new
p2=RubyAlchemyProjectRexx(o2)
a2=.array~new; a2[1]=p2
thr2=RubyAlchemyCallToken(ht,"spawn",a2)
if RubyAlchemyReleaseRexxProjection(p2) \== 1 then exit 127
if RubyAlchemyPumpCallbacks(1) \== 1 then exit 128
r3=RubyAlchemyCallToken(thr2,"value",.array~new)
if r3 \== 1 then exit 129
call RubyAlchemyReleaseToken thr2
call RubyAlchemyRelease h

say "PASS dev17 Ruby-created thread -> retained Rexx callback + release race"
exit 0

::class Counter
::method init
  expose n; n=0
::method next
  expose n; n=n+1; return n

::routine RubyAlchemyEval external "LIBRARY ruby_alchemy RubyAlchemyEval"
::routine RubyAlchemyToken external "LIBRARY ruby_alchemy RubyAlchemyToken"
::routine RubyAlchemyCallToken external "LIBRARY ruby_alchemy RubyAlchemyCallToken"
::routine RubyAlchemyProjectRexx external "LIBRARY ruby_alchemy RubyAlchemyProjectRexx"
::routine RubyAlchemyPumpCallbacks external "LIBRARY ruby_alchemy RubyAlchemyPumpCallbacks"
::routine RubyAlchemyRexxProjectionState external "LIBRARY ruby_alchemy RubyAlchemyRexxProjectionState"
::routine RubyAlchemyReleaseRexxProjection external "LIBRARY ruby_alchemy RubyAlchemyReleaseRexxProjection"
::routine RubyAlchemyReleaseToken external "LIBRARY ruby_alchemy RubyAlchemyReleaseToken"
