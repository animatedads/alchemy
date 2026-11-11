/* Aircraft acoustic geometry. Inputs are local Cartesian metres (ENU or ECEF
   differences in the same reference frame), UTC seconds, m/s, and Hz.
   No claim of measured microphone position or calibrated atmosphere. */
::class AcousticFlyoverPhysics public

::method slantRange class
  use strict arg dx, dy, dz
  numeric digits 16
  sumsq = dx*dx + dy*dy + dz*dz
  if sumsq = 0 then return 0
  guess = sumsq/2
  if guess < 1 then guess = 1
  do 40
    newer = (guess + sumsq/guess)/2
    if abs(newer-guess) < 0.000000000001 then leave
    guess = newer
  end
  return newer

::method rangeRate class
  numeric digits 16
  use strict arg dx, dy, dz, vx, vy, vz
  rr = self~slantRange(dx, dy, dz)
  if rr <= 0 then raise syntax 88.900 array('non-zero range required')
  return (dx*vx + dy*vy + dz*vz)/rr

::method arrivalUtc class
  numeric digits 16
  use strict arg emissionUtc, slantMetres, soundSpeed=343
  if slantMetres < 0 | soundSpeed <= 0 then raise syntax 88.900 array('invalid acoustic propagation parameters')
  return emissionUtc + slantMetres/soundSpeed

::method observedFrequency class
  numeric digits 16
  use strict arg emittedHz, emissionRangeRate, soundSpeed=343
  if emittedHz <= 0 | soundSpeed <= 0 then raise syntax 88.900 array('positive frequency and sound speed required')
  denominator = 1 + emissionRangeRate/soundSpeed
  if denominator <= 0 then raise syntax 88.900 array('invalid/subsonic one-path acoustic state')
  return emittedHz/denominator
