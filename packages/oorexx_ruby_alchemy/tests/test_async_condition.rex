/* dev15: structured Rexx condition survives the Ruby-worker scheduler path. */
bad=.BadTarget~new
guard=.RubyAlchemyCallbackGuard~new(bad)
proxy=RubyAlchemyProjectRexx(guard)
h=RubyAlchemyEval("x=Object.new; def x.spawn_bad(p); t=Thread.new { begin; p.explode; rescue OoRexxAlchemyCondition => e; [e.class.name,e.condition,e.code].join('|'); end }; Thread.pass until t.status == 'sleep'; t; end; x")
ht=RubyAlchemyToken(h)
a=.array~new; a[1]=proxy
thr=RubyAlchemyCallToken(ht,"spawn_bad",a)
pumped=0
do 20 while pumped=0
  pumped=RubyAlchemyPumpCallbacks(1)
end
if pumped \== 1 then exit 150
r=RubyAlchemyCallToken(thr,"value",.array~new)
if pos("OoRexxAlchemyCondition",r)=0 then exit 151
if pos("SYNTAX",r)=0 then exit 152
if pos("98.900",r)=0 then exit 153
call RubyAlchemyReleaseToken thr
call RubyAlchemyReleaseRexxProjection proxy
call RubyAlchemyRelease h
say "PASS dev17 async structured Rexx condition"
exit 0
::class BadTarget
::method explode
  raise syntax 98.900 array("DEV15-ASYNC-BOOM")
::requires "RubyAlchemyCallbacks.cls"
::routine RubyAlchemyEval external "LIBRARY ruby_alchemy RubyAlchemyEval"
::routine RubyAlchemyToken external "LIBRARY ruby_alchemy RubyAlchemyToken"
::routine RubyAlchemyCallToken external "LIBRARY ruby_alchemy RubyAlchemyCallToken"
::routine RubyAlchemyProjectRexx external "LIBRARY ruby_alchemy RubyAlchemyProjectRexx"
::routine RubyAlchemyPumpCallbacks external "LIBRARY ruby_alchemy RubyAlchemyPumpCallbacks"
::routine RubyAlchemyReleaseRexxProjection external "LIBRARY ruby_alchemy RubyAlchemyReleaseRexxProjection"
::routine RubyAlchemyReleaseToken external "LIBRARY ruby_alchemy RubyAlchemyReleaseToken"
::routine RubyAlchemyRelease external "LIBRARY ruby_alchemy RubyAlchemyRelease"
