/* A 2-D liquid free surface becomes two real electrical sensor channels. */
numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(.Units~q(.6,.Units~metre),.Units~q(.4,.Units~metre),.Units~q(.3,.Units~metre),12,8)
slosh=.RectangularTankSlosh2D~new(water,tank,.036,.04)

c=.Circuit~new
sensorA=c~add(.LinearLiquidLevelTransducer~new('LEVEL_A','5 cm','25 cm','0 V','5 V'))
sensorB=c~add(.LinearLiquidLevelTransducer~new('LEVEL_B','5 cm','25 cm','0 V','5 V'))
ra=c~add(.Resistor~new('RA','10 kohm')); rb=c~add(.Resistor~new('RB','10 kohm'))
c~connect('A',.array~of(sensorA~output,ra~pin('A')))
c~connect('B',.array~of(sensorB~output,rb~pin('A')))
c~connectGround(sensorA~reference); c~connectGround(sensorB~reference)
c~connectGround(ra~pin('B')); c~connectGround(rb~pin('B'))

clock=.SimulationClock~new
co=.FreeSurfaceElectricalCoupler2D~new(slosh,c,clock,'1.5 ms')
co~addBinding(.FreeSurfaceDepthSensorBinding~new(.PhysicsFreeSurfaceDepthProbe2D~new(slosh,1,8),sensorA))
co~addBinding(.FreeSurfaceDepthSensorBinding~new(.PhysicsFreeSurfaceDepthProbe2D~new(slosh,12,1),sensorB))
co~begin
do 60
  co~step(-2.5,1.5)
end
run=co~result
scope=.VirtualOscilloscope~new
A=scope~acquireSignal(run~signal('A'),'0 s','.09 s','500 Hz')
B=scope~acquireSignal(run~signal('B'),'0 s','.09 s','500 Hz')
say 'Physics time:' slosh~time 's'
say 'surface range:' slosh~surfaceRange 'm'
say 'channel A:' A~minVoltage 'to' A~maxVoltage 'V'
say 'channel B:' B~minVoltage 'to' B~maxVoltage 'V'
::requires 'RexxTronicsFluids.cls'
::requires 'RexxTronicsDevices.cls'
