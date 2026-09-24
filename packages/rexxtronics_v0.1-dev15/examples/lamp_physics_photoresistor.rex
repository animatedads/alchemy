/* Requires run-time REXX_PATH containing:
 *   Rexx-tronics src/
 *   Physics World dev4 rexx/
 *   Units rexx/
 *   Maths v0.8 rexx/
 */
numeric digits 50
lp=.array~new
lp~append(.PowerIntensityPoint~new('0 W',.Units~q(0,.Units~candela)))
lp~append(.PowerIntensityPoint~new('0.25 W',.Units~q(2,.Units~candela)))
lampCurve=.PowerIntensityCurve~new(lp)

c=.Circuit~new
v=c~add(.DCVoltageSource~new('V1','10 V'))
vr=c~add(.VariableResistor~new('VR1','100 Ohm','900 Ohm',0))
lamp=c~add(.PhotometricLamp~new('L1','100 Ohm',lampCurve,5,'2 W'))

rp=.array~new
rp~append(.LightResistancePoint~new(.Units~q(0,.Units~lux),'1 Mohm'))
rp~append(.LightResistancePoint~new(.Units~q(1000,.Units~lux),'10 kohm'))
rp~append(.LightResistancePoint~new(.Units~q(5000,.Units~lux),'1 kohm'))
ldr=c~add(.PhotoResistor~new('LDR1',.LightResistanceCurve~new(rp),.Units~q(1000,.Units~lux)))
sense=c~add(.Resistor~new('R_SENSE','10 kohm'))

c~connect('VCC',.array~of(v~positive,vr~pin('A'),sense~pin('A')))
c~connect('LAMP_RETURN',.array~of(vr~pin('B'),lamp~pin('A')))
c~connect('SENSE',.array~of(sense~pin('B'),ldr~pin('A')))
c~connectGround(lamp~pin('B')); c~connectGround(ldr~pin('B')); c~connectGround(v~negative)
c~solveDC

ctx=.MathContext~decimal(40)
world=.PhysicalWorld~new(.OpticalMedium~air)
sourcePose=.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx)
sensorPose=.PhysicalPose~new(.MathVector3~new(0,0,0.02,ctx),.nil,ctx)
probe=.OpticalBeamProbe~new(world,sourcePose,sensorPose,0.01,0.01,555,1,'LDR-aperture')
bridge=.PhysicsBeamIlluminanceAdapter~new(probe,lamp)

obs=bridge~sampleAndApply(ldr,'1 ms','lamp -> Physics -> photoresistor')
sol=c~solveDC
say 'lamp power:' lamp~power~in(.Units~watt) 'W'
say 'lamp intensity:' lamp~luminousIntensity~in(.Units~candela) 'cd'
say 'sensor illuminance:' obs~illuminance~in(.Units~lux) 'lx'
say 'LDR resistance:' ldr~resistance~in(.Units~kiloohm) 'kOhm'
say 'SENSE:' sol~voltageQuantity('SENSE')~in(.Units~volt) 'V'

::requires 'RexxTronicsPhysics.cls'
