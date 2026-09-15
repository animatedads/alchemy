tests=.array~of("test_bundle_inventory.rex","test_dependency_floor_seed.rex","test_repository_catalog.rex","test_manifest_identity.rex","test_malformed_manifest.rex")
base=directory(); old=value("REXX_PATH",,"ENVIRONMENT")
path=base || "/src:" || base || "/tests"
transport=value("ALCHEMY_TRANSPORT_ROOT",,"ENVIRONMENT"); model=value("ALCHEMY_MODEL_ROOT",,"ENVIRONMENT")
lease=value("ALCHEMY_REPOSITORY_LEASE_ROOT",,"ENVIRONMENT")
if transport<>"" then path ||= ":" || transport || "/src"
if model<>"" then path ||= ":" || model || "/src"
if lease<>"" then path ||= ":" || lease || "/src"
if old<>"" then path ||= ":" || old
call value "REXX_PATH",path,"ENVIRONMENT"
failed=0
do t over tests
  say "=== " || t || " ==="
  address system "rexx " || base || "/tests/" || t
  if rc<>0 then failed+=1
end
if failed>0 then do; say "FAIL alchemy_dependency_floor tests=" || failed; exit 1; end
say "PASS alchemy_dependency_floor_v0.5"
exit 0
