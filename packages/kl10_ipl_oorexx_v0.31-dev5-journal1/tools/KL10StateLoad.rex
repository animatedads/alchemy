/* Load a self-contained KL10 architectural checkpoint and inspect/step it.
 * Usage: rexx KL10StateLoad.rex file.kl10state [steps]
 */
numeric digits 30
parse arg statePath steps
if statePath = "" then do
  say "usage: rexx KL10StateLoad.rex file.kl10state [steps]"
  exit 2
end
if steps = "" then steps = 0
if \datatype(steps,"W") | steps < 0 then do
  say "steps must be a non-negative integer"
  exit 2
end

state=.KL10State~new
cpu=state~load(statePath)
say "LOADED" statePath
say " schema=" || state~schemaSha256
say " memory_sha256=" || state~memoryDigest
meta=state~metadata
do key over meta
  say " " key || "=" || meta[key]
end
say cpu~string
say cpu~pag~string
say cpu~apr~string
proposal=cpu~preview
say "next:" .LROct~fromDecimal(proposal["pc"])~right .LROct~fromDecimal(proposal["instruction"])~string proposal["mnemonic"]
if proposal["xctInstruction"] \= .nil then
  say " xct->" .LROct~fromDecimal(proposal["xctInstruction"])~string proposal["xctMnemonic"] proposal["xctDeviceName"]

do i=1 to steps
  tr=cpu~step
  say "step" i .LROct~fromDecimal(tr["pcBefore"])~right .LROct~fromDecimal(tr["instruction"])~string tr["mnemonic"] "->" .LROct~fromDecimal(tr["pcAfter"])~right
end
exit 0

::requires "../KL10IPL.cls"
