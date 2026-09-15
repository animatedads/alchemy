parse arg bridge
if bridge = "" then bridge = "../native/openssl_direct.bridge.json"
installed = .CryptoForeignRuntimeInstaller~install(bridge)

payload = copies("A", 1048576)
expected256 = "4e29ad18ab9f42d7c233500771a39d7c852b200baf328fd00fbbe3fecea1eb56"
expected512 = "1339d6533a0b875db3f1f607290f8de0e8f79172390faa03fe1ae15cb738b9c64828b08ed11721acc2909cc9394cc9cc115c9d7c9895cefa76f5146614961277"
threads = 4
loops = 20

/* Warm the provider/library before either timing. */
call verifyPair payload, expected256, expected512

ignore = time("R")
do i = 1 to threads * loops
  call verifyPair payload, expected256, expected512
end
sequential = time("E")

workers = .Array~new
messages = .Array~new
ignore = time("R")
do i = 1 to threads
  worker = .ShaBenchWorker~new(payload, expected256, expected512, loops)
  workers~append(worker)
  messages~append(worker~start("run"))
end
do m over messages
  if m~result \= 1 then do
    say "FAIL parallel SHA worker"
    exit 1
  end
end
parallel = time("E")

mib = threads * loops * 2
say "SHA thread benchmark" threads "activities," loops "pairs/activity," mib "MiB total"
say "Sequential seconds:" format(sequential,,3)
say "Parallel seconds:  " format(parallel,,3)
if parallel > 0 then say "Wall speedup:      " format(sequential / parallel,,2) || "x"
say "Parallel throughput:" format(mib / parallel,,1) "MiB/s"
say "PASS thread-safe SHA concurrency benchmark"

installed["target"]~close
.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch = .nil
exit 0

verifyPair: procedure
  use arg payload, expected256, expected512
  if .SHA256~new(payload)~digest \= expected256 then signal bad
  if .SHA512~new(payload)~digest \= expected512 then signal bad
  return
bad:
  say "FAIL SHA benchmark digest mismatch"
  exit 1

::class ShaBenchWorker
::method init
  expose payload expected256 expected512 loops
  use strict arg payload, expected256, expected512, loops
::method run
  expose payload expected256 expected512 loops
  do i = 1 to loops
    if .SHA256~new(payload)~digest \= expected256 then return 0
    if .SHA512~new(payload)~digest \= expected512 then return 0
  end
  return 1

::requires "CryptoForeignRuntimeProvider.cls"
