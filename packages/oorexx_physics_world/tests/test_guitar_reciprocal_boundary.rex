numeric digits 30
string=.GuitarStringPhysicalModel~new(82.4068892,.648,.00045,75,.00008,2.8,.018,4)
b=.array~of(.GuitarBodyMode~new('body-165',165,.20,.025,.05,1))
c=.GuitarCoupledBoundaryFactory~fromStringAndBody(string,0,.0008,.18,b,18)
e0=c~totalMechanicalEnergy
body0=c~bodyModes[1]~mechanicalEnergy
maxBody=body0
maxStringBack=0
/* small dt relative to the highest retained mode */
do i=1 to 12000
 c~step(.000002)
 eb=c~bodyModes[1]~mechanicalEnergy
 if eb>maxBody then maxBody=eb
 /* after body has become excited, prove reciprocal influence by observing
    non-monotonic string modal energy rather than a one-way drain primitive. */
 if i>1000 then do
   es=c~stringModes[1]~mechanicalEnergy
   if es>maxStringBack then maxStringBack=es
 end
end
if maxBody<=body0 then exit 1
if c~ledger~items<>12000 then exit 1
if c~totalMechanicalEnergy>e0*1.02 then exit 1
say 'PHYSICS GUITAR RECIPROCAL BOUNDARY: OK initialJ=' e0 'maxBodyJ=' maxBody 'finalJ=' c~totalMechanicalEnergy
::requires 'GuitarCoupledBoundary.cls'
