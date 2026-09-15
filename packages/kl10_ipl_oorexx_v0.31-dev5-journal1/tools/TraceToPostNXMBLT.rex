numeric digits 30
parse arg statePath
cpu=.KL10State~new~load(statePath)
do i=1 to 3
  w=cpu~fetch; d=cpu~decode(w)
  say i "BEFORE PC="||.LROct~fromDecimal(cpu~pc)~right d["mnemonic"] -
      "AC1="||.LROct~fromDecimal(cpu~accumulator(1))~string -
      "AC2="||.LROct~fromDecimal(cpu~accumulator(2))~string
  ignored=cpu~step
end
say "AT BLT PC="||.LROct~fromDecimal(cpu~pc)~right -
    "AC1="||.LROct~fromDecimal(cpu~accumulator(1))~string -
    "AC2="||.LROct~fromDecimal(cpu~accumulator(2))~string
say cpu~apr
exit
::requires "../KL10IPL.cls"
