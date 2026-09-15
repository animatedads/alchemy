numeric digits 30
mem=.KL10Memory~new
mem~mapZeroPage(0,0)
mem~put(oct("100"),oct("254000000100"))
cpu=.KL10CPU~new~~loadImage(mem,oct("100"))
state=.KL10State~new
meta=.directory~new
meta["checkpoint"]="fast-freeze-test"

f=state~freeze(cpu,meta)

/* Freeze is detached from later live-machine and caller-metadata mutation. */
meta["checkpoint"]="MUTATED-AFTER-FREEZE"
cpu~memory~put(oct("100"),oct("000000000000"))

call eq f~metadata["checkpoint"],"fast-freeze-test","metadata detached"
call eq f~recordCount>0,1,"records"
call eq f~byteCount>0,1,"bytes"
call eq f~schemaSha256,state~schemaSha256,"schema"

a="/tmp/kl10-fast-freeze-a.state"
b="/tmp/kl10-fast-freeze-b.state"
f~save(a)
f~save(b)

call eq sysFileExists(a),1,"a exists"
call eq sysFileExists(b),1,"b exists"
call eq fileBytes(a),fileBytes(b),"identical bytes"

loaded=.KL10State~new~load(a)
call eq loaded~pc,cpu~pc,"reload PC"
call eq loaded~memory~word(oct("100")),oct("254000000100"),"frozen word survives live mutation"

/* Compatibility wrapper over reconstructed frozen machine produces the same
 * bytes when given the original metadata. */
meta2=.directory~new
meta2["checkpoint"]="fast-freeze-test"
c="/tmp/kl10-fast-freeze-c.state"
state~save(loaded,c,meta2)
call eq fileBytes(a),fileBytes(c),"wrapper identical"
call eq state~memoryDigest,f~memoryDigest,"wrapper digest"

call sysFileDelete a
call sysFileDelete b
call sysFileDelete c
say "PASS test_state_fast_freeze"
exit

fileBytes: procedure
 use arg path
 s=.stream~new(path)~~open("READ")
 data=s~charin(,s~chars)
 s~close
 return data

eq: procedure
 use arg a,e,l
 if a\=e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return

oct: procedure
 use arg x
 x=changestr(",",x,"")
 n=0
 do i=1 to length(x); n=n*8+substr(x,i,1); end
 return n

::requires "../KL10IPL.cls"
