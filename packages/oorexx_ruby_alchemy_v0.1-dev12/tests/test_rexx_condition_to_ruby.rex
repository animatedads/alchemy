cb=.Callback~new
guard=.RubyAlchemyCallbackGuard~new(cb)
cbtoken=RubyAlchemyProjectRexx(guard)
outer=RubyAlchemyEval("x=Object.new; def x.rescue_cb(cb); begin; cb.explode; rescue OoRexxAlchemyCondition => e; [e.condition,e.message,e.rc,e.code].join('|'); end; end; x")
r=RubyAlchemyCallArray(outer,"rescue_cb",.array~of(cbtoken))
if pos("REXX-CALLBACK-BOOM",r)=0 then exit 92
if pos("SYNTAX",r)=0 then exit 93
if pos("98.900",r)=0 then exit 94
if RubyAlchemyReleaseRexxProjection(cbtoken) \== 1 then exit 95
call RubyAlchemyRelease outer
say "PASS dev12 ooRexx condition -> structured Ruby exception"
exit 0

::class Callback
::method explode
  raise syntax 98.900 array("REXX-CALLBACK-BOOM")

::routine RubyAlchemyEval external "LIBRARY ruby_alchemy RubyAlchemyEval"
::routine RubyAlchemyCallArray external "LIBRARY ruby_alchemy RubyAlchemyCallArray"
::routine RubyAlchemyProjectRexx external "LIBRARY ruby_alchemy RubyAlchemyProjectRexx"
::routine RubyAlchemyReleaseRexxProjection external "LIBRARY ruby_alchemy RubyAlchemyReleaseRexxProjection"
::routine RubyAlchemyRelease external "LIBRARY ruby_alchemy RubyAlchemyRelease"
::requires "RubyAlchemyCallbacks.cls"
