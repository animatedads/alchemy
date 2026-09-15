/* Host input remains queued until the DTE post-step service phase. */
parse arg statePath
if statePath="" then do; say "usage: rexx test_cpu_dte_input.rex prompt.state"; exit 2; end
cpu=.KL10State~new~load(statePath)
base=cpu~pag~ebPtr
dtf11=base+oct("0450")
dtmti=base+oct("0456")
call eq cpu~pc,oct("773466"),"prompt PC"
call eq cpu~memory~physicalWord(dtf11),0,"DTF11 initially clear"
call eq cpu~memory~physicalWord(dtmti),0,"DTMTI initially clear"

ignored=cpu~dte~type("N")
call eq cpu~dte~rxHex,"4E","queued N"
call eq cpu~memory~physicalWord(dtf11),0,"type does not mutate DTF11"
call eq cpu~memory~physicalWord(dtmti),0,"type does not mutate DTMTI"

/* CPU observes the old zero flag; only after that instruction does DTE fire. */
tr=cpu~step
call eq tr["mnemonic"],"SKIPN","first wait probe"
call eq cpu~pc,oct("773467"),"zero flag did not skip"
call eq cpu~memory~physicalWord(dtf11),asc("N"),"post-step DTF11 delivery"
call eq cpu~memory~physicalWord(dtmti),.KL10Word~allOnes,"post-step DTMTI flag"
call eq cpu~dte~rxHex,"","RX consumed"

/* JRST loops once; next SKIPN now observes the delivered input and skips. */
ignored=cpu~step
call eq cpu~pc,oct("773466"),"wait loop JRST"
tr=cpu~step
call eq tr["mnemonic"],"SKIPN","second wait probe"
call eq cpu~pc,oct("773470"),"input flag skips wait loop"
ignored=cpu~step
call eq cpu~accumulator(5),asc("N"),"MTBOOT reads N from DTF11"

say "PASS test_cpu_dte_input"
exit 0

asc: procedure
 use arg c
 return c2d(c)
oct: procedure
 use arg t
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a\=e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
