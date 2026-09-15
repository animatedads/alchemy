parse arg repo ready seconds mode
lease=.AlchemyRepositoryLease~new(repo)~acquire(5)
s=.stream~new(ready); s~open("write replace"); s~charout("READY"); s~close
call SysSleep seconds
if mode="close" then lease~close
exit 0
::requires "AlchemyRepositoryLease.cls"
