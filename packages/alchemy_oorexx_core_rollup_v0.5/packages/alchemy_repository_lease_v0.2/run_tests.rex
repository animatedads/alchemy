base=directory(); old=value("REXX_PATH",,"ENVIRONMENT")
repo=base || "/../.."
path=base || "/src:" || base || "/tests:" ||,
     repo || "/packages/alchemy_core_component_v0.1/src:" ||,
     repo || "/packages/alchemy_objects_v0.4.3/src:" ||,
     repo || "/packages/oorexx_crypto_v0.1/src"
if old<>"" then path ||= ":" || old
call value "REXX_PATH",path,"ENVIRONMENT"
failed=0
do t over .array~of("test_alchemy_object_surface.rex","test_contention.rex","test_owner_death.rex")
  say "=== " || t || " ==="
  address system "rexx " || base || "/tests/" || t
  if rc<>0 then failed+=1
end
if failed>0 then do; say "FAIL alchemy_repository_lease tests=" || failed; exit 1; end
say "PASS alchemy_repository_lease_v0.2"
exit 0
