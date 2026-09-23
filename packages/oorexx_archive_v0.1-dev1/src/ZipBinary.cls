/*----------------------------------------------------------------------------*/
/* Little-endian binary helpers for ZIP.                                      */
/*----------------------------------------------------------------------------*/
::class ZipBinary public

::method le16 class
  use strict arg bytes, pos
  self~requireRange(bytes, pos, 2)
  return c2d(reverse(substr(bytes, pos, 2)))

::method le32 class
  use strict arg bytes, pos
  numeric digits 50
  self~requireRange(bytes, pos, 4)
  return c2d(reverse(substr(bytes, pos, 4)))

::method put16 class
  use strict arg value
  if value < 0 | value > 65535 then raise syntax 88.900 array('ZIP uint16 out of range: ' || value)
  return reverse(d2c(value, 2))

::method put32 class
  use strict arg value
  numeric digits 50
  if value < 0 | value > 4294967295 then raise syntax 88.900 array('ZIP uint32 out of range: ' || value)
  return reverse(d2c(value, 4))

::method requireRange class
  use strict arg bytes, pos, count
  if pos < 1 | count < 0 | pos + count - 1 > length(bytes) then -
    raise syntax 88.900 array('Truncated ZIP structure at byte ' || pos || ' length ' || count)
  return
