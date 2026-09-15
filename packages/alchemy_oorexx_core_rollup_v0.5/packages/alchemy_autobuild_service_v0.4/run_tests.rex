parse source . . here
base=filespec("D",here) || filespec("P",here)
tests=.array~of("tests/test_service_pass_idempotent.rex","tests/test_service_fail.rex","tests/test_service_error.rex","tests/test_service_unit.rex")
failed=0; old=directory(base)
do t over tests
  address system "rexx " || .AlchemyShell~quote(t)
  if rc<>0 then failed+=1
end
call directory old
if failed>0 then do; say "FAIL alchemy_autobuild_service tests=" || failed; exit 1; end
say "PASS alchemy_autobuild_service_v0.4"
exit 0
::requires "AlchemyTransport.cls"
