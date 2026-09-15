numeric digits 30
parse arg inputState outputState
cpu=.KL10State~new~load(inputState)
/* Legacy checkpoint predates frozen PI; attach the now-proved device. */
if \cpu~ioBus~hasDevice(4) then ignored=cpu~ioBus~attach(.KL10Pi~new)

do i=1 to 9
  w=cpu~fetch
  d=cpu~decode(w)
  say i "PC="||.LROct~fromDecimal(cpu~pc)~right .LROct~fromDecimal(w)~string d["mnemonic"]
  ignored=cpu~step
end

m=.directory~new
m["checkpoint"]="g143.post-apr-rebuild"
.KL10State~new~save(cpu,outputState,m)
say "END" cpu
say cpu~pi
say cpu~apr
say cpu~pag
say "FROZEN" outputState
::requires "../KL10IPL.cls"
