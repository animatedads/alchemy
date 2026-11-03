numeric digits 50
assertions=0
ctx=.MathContext~binary64('SCIPY')
/* Stable two-state filter/control fixture. */
A=.array~of(.array~of(.91,.04),.array~of(-.03,.86))
B=.array~of(.array~of(.12),.array~of(.07))
C=.array~of(.array~of(.8,-.2))
D=.array~of(.array~of(.05))
sys=.Maths~discreteStateSpace(A,B,C,D,ctx)
U=.array~new
do k=1 to 256; U~append(.array~of(.3*RxCalcSin(k*.071,30,'R')+.1)); end
native=sys~process(U,.array~of(.02,-.01))
call equal native~evidence~primaryProvider,'SCIPY','explicit SCIPY exposes inherited NumPy state-space provider'; assertions+=1
call equal native~sampleCount,256,'native sample count'; assertions+=1
call equal native~outputCount,1,'native output count'; assertions+=1

/* Independent PURE binary64 replay of the same represented inputs. */
pureCtx=.MathContext~binary64('PURE')
pureSys=.Maths~discreteStateSpace(A,B,C,D,pureCtx)
pure=pureSys~process(U,.array~of(.02,-.01))
maxY=0
do i=1 to 256
 diff=(native~outputs[i,1]-pure~outputs[i,1])~abs; if diff>maxY then maxY=diff
end
call near maxY,0,'1E-9','native outputs vs PURE recurrence'; assertions+=1
call near native~finalState[1],pure~finalState[1],'1E-9','native final state 1'; assertions+=1
call near native~finalState[2],pure~finalState[2],'1E-9','native final state 2'; assertions+=1

/* Native continuation blocks exactly resume the represented binary64 state. */
cont=sys~continuation(.array~of(.02,-.01))
u1=.array~new; u2=.array~new
do i=1 to 128; u1~append(U[i]); end
do i=129 to 256; u2~append(U[i]); end
r1=cont~advance(u1); snap=cont~snapshot; r2=cont~advance(u2)
call near cont~state[1],native~finalState[1],'2E-14','native block continuation state 1'; assertions+=1
call near cont~state[2],native~finalState[2],'2E-14','native block continuation state 2'; assertions+=1
ignored=cont~restore(snap); r2b=cont~advance(u2)
call near r2b~outputs[1,1],r2~outputs[1,1],'2E-14','native snapshot replay first output'; assertions+=1
call near r2b~outputs[128,1],r2~outputs[128,1],'2E-14','native snapshot replay last output'; assertions+=1

/* AUTO keeps tiny bridge-dominated recurrences local. */
autoCtx=.MathContext~binary64('AUTO')
autoSys=.Maths~discreteStateSpace(A,B,C,D,autoCtx)
autoTr=autoSys~process(U,.array~of(.02,-.01))
call equal autoTr~evidence~primaryProvider,'PURE','AUTO low-order recurrence stays PURE'; assertions+=1

/* AUTO selects native once state-work is large enough to amortize the bridge. */
na=16; aa=.array~new; bb=.array~new; ccrow=.array~new
do i=1 to na
 row=.array~new
 do j=1 to na; if i=j then val=.99; else val=0; row~append(val); end
 aa~append(row); bb~append(.array~of(.001)); ccrow~append(1/na)
end
cc=.array~of(ccrow); dd=.array~of(.array~of(0)); uu=.array~new
do k=1 to 1000; uu~append(.array~of(.1)); end
xzero=.array~new; do i=1 to na; xzero~append(0); end
big=.Maths~discreteStateSpace(aa,bb,cc,dd,autoCtx)~process(uu,xzero)
call equal big~evidence~primaryProvider,'NUMPY','AUTO larger recurrence selects NumPy'; assertions+=1

say 'PASS oorexx_maths discrete state-space native' assertions 'assertions maxY='maxY
exit 0

equal: procedure
 parse arg actual,expected,label
 if actual\==expected then do; say 'FAIL' label 'actual='actual 'expected='expected; exit 1; end
 return
near: procedure
 parse arg actual,expected,tol,label
 if (actual-expected)~abs>tol then do; say 'FAIL' label 'actual='actual 'expected='expected 'tol='tol; exit 1; end
 return
::requires 'MathDynamicsProvider.cls'
::requires 'rxmath' LIBRARY
