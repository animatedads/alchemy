::class Dual public
::method init
  use strict arg value=0
  return "instance:" || value

::method init class
  use strict arg value=0
  return "class:" || value
