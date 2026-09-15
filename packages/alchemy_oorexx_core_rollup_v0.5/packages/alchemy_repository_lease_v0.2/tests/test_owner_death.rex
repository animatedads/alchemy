s=.LeaseTestSupport; base=s~tempDir("lease-owner-death"); repo=base || "/repo"
s~sh("git init -q " || .AlchemyRepositoryLeaseShell~quote(repo))
ready=base || "/ready"
rexx=value("ALCHEMY_TEST_REXX",,"ENVIRONMENT"); if rexx="" then rexx="rexx"
cmd=.AlchemyRepositoryLeaseShell~joinArgv(.array~of(rexx,directory() || "/tests/hold_lease.rex",repo,ready,"0.2","abandon")) || " >/dev/null 2>&1 &"
address system cmd
deadline=time("E")+3
do while time("E")<deadline
  if .AlchemyRepositoryLeaseFs~isFile(ready) then leave
  call SysSleep 0.05
end
s~assertTrue(.AlchemyRepositoryLeaseFs~isFile(ready),"abandoning owner acquired")
/* Owner exits without close. Helper must observe death and release flock. */
call SysSleep 0.5
lease=.AlchemyRepositoryLease~new(repo)~acquire(3)
s~assertTrue(lease~isActive,"owner death releases kernel lease")
lease~close
s~remove(base)
say "PASS test_owner_death"
exit 0
::requires "AlchemyRepositoryLease.cls"
::requires "LeaseTestSupport.cls"
