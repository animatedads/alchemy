/*----------------------------------------------------------------------------*/
/* ZstdForwardBitReader.cls -- forward little-endian bit reader for FSE tables.*/
/*----------------------------------------------------------------------------*/
::class ZstdForwardBitReader public

::method init
  expose bytes bitPos
  use strict arg bytes
  bitPos = 0

::method bitsConsumed
  expose bitPos
  return bitPos

::method bytesConsumed
  expose bitPos
  return (bitPos + 7) % 8

::method bitsRemaining
  expose bytes bitPos
  return length(bytes) * 8 - bitPos

::method readBits
  use strict arg count
  value = self~peekBits(count)
  self~skipBits(count)
  return value

::method peekBits
  expose bytes bitPos
  use strict arg count
  if count < 0 then raise syntax 88.900 array('Negative Zstandard forward-bit read')
  if count = 0 then return 0
  if bitPos + count > length(bytes)*8 then raise syntax 88.900 array('Zstandard forward bitstream underflow')
  value = 0
  multiplier = 1
  do absolute = bitPos to bitPos + count - 1
    byteIndex = absolute % 8 + 1
    bitIndex = absolute // 8
    b = c2d(substr(bytes,byteIndex,1))
    bit = (b % (2 ** bitIndex)) // 2
    if bit = 1 then value += multiplier
    multiplier *= 2
  end
  return value

::method skipBits
  expose bytes bitPos
  use strict arg count
  if count < 0 | bitPos + count > length(bytes)*8 then raise syntax 88.900 array('Invalid Zstandard forward-bit skip')
  bitPos += count
