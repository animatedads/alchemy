numeric digits 70
assertions=0
ctx=.MathContext~rational

/* Exact accumulator: y[k]=x[k], x[k+1]=x[k]+u[k]. */
A=.array~of(.array~of(1)); B=.array~of(.array~of(1)); C=.array~of(.array~of(1)); D=.array~of(.array~of(0))
sys=.Maths~discreteStateSpace(A,B,C,D,ctx)
U=.array~of(.array~of(1),.array~of(2),.array~of(3))
tr=sys~process(U,.array~of(0))
call equal tr~outputs[1,1]~string,'0','accumulator output sample 1'; assertions+=1
call equal tr~outputs[2,1]~string,'1','accumulator output sample 2'; assertions+=1
call equal tr~outputs[3,1]~string,'3','accumulator output sample 3'; assertions+=1
call equal tr~finalState[1]~string,'6','accumulator final state'; assertions+=1
call equal tr~sampleCount,3,'trajectory sample count'; assertions+=1
call equal sys~stateCount,1,'state count'; assertions+=1
call equal sys~inputCount,1,'input count'; assertions+=1
call equal sys~outputCount,1,'output count'; assertions+=1

/* Feedthrough is evaluated from the same input sample before state advance. */
sys2=.Maths~discreteStateSpace(A,B,C,.array~of(.array~of(2)),ctx)
t2=sys2~process(.array~of(.array~of(4)),.array~of(3))
call equal t2~outputs[1,1]~string,'11','feedthrough convention y=Cx+Du'; assertions+=1
call equal t2~finalState[1]~string,'7','state convention xnext=Ax+Bu'; assertions+=1

/* Block continuation equals monolithic recurrence and snapshot is deterministic. */
cont=sys~continuation(.array~of(0))
b1=cont~advance(.array~of(.array~of(1),.array~of(2)))
snap=cont~snapshot
b2=cont~advance(.array~of(.array~of(3),.array~of(4)))
call equal cont~state[1]~string,'10','continued final state'; assertions+=1
call equal cont~samplesProcessed,4,'continued sample count'; assertions+=1
ignored=cont~restore(snap)
b2r=cont~advance(.array~of(.array~of(3),.array~of(4)))
call equal b2r~outputs[1,1]~string,b2~outputs[1,1]~string,'snapshot restore output 1'; assertions+=1
call equal b2r~outputs[2,1]~string,b2~outputs[2,1]~string,'snapshot restore output 2'; assertions+=1
call equal cont~state[1]~string,'10','snapshot restore final state'; assertions+=1

/* Multi-input / multi-output shape and exact arithmetic. */
A2=.array~of(.array~of(1,1),.array~of(0,1))
B2=.array~of(.array~of(1,0),.array~of(0,1))
C2=.array~of(.array~of(1,0),.array~of(0,1))
D2=.array~of(.array~of(0,0),.array~of(0,0))
s2=.Maths~discreteStateSpace(A2,B2,C2,D2,ctx)
t=s2~process(.array~of(.array~of(2,3),.array~of(0,1)),.array~of(0,0))
call equal t~outputs[1,1]~string,'0','multi output first state sample1'; assertions+=1
call equal t~outputs[2,2]~string,'3','multi output second state sample2'; assertions+=1
call equal t~finalState[1]~string,'5','multi final state 1'; assertions+=1
call equal t~finalState[2]~string,'4','multi final state 2'; assertions+=1

say 'PASS oorexx_maths discrete state-space' assertions 'assertions'
exit 0

equal: procedure
 parse arg actual,expected,label
 if actual\==expected then do; say 'FAIL' label 'actual='actual 'expected='expected; exit 1; end
 return
::requires 'MathsBootstrap.cls'
