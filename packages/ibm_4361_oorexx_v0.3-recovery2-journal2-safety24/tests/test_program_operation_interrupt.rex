/* Safety14 permanent BC-mode operation-exception program interruption. */
numeric digits 30
call caseOne 0,'0004000A60000000','00040000000002CA','0004000160000002'
call caseOne x2d('1000'),'0004000A60000000','00040000000003AA','0004000160000002'
/* A real emulator coverage gap is still atomic and is not reclassified. */
m=makeMachine(0,'0004000000000400',0)
m~storage~storeHex(x2d('0400'),'4C00')
ic=m~cpu~instructionCount
call eq m~tick,'UNSUPPORTED','unclassified missing opcode'
call eq m~cpu~psw~instructionAddress,x2d('0400'),'missing opcode IA atomic'
call eq m~cpu~instructionCount,ic,'missing opcode IC atomic'
call eq m~executor~hasMethod('OP00'),0,'no synthetic OP00'
say 'PASS test_program_operation_interrupt'
exit 0

caseOne: procedure expose m
  parse arg prefix,pre,newpsw,oldwant
  m=makeMachine(prefix,pre,77)
  m~storage~storeHex((prefix+x2d('68'))//16777216,newpsw)
  call eq m~tick,'OK','operation exception delivered'
  call eq m~storage~fetchHex((prefix+x2d('28'))//16777216,8),oldwant,'program-old exact'
  call eq m~cpu~psw~rawHex,newpsw,'program-new full load'
  call eq m~cpu~instructionCount,78,'operation exception counted once'
  call eq m~executor~hasMethod('OP00'),0,'no OP00 during operation exception'
return

makeMachine: procedure
  parse arg prefix,psw,ic
  m=.IBM4361Machine~new(1048576); m~powerOn
  md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
  cs=m~cpu~state; cs['psw']=psw; cs['prefix']=prefix; cs['stopped']=0; cs['instructionCount']=ic; m~cpu~restoreState(cs)
  return m

eq: procedure
  parse arg got,want,label
  if got==want then return
  say 'FAIL' label 'got='got 'want='want
  exit 1
::requires 'IBM4361.cls'
