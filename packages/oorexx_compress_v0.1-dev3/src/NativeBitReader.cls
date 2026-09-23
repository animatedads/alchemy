/* Pure ooRexx LSB-first bit reader used by DEFLATE. */
::class NativeBitReader public
::method init
  expose data position buffer bitCount
  use strict arg data
  position = 1
  buffer = 0
  bitCount = 0

::method readBits
  expose data position buffer bitCount
  use strict arg count
  numeric digits 50
  if count < 0 then raise syntax 88.900 array('Negative bit count')
  value = 0
  multiplier = 1
  do while count > 0
    if bitCount = 0 then do
      if position > length(data) then raise syntax 88.900 array('Unexpected end of compressed bit stream')
      buffer = c2d(substr(data, position, 1))
      position += 1
      bitCount = 8
    end
    bit = buffer // 2
    buffer = buffer % 2
    bitCount -= 1
    if bit \== 0 then value += multiplier
    multiplier *= 2
    count -= 1
  end
  return value

::method alignByte
  expose buffer bitCount
  buffer = 0
  bitCount = 0
  return self

::attribute position
::attribute data get
