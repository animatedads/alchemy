parse source . . here
base=filespec("D",here) || filespec("P",here)
tests=.array~of("tests/test_branch_discovery.rex","tests/test_duplicate_dedupe.rex","tests/test_duplicate_conflict.rex")
failed=0; old=directory(base)
do t over tests
  address system "rexx " || .AlchemyShell~quote(t)
  if rc<>0 then failed+=1
end
call directory old
if failed then do; say "FAIL alchemy_inbox tests=" || failed; exit 1; end
say "PASS alchemy_inbox_v0.3"
exit 0
::requires "AlchemyTransport.cls"
