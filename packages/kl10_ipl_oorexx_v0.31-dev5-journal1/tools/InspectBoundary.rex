numeric digits 30
parse arg statePath
cpu=.KL10State~new~load(statePath)
do i=0 to 8
 a=(cpu~pc+i)//(2**18)
 w=cpu~memory~word(a); d=cpu~decode(w)
 say .LROct~fromDecimal(a)~right .LROct~fromDecimal(w)~string d["mnemonic"] -
     "I="d["indirect"] "X="d["index"] "E=" .LROct~fromDecimal(d["address"])~right -
     "dev="d["device"]
end
say cpu
say cpu~pi
say cpu~apr
say cpu~pag
::requires "../KL10IPL.cls"
