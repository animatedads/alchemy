numeric digits 70
assertions=0

/* Exact discrete mechanics in the rational lane. */
rctx=.MathContext~rational
one=.array~of(.array~of(1)); zero=.array~of(.array~of(0))
rsys=.Maths~secondOrderSystem(one,zero,one,rctx)
half=.Maths~fraction(1,2)
rt=rsys~integrate(.array~of(1),.array~of(0),half,1,.nil,0,'SYMPLECTIC_EULER')
call equal rt~stepCount,1,'rational symplectic step count'; assertions+=1
call equal rt~finalState~displacement[1]~string,'3/4','rational symplectic exact displacement'; assertions+=1
call equal rt~finalState~velocity[1]~string,'-1/2','rational symplectic exact velocity'; assertions+=1
call equal rt~finalState~acceleration[1]~string,'-3/4','rational symplectic exact acceleration'; assertions+=1
call equal rt~evidence~steps[1]~guarantee,'EXACT_DISCRETE_INTEGRATOR','rational dynamics evidence remains exact discrete arithmetic'; assertions+=1

rn=rsys~integrate(.array~of(1),.array~of(0),half,1,.nil,0,'NEWMARK_AVERAGE_ACCELERATION')
call equal rn~finalState~displacement[1]~string,'15/17','rational Newmark exact displacement'; assertions+=1
call equal rn~finalState~velocity[1]~string,'-8/17','rational Newmark exact velocity'; assertions+=1
call equal rn~finalState~acceleration[1]~string,'-15/17','rational Newmark exact acceleration'; assertions+=1

/* Constant-force exact Newmark result: x=1/2, v=1 after one second. */
free=.Maths~secondOrderSystem(one,zero,zero,rctx)
force=.MathVector~new(.array~of(1),rctx)
rf=free~integrate(.array~of(0),.array~of(0),1,1,force,0,'NEWMARK')
call equal rf~finalState~displacement[1]~string,'1/2','constant force exact Newmark displacement'; assertions+=1
call equal rf~finalState~velocity[1]~string,'1','constant force exact Newmark velocity'; assertions+=1
call equal rf~finalState~acceleration[1]~string,'1','constant force exact Newmark acceleration'; assertions+=1

/* Native BINARY64 route: one-DOF oscillator and retained diagnostics. */
ctx=.MathContext~binary64('SCIPY')
sys=.Maths~secondOrderSystem(.array~of(.array~of(1)),.array~of(.array~of(0)),.array~of(.array~of(4)),ctx)
t=sys~integrate(.array~of(1),.array~of(0),.01,10,.nil,2,'NEWMARK_AVERAGE_ACCELERATION')
call equal t~evidence~primaryProvider,'SCIPY','native trajectory provider'; assertions+=1
call equal t~stepCount,10,'native trajectory step count'; assertions+=1
call near t~finalState~time,'2.1','1E-15','trajectory start-time offset'; assertions+=1
call near t~finalState~displacement[1],'0.980067902','2E-9','native Newmark displacement'; assertions+=1
call check t~evidence~checks['equilibriumResidualInf']<1E-10,'native equilibrium residual diagnostic'; assertions+=1
call check t~evidence~checks['kinematicDisplacementResidualInf']<1E-12,'native displacement consistency diagnostic'; assertions+=1
call check t~evidence~checks['kinematicVelocityResidualInf']<1E-12,'native velocity consistency diagnostic'; assertions+=1
call check t~evidence~checks['conditionMass']>=1,'native mass condition evidence'; assertions+=1

p=t~prove(.MathClaim~independentlyReproduced('1E-8'))
call equal p~outcome,'PROVED','native Newmark independently reproduced'; assertions+=1
call equal p~verificationEvidence~primaryProvider,'REFERENCE','Newmark proof switches provider'; assertions+=1
call check p~checks['differentAlgorithm'],'Newmark proof has a different linear-solver implementation'; assertions+=1

/* Final-only native result avoids materialising the entire trajectory. */
f=sys~integrateFinal(.array~of(1),.array~of(0),.01,10,.nil,5,'SYMPLECTIC_EULER')
call equal f~evidence~primaryProvider,'SCIPY','native final-state provider'; assertions+=1
call near f~time,'5.1','1E-15','final-state start-time offset'; assertions+=1
call near f~displacement[1],'0.97807909','2E-9','native symplectic displacement'; assertions+=1
fp=f~prove(.MathClaim~independentlyReproduced('1E-8'))
call equal fp~outcome,'PROVED','native final state independently reproduced'; assertions+=1
call equal fp~verificationEvidence~primaryProvider,'REFERENCE','final-state proof switches provider'; assertions+=1

/* Coupling transfers motion into an initially silent second coordinate. */
M=.array~of(.array~of(1,0),.array~of(0,1))
C=.array~of(.array~of('.02',0),.array~of(0,'.02'))
K=.array~of(.array~of(5,-1),.array~of(-1,5))
csys=.Maths~secondOrderSystem(M,C,K,ctx)
ct=csys~integrateFinal(.array~of(1,0),.array~of(0,0),.001,100,.nil,0,'SYMPLECTIC_EULER')
call check ct~displacement[2]~abs>0,'coupled second coordinate receives motion'; assertions+=1
call check ct~evidence~checks['equilibriumResidualInf']<1E-10,'coupled native residual bounded'; assertions+=1

/* Full force history is explicit: one row for each retained time. */
forces=.MathMatrix~new(.array~of(.array~of(0),.array~of(1),.array~of(1)),ctx)
fh=.Maths~secondOrderSystem(.array~of(.array~of(1)),zero,zero,ctx)~integrate(.array~of(0),.array~of(0),.1,2,forces,0,'NEWMARK')
call equal fh~stepCount,2,'force-history trajectory step count'; assertions+=1
call check fh~finalState~velocity[1]>0,'force history drives system'; assertions+=1

say 'PASS oorexx_maths second-order dynamics' assertions 'assertions'
exit 0

check: procedure
  parse arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return

equal: procedure
  parse arg actual,expected,label
  if actual\==expected then do; say 'FAIL' label 'actual='actual 'expected='expected; exit 1; end
  say 'PASS' label
  return

near: procedure
  parse arg actual,expected,tol,label
  numeric digits 70
  if (actual-expected)~abs>tol then do; say 'FAIL' label 'actual='actual 'expected='expected 'tol='tol; exit 1; end
  say 'PASS' label
  return

::requires 'MathDynamicsProvider.cls'
