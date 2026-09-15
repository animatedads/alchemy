tests = .array~of("test_command_and_policy.rex", "test_local_directory_transport.rex", "test_managed_zip_transport.rex", "test_git_branch_transport.rex", "test_git_main_transaction.rex", "test_git_revision_snapshot.rex")
base = directory()
path = value("REXX_PATH", , "ENVIRONMENT")
prefix = base || "/src:" || base || "/tests"
if path \= "" then prefix ||= ":" || path
call value "REXX_PATH", prefix, "ENVIRONMENT"
failed = 0
do test over tests
  say "=== "test" ==="
  address system "rexx " || base || "/tests/" || test
  if rc \= 0 then failed += 1
end
if failed > 0 then do
  say "FAIL alchemy_transport tests="failed
  exit 1
end
say "PASS alchemy_transport_v0.4"
exit 0
