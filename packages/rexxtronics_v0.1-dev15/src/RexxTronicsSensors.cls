/* Rexx-tronics environmental sensor boundary v0.1-dev15.
 *
 * Environmental propagation remains outside Rexx-tronics.  Physics (or a
 * capture/replay source) supplies a typed observation at a simulation-time
 * coordinate.  Sensor transfer characteristics convert that physical input
 * into ordinary electrical component state.
 *
 * This first boundary is deliberately data-driven: PhotoResistor does not
 * invent a universal CdS law.  It requires an explicit resistance-vs-lux
 * response curve, suitable for one-time construction from a part datasheet.
 */

::class LightResistancePoint public
::attribute illuminanceLux get
::attribute resistanceOhms get

::method init
  expose illuminanceLux resistanceOhms
  numeric digits 50
  use strict arg illuminanceArg, resistanceArg
  illuminanceLux = .RexxTronicsUnits~canonical(illuminanceArg, .Units~lux, 'light-response illuminance')
  resistanceOhms = .RexxTronicsUnits~canonical(resistanceArg, .Units~ohm, 'light-response resistance')
  if illuminanceLux < 0 then raise syntax 93.900 array('illuminance must not be negative')
  if resistanceOhms <= 0 then raise syntax 93.900 array('photoresistor response resistance must be positive')

::method illuminance
  expose illuminanceLux
  return .Units~q(illuminanceLux, .Units~lux)

::method resistance
  expose resistanceOhms
  return .Units~q(resistanceOhms, .Units~ohm)


::class LightResistanceCurve public
::attribute points get
::attribute belowRangePolicy get
::attribute aboveRangePolicy get

::method init
  expose points belowRangePolicy aboveRangePolicy
  use strict arg pointsArg, belowPolicy='ERROR', abovePolicy='ERROR'
  if pointsArg~items < 2 then raise syntax 93.900 array('light-resistance curve requires at least two points')
  points = .array~new
  previous = .nil
  do p over pointsArg
    if \p~isA(.LightResistancePoint) then raise syntax 93.900 array('light-resistance curve entries must be LightResistancePoint objects')
    if previous <> .nil then do
      if p~illuminanceLux <= previous then raise syntax 93.900 array('light-resistance curve illuminance values must be strictly increasing')
    end
    points~append(p)
    previous = p~illuminanceLux
  end
  belowRangePolicy = self~validatePolicy(belowPolicy)
  aboveRangePolicy = self~validatePolicy(abovePolicy)

::method validatePolicy private
  use strict arg value
  p = value~string~upper
  if p <> 'ERROR' & p <> 'CLAMP' then raise syntax 93.900 array('response-curve range policy must be ERROR or CLAMP')
  return p

::method minimumIlluminance
  expose points
  return points[1]~illuminance

::method maximumIlluminance
  expose points
  return points[points~items]~illuminance

::method resistanceOhmsFor
  expose points belowRangePolicy aboveRangePolicy
  numeric digits 50
  use strict arg illuminanceArg
  x = .RexxTronicsUnits~canonical(illuminanceArg, .Units~lux, 'photoresistor illuminance')
  if x < 0 then raise syntax 93.900 array('illuminance must not be negative')

  first = points[1]
  last = points[points~items]
  if x < first~illuminanceLux then do
    if belowRangePolicy = 'CLAMP' then return first~resistanceOhms
    raise syntax 93.900 array('illuminance below photoresistor response curve')
  end
  if x > last~illuminanceLux then do
    if aboveRangePolicy = 'CLAMP' then return last~resistanceOhms
    raise syntax 93.900 array('illuminance above photoresistor response curve')
  end

  if x = first~illuminanceLux then return first~resistanceOhms
  do i = 2 to points~items
    high = points[i]
    low = points[i-1]
    if x = high~illuminanceLux then return high~resistanceOhms
    if x < high~illuminanceLux then do
      fraction = (x - low~illuminanceLux) / (high~illuminanceLux - low~illuminanceLux)
      return low~resistanceOhms + fraction * (high~resistanceOhms - low~resistanceOhms)
    end
  end
  return last~resistanceOhms

::method resistanceFor
  use strict arg illuminanceArg
  return .Units~q(self~resistanceOhmsFor(illuminanceArg), .Units~ohm)


::class IlluminanceObservation public
::attribute illuminanceLux get
::attribute timePs get
::attribute cause get
::attribute source get
::attribute evidence get

::method init
  expose illuminanceLux timePs cause source evidence
  numeric digits 50
  use strict arg illuminanceArg, timeArg=.nil, causeArg=.nil, sourceArg=.nil, evidenceArg=.nil
  illuminanceLux = .RexxTronicsUnits~canonical(illuminanceArg, .Units~lux, 'illuminance observation')
  if illuminanceLux < 0 then raise syntax 93.900 array('illuminance must not be negative')
  if timeArg == .nil then timePs = .nil
  else timePs = .RexxTronicsUnits~timePicoseconds(timeArg)
  cause = causeArg
  source = sourceArg
  evidence = evidenceArg

::method illuminance
  expose illuminanceLux
  return .Units~q(illuminanceLux, .Units~lux)

::method time
  expose timePs
  if timePs == .nil then return .nil
  return .Units~q(timePs / .SimTime~PS_PER_S, .Units~second)


::class PhotoResistor subclass Resistor public
::attribute responseCurve get
::attribute lastIlluminanceLux get
::attribute lastStimulusTimePs get
::attribute lastStimulusCause get
::attribute lastStimulusSource get
::attribute lastStimulusEvidence get
::attribute lastObservation get

::method init
  expose responseCurve lastIlluminanceLux lastStimulusTimePs lastStimulusCause lastStimulusSource lastStimulusEvidence lastObservation
  use strict arg idArg, responseCurveArg, initialIlluminanceArg, toleranceArg=20, powerRatingArg='0.25 W'
  if \responseCurveArg~isA(.LightResistanceCurve) then raise syntax 93.900 array('photoresistor requires a LightResistanceCurve')
  responseCurve = responseCurveArg
  lastIlluminanceLux = .RexxTronicsUnits~canonical(initialIlluminanceArg, .Units~lux, 'initial photoresistor illuminance')
  initialResistance = responseCurve~resistanceOhmsFor(lastIlluminanceLux)
  self~init:super(idArg, initialResistance, toleranceArg, powerRatingArg, 'PHOTORESISTOR')
  lastStimulusTimePs = .nil
  lastStimulusCause = .nil
  lastStimulusSource = .nil
  lastStimulusEvidence = .nil
  lastObservation = .nil

::method illuminance
  expose lastIlluminanceLux
  return .Units~q(lastIlluminanceLux, .Units~lux)

::method lastStimulusTime
  expose lastStimulusTimePs
  if lastStimulusTimePs == .nil then return .nil
  return .Units~q(lastStimulusTimePs / .SimTime~PS_PER_S, .Units~second)

::method applyIlluminance
  expose responseCurve lastIlluminanceLux lastStimulusTimePs lastStimulusCause lastStimulusSource lastStimulusEvidence lastObservation
  numeric digits 50
  use strict arg illuminanceArg, timeArg=.nil, causeArg=.nil, sourceArg=.nil, evidenceArg=.nil
  lux = .RexxTronicsUnits~canonical(illuminanceArg, .Units~lux, 'photoresistor illuminance')
  resistance = responseCurve~resistanceOhmsFor(lux)
  self~setResistanceOhms(resistance)
  lastIlluminanceLux = lux
  if timeArg == .nil then lastStimulusTimePs = .nil
  else lastStimulusTimePs = .RexxTronicsUnits~timePicoseconds(timeArg)
  lastStimulusCause = causeArg
  lastStimulusSource = sourceArg
  lastStimulusEvidence = evidenceArg
  lastObservation = .nil
  return self

::method applyObservation
  expose lastObservation
  use strict arg observation
  if \observation~hasMethod('ILLUMINANCE') then raise syntax 93.900 array('photoresistor observation must provide illuminance')
  time = .nil
  cause = .nil
  source = .nil
  evidence = .nil
  if observation~hasMethod('TIME') then time = observation~time
  if observation~hasMethod('CAUSE') then cause = observation~cause
  if observation~hasMethod('SOURCE') then source = observation~source
  if observation~hasMethod('EVIDENCE') then evidence = observation~evidence
  self~applyIlluminance(observation~illuminance, time, cause, source, evidence)
  lastObservation = observation
  return self

::method scheduleIlluminance
  numeric digits 50
  use strict arg clock, when, illuminanceArg, causeArg=.nil
  atPs = .RexxTronicsUnits~timePicoseconds(when)
  args = .array~of(illuminanceArg, .SimInstant~new(atPs), causeArg)
  return clock~scheduleAt(.SimInstant~new(atPs), self, 'APPLYILLUMINANCE', args, causeArg)

::requires 'RexxTronicsDC.cls'
::requires 'RexxTronicsTime.cls'
