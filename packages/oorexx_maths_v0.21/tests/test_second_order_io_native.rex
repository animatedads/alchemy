numeric digits 50
assertions=0
ctx=.MathContext~binary64('SCIPY')
M=.array~of(.array~of(1,0),.array~of(0,2))
C=.array~of(.array~of(.03,0),.array~of(0,.04))
K=.array~of(.array~of(7,-1.2),.array~of(-1.2,4))
sys=.Maths~secondOrderSystem(M,C,K,ctx)
B=.array~of(.array~of(1),.array~of(.4))
Hx=.array~of(.array~of(1,0))
Hv=.array~of(.array~of(.2,-.3))
io=.Maths~secondOrderInputOutputSystem(sys,B,Hx,Hv,ctx)
steps=80; dt=.0005
u=.array~new; forces=.array~new
do k=0 to steps
  uk=.15+.002*k
  u~append(.array~of(uk))
  forces~append(.array~of(uk,.4*uk))
end
p=io~integrateProjected(.array~of(.02,-.01),.array~of(.03,0),dt,steps,u,0,'SYMPLECTIC_EULER')
tr=sys~integrate(.array~of(.02,-.01),.array~of(.03,0),dt,steps,forces,0,'SYMPLECTIC_EULER')
call equal p~evidence~primaryProvider,'SCIPY','projected provider'; assertions+=1
call equal p~sampleCount,steps+1,'sample count'; assertions+=1
call equal p~outputCount,1,'output count'; assertions+=1
maxd=0
do k=0 to steps
 st=tr~state(k); y=st~displacement[1]+.2*st~velocity[1]-.3*st~velocity[2]
 d=(p~outputs[k+1,1]-y)~abs; if d>maxd then maxd=d
end
call near maxd,0,'2E-10','native selected output vs full trajectory'; assertions+=1
call near p~finalState~displacement[1],tr~finalState~displacement[1],'2E-12','native final x1'; assertions+=1
call near p~finalState~velocity[2],tr~finalState~velocity[2],'2E-9','native final v2'; assertions+=1
say 'PASS oorexx_maths second-order input/output native' assertions 'assertions'
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
