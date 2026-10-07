numeric digits 30
stations=.array~new
rr=.ConstantRollingResistance~new(.01); wear=.EnergyProportionalWearLaw~new(.000000001)
s=.LinearLandingStrut~new(1000000,100000,.5)
names=.array~of('NOSE','MAINL','MAINR')
do name over names
  if name='NOSE' then share=.2
  else share=.4
  mass=10000*share
  w=.WheelTyreState~new(.5,10,rr,wear)
  g=.LandingGearState~new(mass,s,w,1,.05)
  stations~append(.GroundGearStation~new(name,g,share))
end
x=.AircraftGroundExperiment~new(10000,70,stations)
o=x~step(.01,.8,0)
if o~stations~items<>3 | o~resistingForce<=0 | o~groundSpeed>=70 then exit 1
say 'PHYSICS AIRCRAFT MULTI-STATION GROUND: OK stations=' o~stations~items 'resist=' o~resistingForce 'speed=' o~groundSpeed
::requires 'AircraftGroundDynamics.cls'
