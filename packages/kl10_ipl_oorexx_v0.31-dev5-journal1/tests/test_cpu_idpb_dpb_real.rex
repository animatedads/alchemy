numeric digits 30
/* Real post-ENTER byte-pointer archaeology. */
parse arg statePath
if statePath="" then do
  say "usage: rexx test_cpu_idpb_dpb_real.rex after-enter.state"
  exit 2
end
cpu=.KL10State~new~load(statePath)

/* IDPB: AC5 CR through AC7 byte pointer. */
call eq cpu~pc,oct("773446"),"IDPB PC"
call eq cpu~accumulator(5),oct("15"),"CR source"
call eq cpu~accumulator(7),oct("440700772056"),"IDPB pointer before"
tr=cpu~step
call eq tr["mnemonic"],"IDPB","IDPB mnemonic"
call eq tr["byteValue"],13,"IDPB deposited CR"
call eq cpu~accumulator(7),oct("350700772056"),"IDPB pointer after"
call eq first7(cpu~memory~word(oct("772056"))),13,"IDPB target byte"

/* Advance to the real DPB. */
do 79
  ignored=cpu~step
end
call eq cpu~pc,oct("772652"),"DPB PC"
p=cpu~preview
call eq p["mnemonic"],"DPB","DPB mnemonic"
pointerBefore=cpu~memory~word(oct("775160"))
call eq pointerBefore,oct("320737000000"),"indexed/indirect DPB pointer"
targetBefore=cpu~memory~word(oct("772646"))
call eq targetBefore,oct("700201000000"),"unpatched CONO template"
tr=cpu~step
call eq tr["byteValue"],oct("130"),"DPB low seven bits"
call eq cpu~memory~word(oct("775160")),pointerBefore,"DPB pointer unchanged"
call eq tr["byteAddress"],oct("772646"),"DPB resolves self-modifying CONO"
call eq cpu~memory~word(oct("772646")),oct("754201000000"),"DPB patches RH20 device field"

say "PASS test_cpu_idpb_dpb_real"
exit 0

first7: procedure
  use arg word
  numeric digits 30
  return (word % (2**29)) // 128

oct: procedure
  use arg t
  t=changestr(",",t,"")
  n=0
  do i=1 to length(t)
    n=n*8+substr(t,i,1)
  end
  return n

eq: procedure
  use arg actual,expected,label
  if actual \= expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires "../KL10IPL.cls"
