o = .Victim~new
return o~locked("abc")

::class Victim public
::method locked public protected
  use strict arg x
  return "body:" || x
