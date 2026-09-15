numeric digits 30
parse arg statePath count
if count="" then count=40
cpu=.KL10State~new~load(statePath)
do i=1 to count
  w=cpu~fetch; d=cpu~decode(w)
  if i<=40 then say i "PC="||.LROct~fromDecimal(cpu~pc)~right .LROct~fromDecimal(w)~string d["mnemonic"] cpu~apr
  signal on syntax name refused
  ignored=cpu~step
  signal off syntax
end
say "END" cpu
say cpu~apr
exit
refused:
 say "REFUSED" condition("A")
 say cpu
 say cpu~apr
exit 1
::requires "../KL10IPL.cls"
