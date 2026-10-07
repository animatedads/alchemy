numeric digits 50
ctx=.MathContext~binary64('SCIPY')
M=.array~of(.array~of(1,0),.array~of(0,1))
C=.array~of(.array~of('.02',0),.array~of(0,'.02'))
K=.array~of(.array~of(5,-1),.array~of(-1,5))
system=.Maths~secondOrderSystem(M,C,K,ctx)
final=system~integrateFinal(.array~of(1,0),.array~of(0,0),.001,1000,.nil,0,'SYMPLECTIC_EULER')
say 'final time:' final~time
say 'x:' final~displacement
say 'v:' final~velocity
say 'provider:' final~evidence~primaryProvider
say 'equilibrium residual:' final~evidence~checks['equilibriumResidualInf']
proof=final~prove(.MathClaim~independentlyReproduced('1E-8'))
say 'independent replay:' proof~outcome proof~strength
::requires 'MathDynamicsProvider.cls'
