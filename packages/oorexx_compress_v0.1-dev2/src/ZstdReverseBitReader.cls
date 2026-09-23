/*----------------------------------------------------------------------------*/
/* ZstdReverseBitReader.cls -- reverse bitstream reader for Zstandard FSE/HUF.*/
/*----------------------------------------------------------------------------*/
::class ZstdReverseBitReader public

::method init
  expose bytes bitPos
  use strict arg bytes
  if length(bytes) = 0 then raise syntax 88.900 array('Empty Zstandard reverse bitstream')
  last = c2d(substr(bytes,length(bytes),1))
  if last = 0 then raise syntax 88.900 array('Zstandard reverse bitstream has zero final byte')

  marker = -1
  do p = 7 to 0 by -1
    if ((last % (2 ** p)) // 2) = 1 then do
      marker = p
      leave
    end
  end
  if marker < 0 then raise syntax 88.900 array('Missing Zstandard reverse bitstream end marker')
  /* bitPos is the absolute bit index of the marker, hence also the count of */
  /* useful bits preceding it. The marker itself and high zero padding vanish.*/
  bitPos = (length(bytes)-1) * 8 + marker

::method bitsRemaining
  expose bitPos
  return bitPos

::method exhausted
  expose bitPos
  return (bitPos = 0)

::method readBits
  expose bytes bitPos
  use strict arg count
  if count < 0 then raise syntax 88.900 array('Negative Zstandard reverse-bit read')
  if count = 0 then return 0
  if count > bitPos then raise syntax 88.900 array('Zstandard reverse bitstream underflow: need ' || count || ' bits, have ' || bitPos)

  start = bitPos - count
  value = 0
  multiplier = 1
  do absolute = start to bitPos - 1
    byteIndex = absolute % 8 + 1
    bitIndex = absolute // 8
    b = c2d(substr(bytes,byteIndex,1))
    bit = (b % (2 ** bitIndex)) // 2
    if bit = 1 then value += multiplier
    multiplier *= 2
  end
  bitPos = start
  return value


::method peekBits
  expose bytes bitPos
  use strict arg count
  if count < 0 then raise syntax 88.900 array('Negative Zstandard reverse-bit peek')
  if count = 0 then return 0
  if count > bitPos then raise syntax 88.900 array('Zstandard reverse bitstream underflow while peeking')
  saved = bitPos
  value = self~readBits(count)
  bitPos = saved
  return value

::method skipBits
  expose bitPos
  use strict arg count
  if count < 0 | count > bitPos then raise syntax 88.900 array('Invalid Zstandard reverse-bit skip')
  bitPos -= count

::method readBitsPadded
  expose bitPos
  use strict arg count
  if count < 0 then raise syntax 88.900 array('Negative Zstandard padded reverse-bit read')
  available = bitPos
  if available >= count then return self~readBits(count)
  if available = 0 then return 0
  /* Missing bits lie before the beginning of the reverse stream and are zero. */
  /* Existing bits retain their numeric positions at the high end of the field.*/
  value = self~readBits(available)
  return value * (2 ** (count-available))
