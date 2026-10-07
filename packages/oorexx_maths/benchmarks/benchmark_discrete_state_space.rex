numeric digits 18
ctx=.MathContext~binary64('SCIPY')
A=.array~of(.array~of(0.9981,0.0017),.array~of(-0.0012,0.9968))
B=.array~of(.array~of(0.012),.array~of(0.006))
C=.array~of(.array~of(0.7,-0.25))
D=.array~of(.array~of(0.02))
n=12000
inputs=.array~new
do k=1 to n; inputs~append(.array~of(0.3*RxCalcSin(k*0.031,18,'R')+(0.1*RxCalcSin(k*0.113,18,'R')))); end

/* ooRexx scalar recurrence baseline over the same represented coefficients. */
x1=0.02; x2=-0.01; checksum=0
reset=time('R')
do k=1 to n
 row=inputs[k]; sample=row[1]
 y=0.7*x1 - 0.25*x2 + (0.02*sample)
 checksum+=y
 nx1=0.9981*x1 + x2*0.0017 + sample*0.012
 nx2=-0.0012*x1 + x2*0.9968 + sample*0.006
 x1=nx1; x2=nx2
end
pureSeconds=time('E')

sys=.Maths~discreteStateSpace(A,B,C,D,ctx)
reset=time('R')
tr=sys~process(inputs,.array~of(0.02,-.01))
nativeSeconds=time('E')
nsum=0; do i=1 to n; nsum+=tr~outputs[i,1]; end
say 'samples='n
say 'oorexx_scalar_seconds='pureSeconds
say 'numpy_block_seconds='nativeSeconds
if nativeSeconds>0 then say 'speedup='pureSeconds/nativeSeconds
say 'checksum_difference='abs(checksum-nsum)
say 'final_state_difference='max(abs(x1-tr~finalState[1]),abs(x2-tr~finalState[2]))
::requires 'MathDynamicsProvider.cls'
::requires 'rxmath' LIBRARY
