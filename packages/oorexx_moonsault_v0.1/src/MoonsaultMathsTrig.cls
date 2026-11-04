/* Plug-in for Alchemy's existing oorexx_maths library. No trig fork. */
::class MoonsaultMathsTrig public
::method sinDeg class
  use strict arg degrees
  return .Maths~angleDegrees(degrees)~sin
::method cosDeg class
  use strict arg degrees
  return .Maths~angleDegrees(degrees)~cos
::method tanDeg class
  use strict arg degrees
  return .Maths~angleDegrees(degrees)~tan
::requires 'Maths.cls'
