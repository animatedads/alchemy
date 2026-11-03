parse arg provider n rounds
if provider='' then provider='PURE'
if n='' then n=10000
if rounds='' then rounds=5
numeric digits 30
if provider='NUMPY' then ctx=.MathContext~binary64('NUMPY'); else ctx=.MathContext~binary64('PURE')
a=.array~new; b=.array~new
do i=1 to n; a~append(i/10); b~append((n-i)/7); end
va=.MathVector~new(a,ctx); vb=.MathVector~new(b,ctx)
reset=time('R')
x=va
do r=1 to rounds
  x=(x+vb)~hadamard(va)
end
elapsed=time('E')
s=x[1]+x[n]
say provider 'n='n 'rounds='rounds 'elapsed='elapsed 'checksum='s
::requires 'MathNumpyProvider.cls'
