/* Rexx-tronics physical transducer boundary v0.1-dev15.
 *
 * This file contains electrical devices whose externally visible physical
 * behaviour is defined by evidence-backed transfer curves.  It does not
 * perform environmental propagation; Physics World remains authoritative
 * for geometry/material interaction.
 */

::class PowerIntensityPoint public
::attribute powerWatts get
::attribute intensityCandela get

::method init
  expose powerWatts intensityCandela
  numeric digits 50
  use strict arg powerArg, intensityArg
  powerWatts = .RexxTronicsUnits~canonical(powerArg, .Units~watt, 'lamp response electrical power')
  intensityCandela = .RexxTronicsUnits~canonical(intensityArg, .Units~candela, 'lamp response luminous intensity')
  if powerWatts < 0 then raise syntax 93.900 array('lamp response power must not be negative')
  if intensityCandela < 0 then raise syntax 93.900 array('lamp response luminous intensity must not be negative')

::method power
  expose powerWatts
  return .Units~q(powerWatts, .Units~watt)

::method intensity
  expose intensityCandela
  return .Units~q(intensityCandela, .Units~candela)


::class PowerIntensityCurve public
::attribute points get
::attribute belowRangePolicy get
::attribute aboveRangePolicy get

::method init
  expose points belowRangePolicy aboveRangePolicy
  use strict arg pointsArg, belowPolicy='ERROR', abovePolicy='ERROR'
  if pointsArg~items < 2 then raise syntax 93.900 array('power-intensity curve requires at least two points')
  points = .array~new
  previous = .nil
  do p over pointsArg
    if \p~isA(.PowerIntensityPoint) then raise syntax 93.900 array('power-intensity curve entries must be PowerIntensityPoint objects')
    if previous <> .nil then do
      if p~powerWatts <= previous then raise syntax 93.900 array('power-intensity curve powers must be strictly increasing')
    end
    points~append(p)
    previous = p~powerWatts
  end
  belowRangePolicy = self~validatePolicy(belowPolicy)
  aboveRangePolicy = self~validatePolicy(abovePolicy)

::method validatePolicy private
  use strict arg value
  p = value~string~upper
  if p <> 'ERROR' & p <> 'CLAMP' then raise syntax 93.900 array('response-curve range policy must be ERROR or CLAMP')
  return p

::method intensityCandelaFor
  expose points belowRangePolicy aboveRangePolicy
  numeric digits 50
  use strict arg powerArg
  x = .RexxTronicsUnits~canonical(powerArg, .Units~watt, 'lamp electrical power')
  if x < 0 then raise syntax 93.900 array('lamp power must not be negative')

  first = points[1]
  last = points[points~items]
  if x < first~powerWatts then do
    if belowRangePolicy = 'CLAMP' then return first~intensityCandela
    raise syntax 93.900 array('power below lamp photometric response curve')
  end
  if x > last~powerWatts then do
    if aboveRangePolicy = 'CLAMP' then return last~intensityCandela
    raise syntax 93.900 array('power above lamp photometric response curve')
  end

  if x = first~powerWatts then return first~intensityCandela
  do i = 2 to points~items
    high = points[i]
    low = points[i-1]
    if x = high~powerWatts then return high~intensityCandela
    if x < high~powerWatts then do
      fraction = (x - low~powerWatts) / (high~powerWatts - low~powerWatts)
      return low~intensityCandela + fraction * (high~intensityCandela - low~intensityCandela)
    end
  end
  return last~intensityCandela

::method intensityFor
  use strict arg powerArg
  return .Units~q(self~intensityCandelaFor(powerArg), .Units~candela)


/* Quasi-static electrical-to-photometric lamp model.
 *
 * Electrical behaviour is an ordinary resistor.  Luminous intensity is
 * derived only from the supplied evidence curve and the solver's accepted
 * electrical power.  Thermal warm-up/cool-down is intentionally not invented;
 * a future thermal Physics coupling may provide a dynamic transducer model.
 */
::class PhotometricLamp subclass Resistor public
::attribute photometricCurve get

::method init
  expose photometricCurve
  use strict arg idArg, resistanceArg, curveArg, toleranceArg=5, powerRatingArg='1 W'
  if \curveArg~isA(.PowerIntensityCurve) then raise syntax 93.900 array('photometric lamp requires a PowerIntensityCurve')
  photometricCurve = curveArg
  self~init:super(idArg, resistanceArg, toleranceArg, powerRatingArg, 'PHOTOMETRIC_LAMP')

::method luminousIntensity
  expose photometricCurve
  return photometricCurve~intensityFor(self~power)

::method luminousIntensityCandela
  expose photometricCurve
  return photometricCurve~intensityCandelaFor(self~power)

::requires 'RexxTronicsDC.cls'
