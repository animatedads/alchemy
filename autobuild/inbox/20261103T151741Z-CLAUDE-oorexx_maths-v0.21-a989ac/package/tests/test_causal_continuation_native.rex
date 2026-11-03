numeric digits 50
assertions=0
ctx=.MathContext~binary64('SCIPY')
M=.array~of(.array~of(1,0),.array~of(0,1))
C=.array~of(.array~of('.02',0),.array~of(0,'.02'))
K=.array~of(.array~of(5,-1),.array~of(-1,5))
sys=.Maths~secondOrderSystem(M,C,K,ctx)
whole=sys~integrate(.array~of(1,0),.array~of(0,0),.001,100,.nil,0,'SYMPLECTIC_EULER')
cont=.Maths~secondOrderContinuation(sys,.array~of(1,0),.array~of(0,0),0,'SYMPLECTIC_EULER')
do n=1 to 4
  block=cont~advance(.001,25)
  call equal block~evidence~primaryProvider,'SCIPY','block provider remains native'; assertions+=1
end
call near cont~time,whole~finalState~time,'1E-14','native continuation time'; assertions+=1
call near cont~displacement[1],whole~finalState~displacement[1],'1E-12','native continuation x1'; assertions+=1
call near cont~displacement[2],whole~finalState~displacement[2],'1E-12','native continuation x2'; assertions+=1
call near cont~velocity[1],whole~finalState~velocity[1],'2E-9','native continuation v1'; assertions+=1
call near cont~velocity[2],whole~finalState~velocity[2],'2E-9','native continuation v2'; assertions+=1

/* Delay state composes with native block output without a Python-side semantic object. */
d=.Maths~sampleDelayLine(4,0,ctx)
y=d~process(.array~of(1,2,3,4,5,6))
call near y[5],1,'1E-15','native-context delay output'; assertions+=1

say 'PASS oorexx_maths native causal continuation' assertions 'assertions'
exit 0

equal: procedure
  parse arg actual,expected,label
  if actual\==expected then do; say 'FAIL' label 'actual='actual 'expected='expected; exit 1; end
  say 'PASS' label
  return
near: procedure
  parse arg actual,expected,tol,label
  if (actual-expected)~abs>tol then do; say 'FAIL' label 'actual='actual 'expected='expected 'tol='tol; exit 1; end
  say 'PASS' label
  return

::requires 'MathDynamicsProvider.cls'
