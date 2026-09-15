/* Safety15 pre-promotion ALR object-scope candidate. */
numeric digits 30
m=.IBM4361Machine~new(1048576); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=0; m~restoreMachineState(md)
cs=m~cpu~state; cs['stopped']=0; cs['psw']='0004000000001000'; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('1000'),'1E12')
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; f=self~rr(i); a=cpu~gprFast(f[1]); b=cpu~gprFast(f[2]); exact=a+b; carry=(exact>=4294967296); v=exact//4294967296; cpu~setGprFast(f[1],v); if carry then do; if v=0 then cc=2; else cc=3; end; else do; if v=0 then cc=0; else cc=1; end; cpu~psw~setConditionCode(cc); return ia+2"
call eq m~tick,'OK','permanent ALR baseline'
/* Restore the invocation, then overlay the object-scope candidate. */
m~cpu~psw~loadRawHex('0004000000001000'); m~storage~storeHex(x2d('1000'),'1E12')
call eq m~executor~installLiveMethod('OP1E',source),1,'install ALR'
call runCase m,0,0,0,0
call runCase m,1,1,2,1
call runCase m,x2d('FFFFFFFF'),1,0,2
call runCase m,x2d('FFFFFFFF'),2,1,3
/* alias R1==R2 */
m~storage~storeHex(x2d('1000'),'1E11'); m~cpu~setGpr(1,x2d('80000000')); m~cpu~psw~loadRawHex('0004000000001000')
call eq m~tick,'OK','alias ALR executes'; call eq m~cpu~gpr(1),0,'alias result'; call eq m~cpu~psw~conditionCode,2,'alias carry-zero CC'
say 'PASS test_cpu_alr_live_trial'
exit 0
runCase: procedure
  use arg m,a,b,want,cc
  m~storage~storeHex(x2d('1000'),'1E12'); m~cpu~setGpr(1,a); m~cpu~setGpr(2,b); m~cpu~psw~loadRawHex('0004000000001000')
  call eq m~tick,'OK','ALR executes'; call eq m~cpu~gpr(1),want,'ALR result'; call eq m~cpu~psw~conditionCode,cc,'ALR CC'
return
eq: procedure
  parse arg got,want,label
  if got==want then return
  say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361.cls'
