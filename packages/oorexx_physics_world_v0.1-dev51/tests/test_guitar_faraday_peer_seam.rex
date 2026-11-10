numeric digits 30
string=.GuitarStringPhysicalModel~new(82.4068892)
geom=.MagneticFluxGeometry~new(0.000001,0.00012,.82,'fixture-gradient')
probe=.GuitarStringMagneticFluxProbe~new(string,geom)
p1=probe~observe(5,0)
p2=probe~observe(5,0.0001)
o1=.MagneticFluxObservation~new(.Units~q(p1~timeSeconds,.Units~second),.Units~q(p1~fluxWebers,.Units~weber),p1~source,p1~evidence,'physics string flux')
o2=.MagneticFluxObservation~new(.Units~q(p2~timeSeconds,.Units~second),.Units~q(p2~fluxWebers,.Units~weber),p2~source,p2~evidence,'physics string flux')
pickup=.GuitarMagneticPickup~new('bridge',800,.Units~q(6200,.Units~ohm),.Units~q(2.4,.Units~henry),.Units~q(100E-12,.Units~farad))
v=pickup~inducedVoltageBetween(o1,o2)
expected=-pickup~turns*(p2~fluxWebers-p1~fluxWebers)/(p2~timeSeconds-p1~timeSeconds)
if abs(v-expected)>1E-20 then exit 1
say 'PHYSICS -> REXX-TRONICS GUITAR FARADAY SEAM: OK volts='v
::requires 'GuitarStringMagnetics.cls'
::requires 'RexxTronicsGuitar.cls'
