base=directory(); old=value("REXX_PATH",,"ENVIRONMENT")
path=base || "/src:" || base || "/tests"; if old<>"" then path ||= ":" || old
call value "REXX_PATH",path,"ENVIRONMENT"
failed=0
do t over .array~of("test_git_pipeline.rex","test_failure_not_published.rex","test_manifest_dependency_identity.rex")
  say "=== " || t || " ==="
  address system "rexx " || base || "/tests/" || t
  if rc<>0 then failed+=1
end
if failed>0 then do; say "FAIL alchemy_orchestrator tests=" || failed; exit 1; end
say "PASS alchemy_orchestrator_v0.5"
exit 0
