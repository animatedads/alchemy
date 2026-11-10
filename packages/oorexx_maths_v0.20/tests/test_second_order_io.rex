numeric digits 30
assertions=0
ctx=.MathContext~decimal(30)
M=.array~of(.array~of(2,0),.array~of(0,1))
C=.array~of(.array~of(.2,0),.array~of(0,.1))
K=.array~of(.array~of(8,-1),.array~of(-1,5))
sys=.Maths~secondOrderSystem(M,C,K,ctx)
B=.array~of(.array~of(1),.array~of(.5))
Hx=.array~of(.array~of(1,0),.array~of(0,0))
Hv=.array~of(.array~of(0,0),.array~of(.25,-.5))
io=.Maths~secondOrderInputOutputSystem(sys,B,Hx,Hv,ctx)
call assert io~inputCount=1,'one input'; assertions+=1
call assert io~outputCount=2,'two outputs'; assertions+=1
steps=20; dt=.001
u=.array~new; do i=0 to steps; u~append(.array~of(.3)); end
p=io~integrateProjected(.array~of(.1,-.05),.array~of(0,.02),dt,steps,u,0,'SYMPLECTIC_EULER')
call assert p~sampleCount=steps+1,'sample count'; assertions+=1
call assert p~outputCount=2,'output count'; assertions+=1
fullF=.array~new
do k=0 to steps; fullF~append(.array~of(.3,.15)); end
tr=sys~integrate(.array~of(.1,-.05),.array~of(0,.02),dt,steps,fullF,0,'SYMPLECTIC_EULER')
maxd=0
do k=0 to steps
 st=tr~state(k); y1=st~displacement[1]; y2=.25*st~velocity[1]-.5*st~velocity[2]
 d=(p~outputs[k+1,1]-y1)~abs; if d>maxd then maxd=d
 d=(p~outputs[k+1,2]-y2)~abs; if d>maxd then maxd=d
end
call assert maxd<1E-24,'PURE selected outputs reproduce full trajectory'; assertions+=1
call assert p~finalState~maxAbsDifference(tr~finalState)<1E-24,'PURE final state matches full integration'; assertions+=1
say 'PASS second-order input/output PURE' assertions 'assertions'
exit 0
assert: procedure
 use strict arg condition,label
 if \condition then do; say 'FAIL:' label; exit 1; end
 return
::requires 'MathsBootstrap.cls'
