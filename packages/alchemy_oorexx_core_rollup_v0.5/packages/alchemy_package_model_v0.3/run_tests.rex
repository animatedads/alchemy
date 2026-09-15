tests=.array~of("test_manifest_plan.rex","test_unresolved_dependency.rex","test_schema_compat.rex")
base=directory(); old=value("REXX_PATH",,"ENVIRONMENT"); p=base || "/src:" || base || "/tests"; if old<>"" then p ||= ":" || old; call value "REXX_PATH",p,"ENVIRONMENT"
f=0; do t over tests; say "=== "t" ==="; address system "rexx " || base || "/tests/" || t; if rc<>0 then f+=1; end
if f then do; say "FAIL alchemy_package_model tests="f; exit 1; end
say "PASS alchemy_package_model_v0.3"; exit 0
