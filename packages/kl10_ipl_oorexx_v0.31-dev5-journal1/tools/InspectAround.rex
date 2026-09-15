numeric digits 30
parse arg statePath startOct count
if count="" then count=16
cpu=.KL10State~new~load(statePath)
a=oct(startOct)
do i=0 to count-1
 w=cpu~memory~word((a+i)//(2**18)); d=cpu~decode(w)
 say .LROct~fromDecimal((a+i)//(2**18))~right .LROct~fromDecimal(w)~string d["mnemonic"] -
 "AC="d["ac"] "I="d["indirect"] "X="d["index"] "Y=" .LROct~fromDecimal(d["address"])~right
end
exit
oct: procedure
 use arg t
 n=0
 do j=1 to length(t); n=n*8+substr(t,j,1); end
 return n
::requires "../KL10IPL.cls"
