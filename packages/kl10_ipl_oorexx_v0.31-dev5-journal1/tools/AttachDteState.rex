/* Explicit architectural migration: attach reset-state KL10 DTE20 to a
 * checkpoint whose next proposal requests device 0200.
 *
 * Usage: rexx AttachDteState.rex input.kl10state output.kl10state
 */
parse arg inputState outputState
if inputState="" | outputState="" then do
  say "usage: rexx AttachDteState.rex input.kl10state output.kl10state"
  exit 2
end

reader=.KL10State~new
cpu=reader~load(inputState)
p=cpu~preview
if p["xctDeviceName"] \= "DTE" & p["deviceName"] \= "DTE" then do
  say "refusing DTE attachment: checkpoint does not currently propose DTE I/O"
  exit 1
end
if cpu~ioBus~hasDevice(oct("0200")) then do
  say "refusing DTE attachment: DTE already present"
  exit 1
end

dte=cpu~attachDte
if dte~coni(cpu~ioBus) \= 0 then do
  say "refusing DTE attachment: reset-visible status is not zero"
  exit 1
end

meta=.directory~new
oldMeta=reader~metadata
do key over oldMeta
  meta[key]=oldMeta[key]
end
meta["parent_state_sha256"]=sha256File(inputState)
meta["transition"]="attach-DTE-0200-reset"
meta["checkpoint"]="mtboot.pre-dte-probe.attached"

writer=.KL10State~new
ignored=writer~save(cpu,outputState,meta)

/* Byte-level reload is part of the migration contract. */
verifyState=.KL10State~new
verify=verifyState~load(outputState)
if \verify~ioBus~hasDevice(oct("0200")) then do
  say "DTE missing after reload"
  exit 1
end
if verify~dte~coni(verify~ioBus) \= 0 then do
  say "DTE visible reset state changed after reload"
  exit 1
end
vp=verify~preview
if vp["xctDeviceName"] \= "DTE" then do
  say "next DTE proposal changed after reload"
  exit 1
end

say "MIGRATED" outputState
say " schema=" || verifyState~schemaSha256
say " transition=attach-DTE-0200-reset"
say " DTE-visible=" || .LROct~fromDecimal(verify~dte~coni(verify~ioBus))~right
say " DTE-internal=" || .LROct~fromDecimal(verify~dte~statusInternal)~right
say " next=" || .LROct~fromDecimal(vp["instruction"])~string vp["mnemonic"]
say " xct=" || .LROct~fromDecimal(vp["xctInstruction"])~string vp["xctMnemonic"] vp["xctDeviceName"]
exit 0

sha256File: procedure
  use arg path
  out=path||".parent.sha256.tmp"
  address system 'sha256sum "' || path || '" > "' || out || '"'
  if rc \= 0 then do; say "sha256sum failed"; exit 1; end
  s=.stream~new(out)~~open("READ")
  line=s~linein
  s~close
  call sysFileDelete out
  parse var line digest .
  return digest

oct: procedure
  use arg t
  n=0
  do i=1 to length(t); n=n*8+substr(t,i,1); end
  return n

::requires "../KL10IPL.cls"
