numeric digits 50
points=.array~new
points~append(.PowerIntensityPoint~new('0 W', .Units~q(0,.Units~candela)))
points~append(.PowerIntensityPoint~new('0.01 W', .Units~q(0.1,.Units~candela)))
points~append(.PowerIntensityPoint~new('0.25 W', .Units~q(2,.Units~candela)))
curve=.PowerIntensityCurve~new(points)

c=.Circuit~new
v=c~add(.DCVoltageSource~new('V1','10 V'))
vr=c~add(.VariableResistor~new('VR1','100 Ohm','900 Ohm',0))
lamp=c~add(.PhotometricLamp~new('L1','100 Ohm',curve,5,'2 W'))
c~connect('VCC',.array~of(v~positive,vr~pin('A')))
c~connect('LAMP',.array~of(vr~pin('B'),lamp~pin('A')))
c~connectGround(lamp~pin('B')); c~connectGround(v~negative)

do p over .array~of(0,0.25,0.5,0.75,1)
  vr~setPosition(p)
  c~solveDC
  say 'position='p 'lamp power='lamp~power~in(.Units~watt)'W' -
      'intensity='lamp~luminousIntensity~in(.Units~candela)'cd'
end

::requires 'RexxTronicsPhysical.cls'
