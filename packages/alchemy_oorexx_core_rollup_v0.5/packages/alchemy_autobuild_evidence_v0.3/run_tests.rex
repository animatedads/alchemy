parse source . . here
base=filespec("D",here) || filespec("P",here)
tests=.array~of("tests/test_error_receipt.rex","tests/test_pass_logs.rex")
failed=0
old=directory(base)
do t over tests
  address system "rexx " || .AlchemyShell~quote(t)
  if rc<>0 then failed+=1
end
call directory old
if failed then do
  say "FAIL alchemy_autobuild_evidence tests=" || failed
  exit 1
end
say "PASS alchemy_autobuild_evidence_v0.3"
exit 0
::requires "AlchemyTransport.cls"
