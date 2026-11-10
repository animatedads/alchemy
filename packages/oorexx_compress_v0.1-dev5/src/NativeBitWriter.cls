/* Pure ooRexx LSB-first bit writer used by DEFLATE. */
::class NativeBitWriter public
::method init
  expose out buffer bitCount
  out = ''
  buffer = 0
  bitCount = 0

::method writeBits
  expose out buffer bitCount
  use strict arg value, count
  numeric digits 50
  if count < 0 then raise syntax 88.900 array('Negative bit count')
  do while count > 0
    bit = value // 2
    value = value % 2
    if bit \== 0 then buffer = buffer + (2 ** bitCount)
    bitCount += 1
    if bitCount >= 8 then do
      out ||= d2c(buffer // 256, 1)
      buffer = buffer % 256
      bitCount -= 8
    end
    count -= 1
  end
  return self

::method finish
  expose out buffer bitCount
  if bitCount > 0 then do
    out ||= d2c(buffer // 256, 1)
    buffer = 0
    bitCount = 0
  end
  return out
