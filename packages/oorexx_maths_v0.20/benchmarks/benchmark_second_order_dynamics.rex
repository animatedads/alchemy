parse arg n steps
if n='' then n=32
if steps='' then steps=1200
numeric digits 40
M=.array~new; C=.array~new; K=.array~new; x0=.array~new; v0=.array~new
do i=1 to n
  mr=.array~new; cr=.array~new; kr=.array~new
  do j=1 to n
    if i=j then do; mr~append(1); cr~append('.015'); kr~append(4+i/20); end
    else do
      mr~append(0); cr~append(0)
      if (i-j)~abs=1 then kr~append('-.05'); else kr~append(0)
    end
  end
  M~append(mr); C~append(cr); K~append(kr)
  if i=1 then x0~append(1); else x0~append(0)
  v0~append(0)
end
ctx=.MathContext~binary64('SCIPY')
system=.Maths~secondOrderSystem(M,C,K,ctx)
call time 'R'
final=system~integrateFinal(x0,v0,.00001,steps,.nil,0,'SYMPLECTIC_EULER')
elapsed=time('E')
say 'DOF='n 'STEPS='steps 'SECONDS='elapsed 'PROVIDER='final~evidence~primaryProvider
say 'EQUILIBRIUM_RESIDUAL='final~evidence~checks['equilibriumResidualInf']
::requires 'MathDynamicsProvider.cls'
