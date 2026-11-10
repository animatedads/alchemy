/* Pure ooRexx reflected CRC32. Table-driven so bootstrap does not crawl. */
::class NativeCRC32 public

::method calculate
  use strict arg bytes
  table = self~makeTable
  crc = x2c('FFFFFFFF')
  zero = d2c(0, 1)
  do p = 1 to length(bytes)
    index = c2d(bitxor(substr(crc, 1, 1), substr(bytes, p, 1)))
    crc = bitxor(substr(crc, 2, 3) || zero, table[index + 1])
  end
  return bitxor(crc, x2c('FFFFFFFF'))

::method makeTable private
  table = .array~new(256)
  poly = x2c('2083B8ED')  /* 0xEDB88320 represented least-significant byte first. */
  do index = 0 to 255
    crc = d2c(index, 1) || x2c('000000')
    do 8
      low = c2d(substr(crc, 1, 1)) // 2
      crc = self~shiftRightOne(crc)
      if low \== 0 then crc = bitxor(crc, poly)
    end
    table[index + 1] = crc
  end
  return table

::method shiftRightOne private
  use strict arg s
  b0 = c2d(substr(s, 1, 1)); b1 = c2d(substr(s, 2, 1))
  b2 = c2d(substr(s, 3, 1)); b3 = c2d(substr(s, 4, 1))
  n0 = (b0 % 2) + ((b1 // 2) * 128)
  n1 = (b1 % 2) + ((b2 // 2) * 128)
  n2 = (b2 % 2) + ((b3 // 2) * 128)
  n3 = (b3 % 2)
  return d2c(n0, 1) || d2c(n1, 1) || d2c(n2, 1) || d2c(n3, 1)
