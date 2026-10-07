numeric digits 70
assertions=0
ctx=.MathContext~rational

/* Exact bounded sample delay. */
d=.Maths~sampleDelayLine(3,0,ctx)
out=d~process(.array~of(1,2,3,4,5))
call equal out[1]~string,'0','delay sample 1'; assertions+=1
call equal out[2]~string,'0','delay sample 2'; assertions+=1
call equal out[3]~string,'0','delay sample 3'; assertions+=1
call equal out[4]~string,'1','delay sample 4'; assertions+=1
call equal out[5]~string,'2','delay sample 5'; assertions+=1
call equal d~delaySamples,3,'delay length retained'; assertions+=1

/* Snapshot/restore is deterministic continuation state. */
d2=.Maths~sampleDelayLine(2,0,ctx)
ignored=d2~push(7)
snap=d2~snapshot
first=d2~push(8); next1=d2~push(9)
ignored=d2~restore(snap)
again=d2~push(8); next2=d2~push(9)
call equal first~string,again~string,'delay restore first output'; assertions+=1
call equal next1~string,next2~string,'delay restore second output'; assertions+=1

/* Zero delay is an identity boundary. */
d0=.Maths~sampleDelayLine(0,0,ctx)
call equal d0~push(17),17,'zero sample delay identity'; assertions+=1

/* Stateful blocks must equal one monolithic discrete integration. */
one=.array~of(.array~of(1)); zero=.array~of(.array~of(0))
sys=.Maths~secondOrderSystem(one,zero,one,ctx)
dt=.Maths~fraction(1,10)
force=.MathVector~new(.array~of(.Maths~fraction(1,5)),ctx)
whole=sys~integrate(.array~of(1),.array~of(0),dt,6,force,0,'SYMPLECTIC_EULER')
cont=.Maths~secondOrderContinuation(sys,.array~of(1),.array~of(0),0,'SYMPLECTIC_EULER')
b1=cont~advance(dt,3,force)
b2=cont~advance(dt,3,force)
call equal cont~time~string,whole~finalState~time~string,'continuation time equals monolithic'; assertions+=1
call equal cont~displacement[1]~string,whole~finalState~displacement[1]~string,'continuation displacement equals monolithic'; assertions+=1
call equal cont~velocity[1]~string,whole~finalState~velocity[1]~string,'continuation velocity equals monolithic'; assertions+=1
call equal b1~finalState~time~string,'3/10','first block endpoint'; assertions+=1
call equal b2~startTime~string,'3/10','second block starts at prior endpoint'; assertions+=1

/* Final-only blocks retain state without materialising the trajectory. */
cont2=.Maths~secondOrderContinuation(sys,.array~of(1),.array~of(0),2,'NEWMARK')
f1=cont2~advanceFinal(dt,2,force)
f2=cont2~advanceFinal(dt,2,force)
call equal cont2~time~string,'12/5','final-only continuation time'; assertions+=1
call equal cont2~lastState~time~string,f2~time~string,'last state retained'; assertions+=1

say 'PASS oorexx_maths causal continuation' assertions 'assertions'
exit 0

equal: procedure
  parse arg actual,expected,label
  if actual\==expected then do; say 'FAIL' label 'actual='actual 'expected='expected; exit 1; end
  say 'PASS' label
  return

::requires 'MathsBootstrap.cls'
