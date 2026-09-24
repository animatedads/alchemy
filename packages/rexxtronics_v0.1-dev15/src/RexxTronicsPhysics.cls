/* Rexx-tronics <-> ooRexx Physics World optical adapter v0.1-dev15.
 *
 * Optional peer integration.  Rexx-tronics owns electrical state and sensor
 * transfer characteristics.  Physics World owns geometry, optical media,
 * reflection/refraction/occlusion and photometry.
 *
 * This adapter intentionally consumes Physics' public OpticalBeamProbe and
 * Photometry surfaces.  It does not duplicate ray tracing.
 */

::class PhysicsIlluminanceEvidence public
::attribute reading get
::attribute sourceIntensityCandela get
::attribute baselineIlluminanceLux get
::attribute transmissionValue get
::attribute receivedIlluminanceLux get
::attribute distanceMetres get
::attribute sensorWidthMetres get
::attribute sensorHeightMetres get
::attribute wavelengthNm get

::method init
  expose reading sourceIntensityCandela baselineIlluminanceLux transmissionValue receivedIlluminanceLux distanceMetres sensorWidthMetres sensorHeightMetres wavelengthNm
  numeric digits 50
  use strict arg readingArg, intensityArg, baselineArg, transmissionArg, receivedArg, distanceArg, widthArg, heightArg, wavelengthArg
  reading = readingArg
  sourceIntensityCandela = intensityArg + 0
  baselineIlluminanceLux = baselineArg + 0
  transmissionValue = transmissionArg + 0
  receivedIlluminanceLux = receivedArg + 0
  distanceMetres = distanceArg + 0
  sensorWidthMetres = widthArg + 0
  sensorHeightMetres = heightArg + 0
  wavelengthNm = wavelengthArg + 0

::method sourceIntensity
  expose sourceIntensityCandela
  return .Units~q(sourceIntensityCandela, .Units~candela)

::method baselineIlluminance
  expose baselineIlluminanceLux
  return .Units~q(baselineIlluminanceLux, .Units~lux)

::method transmission
  expose transmissionValue
  return .Units~q(transmissionValue, .Units~one)

::method receivedIlluminance
  expose receivedIlluminanceLux
  return .Units~q(receivedIlluminanceLux, .Units~lux)

::method distance
  expose distanceMetres
  return .Units~q(distanceMetres, .Units~metre)

::method sensorWidth
  expose sensorWidthMetres
  return .Units~q(sensorWidthMetres, .Units~metre)

::method sensorHeight
  expose sensorHeightMetres
  return .Units~q(sensorHeightMetres, .Units~metre)


/* Converts one Physics OpticalBeamProbe sample into a typed Rexx-tronics
 * illuminance observation.
 *
 * The Physics probe supplies geometric/material transmission for the central
 * source-to-sensor ray.  Physics Photometry supplies the exact rectangular
 * solid-angle baseline for an isotropic point source.  Their product is the
 * accepted illuminance for this adapter.
 *
 * This is deliberately not claimed to be an aperture-integrated multi-ray or
 * spectral radiometric solver.  A richer Physics source model can later emit
 * IlluminanceObservation directly without changing PhotoResistor.
 */
::class PhysicsBeamIlluminanceAdapter public
::attribute probe get
::attribute intensitySource get
::attribute name get

::method init
  expose probe intensitySource name
  use strict arg probeArg, intensitySourceArg, nameArg='PhysicsBeamIlluminanceAdapter'
  probe = probeArg
  intensitySource = intensitySourceArg
  name = nameArg~string

::method currentIntensity
  expose intensitySource
  if intensitySource~hasMethod('LUMINOUSINTENSITY') then return intensitySource~luminousIntensity
  return .RexxTronicsUnits~typed(intensitySource, .Units~candela, 'Physics optical source luminous intensity')

::method sample
  expose probe intensitySource name
  numeric digits 50
  use strict arg timeArg=.nil, causeArg=.nil

  intensity = self~currentIntensity
  cd = intensity~in(.Units~candela)

  reading = probe~sample
  sourcePoint = reading~sourcePoint
  targetPoint = reading~targetPoint
  distance = (targetPoint - sourcePoint)~norm
  if distance <= 0 then raise syntax 93.900 array('Physics optical source and sensor must have non-zero separation')

  shape = probe~sensor~shape
  if \shape~hasMethod('WIDTH') | \shape~hasMethod('HEIGHT') then -
      raise syntax 93.900 array('PhysicsBeamIlluminanceAdapter requires a rectangular Physics sensor shape')
  width = shape~width
  height = shape~height

  baseline = .Photometry~isotropicRectangleAverageIlluminance(cd, width, height, distance)
  transmission = reading~transmission
  if transmission < 0 | transmission > 1 then -
      raise syntax 93.900 array('Physics optical transmission must be within 0..1')
  received = baseline * transmission

  evidence = .PhysicsIlluminanceEvidence~new(reading, cd, baseline, transmission, received, distance, width, height, probe~wavelengthNm)
  if causeArg == .nil then cause = 'Physics optical propagation'
  else cause = causeArg
  return .IlluminanceObservation~new(.Units~q(received, .Units~lux), timeArg, cause, intensitySource, evidence)

::method sampleAndApply
  use strict arg photoResistor, timeArg=.nil, causeArg=.nil
  observation = self~sample(timeArg, causeArg)
  photoResistor~applyObservation(observation)
  return observation

::method applyAt
  use strict arg photoResistor, when, causeArg=.nil
  return self~sampleAndApply(photoResistor, when, causeArg)

::method scheduleSample
  numeric digits 50
  use strict arg clock, when, photoResistor, causeArg=.nil
  atPs = .RexxTronicsUnits~timePicoseconds(when)
  instant = .SimInstant~new(atPs)
  args = .array~of(photoResistor, instant, causeArg)
  return clock~scheduleAt(instant, self, 'APPLYAT', args, causeArg)

::requires 'RexxTronicsPhysical.cls'
::requires 'RexxTronicsSensors.cls'
::requires 'Coupling.cls'
