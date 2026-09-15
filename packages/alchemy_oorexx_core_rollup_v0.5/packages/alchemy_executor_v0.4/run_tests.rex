tests=.array~of("test_exact_environment_execution.rex","test_failure_capture.rex","test_timeout_capture.rex")
base=directory(); old=value("REXX_PATH",,"ENVIRONMENT"); p=base || "/src:" || base || "/tests"
m=value("ALCHEMY_MODEL_ROOT",,"ENVIRONMENT"); t=value("ALCHEMY_TRANSPORT_ROOT",,"ENVIRONMENT"); if m<>"" then p ||= ":" || m || "/src"; if t<>"" then p ||= ":" || t || "/src"; if old<>"" then p ||= ":" || old; call value "REXX_PATH",p,"ENVIRONMENT"
f=0; do x over tests; say "=== " || x || " ==="; address system "rexx " || base || "/tests/" || x; if rc<>0 then f+=1; end
if f then do; say "FAIL alchemy_executor tests="f; exit 1; end
say "PASS alchemy_executor_v0.4"; exit 0
