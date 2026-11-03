/*----------------------------------------------------------------------------*/
/* NativeXXH64.cls -- pure ooRexx XXH64, seed-capable.                        */
/* Used by the Zstandard frame checksum. No foreign/process dependency.        */
/*----------------------------------------------------------------------------*/
::class NativeXXH64 public

::method calculate
  use strict arg bytes, seed = 0
  numeric digits 80
  p1 = 11400714785074694791
  p2 = 14029467366897019727
  p3 = 1609587929392839161
  p4 = 9650029242287828579
  p5 = 2870177450012600261
  n = length(bytes)
  pos = 1
  seed = self~u64(seed)

  if n >= 32 then do
    v1 = self~u64(seed + p1 + p2)
    v2 = self~u64(seed + p2)
    v3 = seed
    v4 = self~u64(seed - p1)
    limit = n - 31
    do while pos <= limit
      v1 = self~round(v1, self~le64At(bytes, pos)); pos += 8
      v2 = self~round(v2, self~le64At(bytes, pos)); pos += 8
      v3 = self~round(v3, self~le64At(bytes, pos)); pos += 8
      v4 = self~round(v4, self~le64At(bytes, pos)); pos += 8
    end
    h = self~u64(self~rotl(v1,1) + self~rotl(v2,7) + self~rotl(v3,12) + self~rotl(v4,18))
    h = self~mergeRound(h, v1)
    h = self~mergeRound(h, v2)
    h = self~mergeRound(h, v3)
    h = self~mergeRound(h, v4)
  end
  else h = self~u64(seed + p5)

  h = self~u64(h + n)

  do while pos + 7 <= n
    k1 = self~round(0, self~le64At(bytes, pos))
    h = self~xor64(h, k1)
    h = self~u64(self~rotl(h,27) * p1 + p4)
    pos += 8
  end

  if pos + 3 <= n then do
    h = self~xor64(h, self~u64(self~le32At(bytes, pos) * p1))
    h = self~u64(self~rotl(h,23) * p2 + p3)
    pos += 4
  end

  do while pos <= n
    h = self~xor64(h, self~u64(self~byteAt(bytes,pos) * p5))
    h = self~u64(self~rotl(h,11) * p1)
    pos += 1
  end

  h = self~xor64(h, h % (2**33))
  h = self~u64(h * p2)
  h = self~xor64(h, h % (2**29))
  h = self~u64(h * p3)
  h = self~xor64(h, h % (2**32))
  return self~u64(h)

::method round private
  use strict arg acc, lane
  numeric digits 80
  p1 = 11400714785074694791
  p2 = 14029467366897019727
  acc = self~u64(acc + self~u64(lane * p2))
  acc = self~rotl(acc,31)
  return self~u64(acc * p1)

::method mergeRound private
  use strict arg acc, value
  numeric digits 80
  p1 = 11400714785074694791
  p4 = 9650029242287828579
  acc = self~xor64(acc, self~round(0,value))
  return self~u64(acc * p1 + p4)

::method rotl private
  use strict arg value, count
  numeric digits 80
  value = self~u64(value)
  count = count // 64
  if count = 0 then return value
  low = self~u64(value * (2**count))
  high = value % (2**(64-count))
  return self~u64(low + high)

::method xor64 private
  use strict arg a, b
  numeric digits 80
  return c2d(bitxor(d2c(self~u64(a),8), d2c(self~u64(b),8)))

::method u64 private
  use strict arg value
  numeric digits 80
  modulus = 18446744073709551616
  value = value // modulus
  if value < 0 then value += modulus
  return value

::method le64At private
  use strict arg bytes, pos
  numeric digits 80
  if pos < 1 | pos + 7 > length(bytes) then raise syntax 88.900 array('XXH64 out-of-range 64-bit read')
  return c2d(reverse(substr(bytes,pos,8)))

::method le32At private
  use strict arg bytes, pos
  numeric digits 80
  if pos < 1 | pos + 3 > length(bytes) then raise syntax 88.900 array('XXH64 out-of-range 32-bit read')
  return c2d(reverse(substr(bytes,pos,4)))

::method byteAt private
  use strict arg bytes, pos
  if pos < 1 | pos > length(bytes) then raise syntax 88.900 array('XXH64 out-of-range byte read')
  return c2d(substr(bytes,pos,1))
