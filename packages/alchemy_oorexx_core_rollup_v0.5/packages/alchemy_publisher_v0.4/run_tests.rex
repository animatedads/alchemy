tests=.array~of("test_publication.rex","test_failed_not_published.rex"); base=directory(); p=base || "/src:" || base || "/tests"
do k over .array~of("ALCHEMY_MODEL_ROOT","ALCHEMY_TRANSPORT_ROOT","ALCHEMY_EXECUTOR_ROOT"); v=value(k,,"ENVIRONMENT"); if v<>"" then p ||= ":" || v || "/src"; end
old=value("REXX_PATH",,"ENVIRONMENT"); if old<>"" then p ||= ":" || old; call value "REXX_PATH",p,"ENVIRONMENT"
f=0; do t over tests; say "=== " || t || " ==="; address system "rexx " || base || "/tests/" || t; if rc<>0 then f+=1; end
if f then do; say "FAIL alchemy_publisher tests="f; exit 1; end; say "PASS alchemy_publisher_v0.4"; exit 0
