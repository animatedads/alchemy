numeric digits 30
parse arg inputState outA outB
if outA="" then outA="/tmp/kl10-freeze-a.state"
if outB="" then outB="/tmp/kl10-freeze-b.state"

state=.KL10State~new
call time "R"
cpu=state~load(inputState)
loadSeconds=time("E")

meta=.directory~new
meta["checkpoint"]="benchmark-fast-freeze"
call time "R"
f=state~freeze(cpu,meta)
freezeSeconds=time("E")

call time "R"
f~save(outA)
save1Seconds=time("E")

call time "R"
f~save(outB)
save2Seconds=time("E")

say "LOAD_SECONDS" loadSeconds
say "FREEZE_SECONDS" freezeSeconds
say "SAVE1_SECONDS" save1Seconds
say "SAVE2_SECONDS" save2Seconds
say "FROZEN_BYTES" f~byteCount
say "FROZEN_RECORDS" f~recordCount
say "MEMORY_SHA256" f~memoryDigest
say "A_BYTES" streamBytes(outA)
say "B_BYTES" streamBytes(outB)
exit

streamBytes: procedure
 use arg path
 s=.stream~new(path)~~open("READ")
 n=s~chars
 s~close
 return n

::requires "../KL10IPL.cls"
