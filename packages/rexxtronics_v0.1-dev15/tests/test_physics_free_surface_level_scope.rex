/* Physics dev10.1 2-D free surface -> calibrated electrical level sensors -> scope.
 *
 * Physics owns the liquid surface.  The sensor calibration is deliberately
 * generic qualification data, not a claim about a particular production part.
 */
numeric digits 50
failures = 0

water = .FluidMedium~water20C
tank = .RectangularTankGeometry2D~new(.Units~q(0.6,.Units~metre), .Units~q(0.4,.Units~metre), .Units~q(0.3,.Units~metre), 12, 8)
slosh = .RectangularTankSlosh2D~new(water, tank, .Units~q(0.036, .Units~cubicMetre), .Units~q(0.04, .Units~hertz))

/* Opposite corners make the two-axis diagonal forcing visible electrically. */
probeA = .PhysicsFreeSurfaceDepthProbe2D~new(slosh, 1, 8, 'near-left corner')
probeB = .PhysicsFreeSurfaceDepthProbe2D~new(slosh, 12, 1, 'far-right corner')

levelA = .LinearLiquidLevelTransducer~new('LEVEL_A_SENSOR', '5 cm', '25 cm', '0 V', '5 V')
levelB = .LinearLiquidLevelTransducer~new('LEVEL_B_SENSOR', '5 cm', '25 cm', '0 V', '5 V')

c = .Circuit~new
c~add(levelA); c~add(levelB)
loadA = c~add(.Resistor~new('LOAD_A', '10 kohm'))
loadB = c~add(.Resistor~new('LOAD_B', '10 kohm'))
c~connect('LEVEL_A', .array~of(levelA~output, loadA~pin('A')))
c~connect('LEVEL_B', .array~of(levelB~output, loadB~pin('A')))
c~connectGround(levelA~reference)
c~connectGround(levelB~reference)
c~connectGround(loadA~pin('B'))
c~connectGround(loadB~pin('B'))

clock = .SimulationClock~new
coupler = .FreeSurfaceElectricalCoupler2D~new(slosh, c, clock, '1.5 ms')
coupler~addBinding(.FreeSurfaceDepthSensorBinding~new(probeA, levelA))
coupler~addBinding(.FreeSurfaceDepthSensorBinding~new(probeB, levelB))
initial = coupler~begin

call near initial~voltage('LEVEL_A'), 2.5, 'initial A output', '0.000000001'
call near initial~voltage('LEVEL_B'), 2.5, 'initial B output', '0.000000001'

/* Diagonal effective gravity exactly matches the authoritative Physics dev10.1
 * forcing fixture direction, but here the resolved free surface becomes an
 * electrical instrument signal. */
do n = 1 to 60
  last = coupler~step(.Units~q(-2.5, .Units~metrePerSecondSquared), .Units~q(1.5, .Units~metrePerSecondSquared))
end

if clock~now~milliseconds <> 90 then do
  say 'FAIL shared clock did not reach 90 ms:' clock~now~milliseconds
  failures += 1
end
call near slosh~time, 0.09, 'Physics time alignment', '0.000000000001'

expectedDepthA = slosh~depthAtCell(1, 8)
expectedDepthB = slosh~depthAtCell(12, 1)
call near levelA~lastDepth~in(.Units~metre), expectedDepthA, 'A physical depth retained', '0.000000000001'
call near levelB~lastDepth~in(.Units~metre), expectedDepthB, 'B physical depth retained', '0.000000000001'

expectedVA = levelA~voltageForDepth(.Units~q(expectedDepthA, .Units~metre))
expectedVB = levelB~voltageForDepth(.Units~q(expectedDepthB, .Units~metre))
call near last~electricalSolution~voltage('LEVEL_A'), expectedVA, 'A final electrical output', '0.000001'
call near last~electricalSolution~voltage('LEVEL_B'), expectedVB, 'B final electrical output', '0.000001'

if expectedVA <= expectedVB then do
  say 'FAIL diagonal slosh did not separate corner sensor outputs'
  failures += 1
end

run = coupler~result
scope = .VirtualOscilloscope~new
traceA = scope~acquireSignal(run~signal('LEVEL_A'), '0 ms', '90 ms', '500 Hz')
traceB = scope~acquireSignal(run~signal('LEVEL_B'), '0 ms', '90 ms', '500 Hz')
call near traceA~samples[1]~voltage, 2.5, 'scope A initial', '0.000000001'
call near traceB~samples[1]~voltage, 2.5, 'scope B initial', '0.000000001'
call near traceA~samples[traceA~samples~items]~voltage, expectedVA, 'scope A final', '0.00001'
call near traceB~samples[traceB~samples~items]~voltage, expectedVB, 'scope B final', '0.00001'

if probeA~lastObservation~evidence == .nil | probeB~lastObservation~evidence == .nil then do
  say 'FAIL free-surface observations lost Physics snapshot evidence'
  failures += 1
end

if failures = 0 then do
  say 'REXX-TRONICS / PHYSICS 2-D SLOSH LEVEL SCOPE: OK'
  say 'time:' slosh~time 's'
  say 'A depth:' expectedDepthA 'm output:' expectedVA 'V'
  say 'B depth:' expectedDepthB 'm output:' expectedVB 'V'
  say 'surface range:' slosh~surfaceRange 'm'
  say 'scope A min/max:' traceA~minVoltage traceA~maxVoltage 'V'
  say 'scope B min/max:' traceB~minVoltage traceB~maxVoltage 'V'
  exit 0
end
say 'FAIL 2-D slosh/electrical failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label, tolerance='0.000001'
  if abs(actual - expected) > tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

::requires 'RexxTronicsFluids.cls'
::requires 'RexxTronicsDevices.cls'
