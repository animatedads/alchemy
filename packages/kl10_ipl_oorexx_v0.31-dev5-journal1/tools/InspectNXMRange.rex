numeric digits 30
parse arg statePath
cpu=.KL10State~new~load(statePath)
m=cpu~memory
do v=oct("645000") to oct("654000") by oct("001000")
  tr=m~translate(v,1,1)
  say .LROct~fromDecimal(v)~right "->" .LROct~fromDecimal(tr["physical"])~right -
      "page="||.LROct~fromDecimal(tr["physical"]%512)~right -
      "exists="||m~physicalExists(tr["physical"])
end
exit
oct: procedure
 use arg t
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
::requires "../KL10IPL.cls"
