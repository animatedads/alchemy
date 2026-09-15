numeric digits 30
parse arg statePath
s=.KL10State~new
cpu=s~load(statePath)
rh=cpu~rh20(oct("540"))
t=rh~unit(0)
say "LOADED" statePath
say "schema=" || s~schemaSha256
say "PC=" || .LROct~fromDecimal(cpu~pc)~right "ICOUNT=" || cpu~instructionCount
say "RH20=" || rh~string
say "TAPE=" || t~string
say "PENDING=" || t~pendingRecord["kind"] || "/" || t~pendingRecord["length"]
say "WORD0=" || .LROct~fromDecimal(t~pendingWord36(0))~string
say "MEM0=" || .LROct~fromDecimal(cpu~memory~physicalWord(oct("771000")))~string
exit
oct: procedure
 use arg x
 x=changestr(",",x,"")
 n=0
 do i=1 to length(x); n=n*8+substr(x,i,1); end
 return n
::requires "../KL10IPL.cls"
