parse source . . here
root=filespec("L",here) || filespec("D",here) || filespec("P",here); old=directory(root)
do f over .array~of("tests/test_submission_sender.rex","tests/test_dry_run.rex")
  say "=== " || f || " ==="
  address system "rexx " || .AlchemyShell~quote(f)
  if rc<>0 then exit rc
end
call directory old
say "PASS alchemy_submission_v0.4"; exit 0
::requires "AlchemyTransport.cls"
