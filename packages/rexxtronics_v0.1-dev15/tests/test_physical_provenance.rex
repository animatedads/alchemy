/* Qualification: physical-world provenance survives the observation->sensor
 * boundary and remains queryable after the electrical state changes.
 */
numeric digits 50
failures = 0

points = .array~new
points~append(.LightResistancePoint~new(.Units~q(0, .Units~lux), '1 Mohm'))
points~append(.LightResistancePoint~new(.Units~q(100, .Units~lux), '10 kohm'))
points~append(.LightResistancePoint~new(.Units~q(1000, .Units~lux), '1 kohm'))
curve = .LightResistanceCurve~new(points)
ldr = .PhotoResistor~new('LDR1', curve, .Units~q(100, .Units~lux))

evidence = .directory~new
evidence['path'] = 'lamp -> prism -> mirror -> sensor'
evidence['solver'] = 'PhysicsWorld'
obs = .IlluminanceObservation~new(.Units~q(1000, .Units~lux), '2 ms', 'optical path recomputed', 'PhysicsWorld', evidence)
ldr~applyObservation(obs)

call near ldr~resistance~in(.Units~kiloohm), 1, 'LDR electrical response'
if ldr~lastStimulusSource <> 'PhysicsWorld' then do
  say 'FAIL source provenance lost'
  failures += 1
end
if ldr~lastStimulusEvidence <> evidence then do
  say 'FAIL evidence object identity lost'
  failures += 1
end
if ldr~lastObservation <> obs then do
  say 'FAIL observation identity lost'
  failures += 1
end
if ldr~lastStimulusCause <> 'optical path recomputed' then do
  say 'FAIL cause provenance lost'
  failures += 1
end

if failures = 0 then do
  say 'REXX-TRONICS PHYSICAL PROVENANCE: OK'
  exit 0
end
say 'FAIL physical provenance failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.0000001' then do
    say 'FAIL:' label actual expected
    failures += 1
  end
  return

::requires 'RexxTronicsSensors.cls'
