numeric digits 30
/* Two string-like oscillators coupled through one body oscillator.  String B
   starts silent: any later energy is sympathetic excitation through the body. */
s=.array~new
s~append(.GuitarCoupledOscillator~new('A',.00015,110,.003,.0006,0,'STRING_MODE'))
s~append(.GuitarCoupledOscillator~new('B',.00015,112,.003,0,0,'STRING_MODE'))
b=.array~of(.GuitarCoupledOscillator~new('body',.18,111,.02,0,0,'BODY_MODE'))
c=.GuitarCoupledBoundary~new(s,b,10)
initialB=s[2]~mechanicalEnergy
maxB=initialB
do i=1 to 20000
 c~step(.000002)
 e=s[2]~mechanicalEnergy
 if e>maxB then maxB=e
end
if initialB<>0 then exit 1
if maxB<=1E-14 then exit 1
say 'PHYSICS GUITAR SYMPATHETIC STRING: OK silentInitialJ=' initialB 'excitedMaxJ=' maxB
::requires 'GuitarCoupledBoundary.cls'
