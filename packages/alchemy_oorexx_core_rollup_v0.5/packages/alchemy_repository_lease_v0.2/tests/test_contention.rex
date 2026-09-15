s=.LeaseTestSupport; base=s~tempDir("lease-contention"); repo=base || "/repo"
s~sh("git init -q " || .AlchemyRepositoryLeaseShell~quote(repo))
ready=base || "/ready"
rexx=value("ALCHEMY_TEST_REXX",,"ENVIRONMENT"); if rexx="" then rexx="rexx"
holder=base || "/holder.out"
cmd=.AlchemyRepositoryLeaseShell~joinArgv(.array~of(rexx,directory() || "/tests/hold_lease.rex",repo,ready,"1.2","close")) || " >" || .AlchemyRepositoryLeaseShell~quote(holder) || " 2>&1 &"
address system cmd
deadline=time("E")+3
do while time("E")<deadline
  if .AlchemyRepositoryLeaseFs~isFile(ready) then leave
  call SysSleep 0.05
end
s~assertTrue(.AlchemyRepositoryLeaseFs~isFile(ready),"holder acquired")
raised=.false
signal on syntax name expectedBusy
busy=.AlchemyRepositoryLease~new(repo)~acquire(0.2)
signal off syntax
busy~close
raise syntax 88.900 array("FAIL competitor unexpectedly acquired")
expectedBusy:
  signal off syntax
  raised=.true
call SysSleep 1.2
lease=.AlchemyRepositoryLease~new(repo)~acquire(2)
s~assertTrue(lease~isActive,"competitor acquires after release")
lease~close
s~remove(base)
say "PASS test_contention"
exit 0
::requires "AlchemyRepositoryLease.cls"
::requires "LeaseTestSupport.cls"
