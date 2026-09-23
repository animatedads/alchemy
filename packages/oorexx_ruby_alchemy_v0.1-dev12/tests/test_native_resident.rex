ruby=RubyAlchemyEval("x=Object.new; def x.boom; raise ArgumentError, 'ruby-bang'; end; def x.internal_missing; self.definitely_absent; end; def x.method_missing(n,*a); return 77 if n==:dynamic; super; end; x")
tok=RubyAlchemyToken(ruby)

/* Existing dynamic method_missing remains a normal value, not an exception. */
ok=RubyAlchemyTryCallToken(tok,"dynamic",.array~new)
if ok["kind"] \== "value" then exit 71
if ok["value"] \== 77 then exit 72

/* A method that really raises is preserved as a Ruby exception identity. */
bad=RubyAlchemyTryCallToken(tok,"boom",.array~new)
if bad["kind"] \== "raised" then exit 73
if bad["class"] \== "ArgumentError" then exit 74
if bad["message"] \== "ruby-bang" then exit 75
fid=bad["failureId"]
if fid<=0 then exit 76
bt=RubyAlchemyFailureBacktrace(fid)
/* Backtrace can be short but must remain queryable while failure is retained. */
if RubyAlchemyReleaseFailure(fid) \== 1 then exit 77

/* A genuinely unresolved send is also a Ruby NoMethodError, distinguishable
   by its actual class rather than guessed from respond_to?. */
miss=RubyAlchemyTryCallToken(tok,"definitely_absent",.array~new)
if miss["kind"] \== "missing" then exit 78
if miss["class"] \== "NoMethodError" then exit 79
call RubyAlchemyReleaseFailure miss["failureId"]

/* A resolved method that internally triggers the same NoMethodError class is
   a real Ruby failure, never UNKNOWN fallback. */
inside=RubyAlchemyTryCallToken(tok,"internal_missing",.array~new)
if inside["kind"] \== "raised" then exit 80
if inside["class"] \== "NoMethodError" then exit 81
call RubyAlchemyReleaseFailure inside["failureId"]

call RubyAlchemyRelease ruby
say "PASS dev12 exact NoMethodError provenance and structured Ruby failure identity"
exit 0

::routine RubyAlchemyEval external "LIBRARY ruby_alchemy RubyAlchemyEval"
::routine RubyAlchemyToken external "LIBRARY ruby_alchemy RubyAlchemyToken"
::routine RubyAlchemyTryCallToken external "LIBRARY ruby_alchemy RubyAlchemyTryCallToken"
::routine RubyAlchemyFailureBacktrace external "LIBRARY ruby_alchemy RubyAlchemyFailureBacktrace"
::routine RubyAlchemyReleaseFailure external "LIBRARY ruby_alchemy RubyAlchemyReleaseFailure"
::routine RubyAlchemyRelease external "LIBRARY ruby_alchemy RubyAlchemyRelease"
