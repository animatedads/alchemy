numeric digits 30
parse arg statePath
if statePath="" then do; say "usage: rexx test_cpu_map.rex pre-map.state"; exit 2; end
state=.KL10State~new
cpu=state~load(statePath)
call eq cpu~pc,oct("772512"),"pre-MAP PC"
beforeCst=cpu~memory~physicalWord(oct("742762"))
beforeDigest=state~memoryDigest
p=cpu~preview
call eq p["mnemonic"],"MAP","preview MAP"
tr=cpu~step
call eq tr["mnemonic"],"MAP","execute MAP"
call eq tr["effectiveAddress"],oct("762000"),"MAP E"
call eq tr["mapPhysicalAddress"],oct("762000"),"MAP PA"
call eq tr["result"],oct("160000762000"),"MAP result word"
call eq cpu~accumulator(1),oct("160000762000"),"MAP AC1"
call eq cpu~memory~physicalWord(oct("742762")),beforeCst,"MAP does not mutate CST"
call eq cpu~pc,oct("772513"),"MAP advances PC"
say "PASS test_cpu_map"; exit 0
oct: procedure
 use arg t
 t=changestr(",",t,"")
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a\=e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
