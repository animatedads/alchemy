/* Precision-independent octal helpers and PDP-10 36-bit octal value algebra.
 *
 * Oct2Bin/Bin2Oct/Oct2Hex/Hex2Oct intentionally map character strings rather
 * than routing octal through decimal arithmetic.
 *
 * Oct("LH,,RH") returns an immutable .LROct object.  .LROct stores exactly
 * 36 bits as a binary string and overloads the ooRexx logical operators as
 * bitwise word operators:
 *
 *      &   bitwise AND
 *      |   bitwise OR
 *      &&  bitwise XOR
 *      \   bitwise NOT
 *      +   unsigned addition modulo 2**36
 *      -   unsigned subtraction modulo 2**36 / unary two's complement
 *
 * The class inherits Orderable so compareTo() supplies ooRexx comparison
 * operators.  Arithmetic here is word algebra only.  Carry, overflow, flags,
 * traps, etc.
 * remain CPU semantics and are deliberately not invented by this class.
 */

::routine Oct2Bin public
  use arg oct
  map = "000 001 010 011 100 101 110 111"
  if oct = "" then raise syntax 40.900 array("empty octal string")
  bin = ""
  do i = 1 to oct~length
    d = oct~substr(i, 1)
    ix = pos(d, "01234567")
    if ix = 0 then raise syntax 40.900 array("invalid octal digit:" d)
    bin = bin || word(map, ix)
  end
  return bin

::routine Bin2Oct public
  use arg bin
  map = "000 001 010 011 100 101 110 111"
  if bin = "" then raise syntax 40.900 array("empty binary string")
  do i = 1 to bin~length
    if pos(bin~substr(i, 1), "01") = 0 then
      raise syntax 40.900 array("invalid binary digit:" bin~substr(i, 1))
  end
  rem = bin~length // 3
  if rem \= 0 then bin = copies("0", 3 - rem) || bin
  oct = ""
  do i = 1 to bin~length by 3
    chunk = bin~substr(i, 3)
    ix = wordpos(chunk, map)
    if ix = 0 then raise syntax 40.900 array("invalid binary sequence:" chunk)
    oct = oct || substr("01234567", ix, 1)
  end
  return oct

::routine Oct2Hex public
  use arg oct
  return b2x(Oct2Bin(oct))

::routine Hex2Oct public
  use arg hex
  if hex = "" then raise syntax 40.900 array("empty hexadecimal string")
  return Bin2Oct(x2b(hex))

::routine Oct public
  use strict arg text
  if text~isa(.LROct) then return text
  return .LROct~new(text)

::routine Oct36 public
  use strict arg text
  return Oct(text)

::routine LROctFromDecimal public
  use strict arg value
  return .LROct~fromDecimal(value)


::class "LROct" public inherit Orderable

::method init
  expose bits
  use strict arg source

  if source~isa(.LROct) then do
    bits = source~bits
    return
  end

  text = space(source~string, 0)
  if text = "" then raise syntax 40.900 array("empty LROct value")

  comma = pos(",,", text)
  if comma > 0 then do
    if pos(",,", text, comma + 2) > 0 then
      raise syntax 40.900 array("invalid PDP-10 LH,,RH word:" text)
    lh = substr(text, 1, comma - 1)
    rh = substr(text, comma + 2)
    if lh = "" | rh = "" then
      raise syntax 40.900 array("invalid PDP-10 LH,,RH word:" text)
    if lh~length > 6 | rh~length > 6 then
      raise syntax 40.900 array("PDP-10 half exceeds 18 bits:" text)
    ignored = self~validateOctal(lh)
    ignored = self~validateOctal(rh)
    oct = right(lh, 6, "0") || right(rh, 6, "0")
  end
  else do
    if text~length > 12 then
      raise syntax 40.900 array("PDP-10 word exceeds 36 bits:" text)
    ignored = self~validateOctal(text)
    oct = right(text, 12, "0")
  end

  bits = Oct2Bin(oct)
  return

::method fromDecimal class
  use strict arg value
  numeric digits 30
  if \datatype(value, "W") then
    raise syntax 40.900 array("LROct decimal source must be a whole number:" value)
  value = value // (2 ** 36)
  if value < 0 then value = value + (2 ** 36)
  bin = x2b(d2x(value))
  bin = right(bin, 36, "0")
  if bin~length > 36 then bin = right(bin, 36)
  return self~new(Bin2Oct(bin))

::method fromBits class
  use strict arg valueBits
  if valueBits~length \= 36 then
    raise syntax 40.900 array("LROct bit string must contain exactly 36 bits")
  do i = 1 to 36
    if pos(valueBits~substr(i, 1), "01") = 0 then
      raise syntax 40.900 array("invalid LROct bit:" valueBits~substr(i, 1))
  end
  return self~new(Bin2Oct(valueBits))

::method bits
  expose bits
  return bits

::method compact
  expose bits
  return Bin2Oct(bits)

::method octal
  expose bits
  oct = Bin2Oct(bits)
  return oct~substr(1, 6) || ",," || oct~substr(7, 6)

::method string
  return self~octal

::method left
  expose bits
  return Bin2Oct(bits~substr(1, 18))

::method right
  expose bits
  return Bin2Oct(bits~substr(19, 18))

::method leftDecimal
  expose bits
  return self~binaryToDecimal(bits~substr(1, 18))

::method rightDecimal
  expose bits
  return self~binaryToDecimal(bits~substr(19, 18))

::method decimal
  expose bits
  return self~binaryToDecimal(bits)

::method '&'
  expose bits
  use strict arg other
  rhs = self~coerce(other)
  out = ""
  rb = rhs~bits
  do i = 1 to 36
    if bits~substr(i, 1) = "1" & rb~substr(i, 1) = "1" then out = out || "1"
    else out = out || "0"
  end
  return self~class~fromBits(out)

::method '|'
  expose bits
  use strict arg other
  rhs = self~coerce(other)
  out = ""
  rb = rhs~bits
  do i = 1 to 36
    if bits~substr(i, 1) = "1" | rb~substr(i, 1) = "1" then out = out || "1"
    else out = out || "0"
  end
  return self~class~fromBits(out)

::method '&&'
  expose bits
  use strict arg other
  rhs = self~coerce(other)
  out = ""
  rb = rhs~bits
  do i = 1 to 36
    if bits~substr(i, 1) \= rb~substr(i, 1) then out = out || "1"
    else out = out || "0"
  end
  return self~class~fromBits(out)

::method '\'
  expose bits
  use strict arg
  out = ""
  do i = 1 to 36
    if bits~substr(i, 1) = "1" then out = out || "0"
    else out = out || "1"
  end
  return self~class~fromBits(out)

::method '+'
  expose bits
  use strict arg other = .nil
  if arg(1, "O") then return self
  rhs = self~coerce(other)
  rb = rhs~bits
  out = ""
  carry = 0
  do i = 36 to 1 by -1
    total = carry
    if bits~substr(i, 1) = "1" then total = total + 1
    if rb~substr(i, 1) = "1" then total = total + 1
    if total // 2 = 1 then out = "1" || out
    else out = "0" || out
    carry = total % 2
  end
  /* Carry out is intentionally discarded: this is modulo 2**36 algebra. */
  return self~class~fromBits(out)

::method '-'
  use strict arg other = .nil
  if arg(1, "O") then do
    inv = \self
    return inv + self~class~new("1")
  end
  rhs = self~coerce(other)
  return self + (-rhs)

::method shl
  expose bits
  use strict arg count
  if \datatype(count, "W") | count < 0 then
    raise syntax 40.900 array("shift count must be a non-negative whole number:" count)
  if count >= 36 then return self~class~new("0")
  if count = 0 then return self
  return self~class~fromBits(bits~substr(count + 1) || copies("0", count))

::method shr
  expose bits
  use strict arg count
  if \datatype(count, "W") | count < 0 then
    raise syntax 40.900 array("shift count must be a non-negative whole number:" count)
  if count >= 36 then return self~class~new("0")
  if count = 0 then return self
  return self~class~fromBits(copies("0", count) || bits~substr(1, 36 - count))

::method compareTo
  expose bits
  use strict arg other
  rhs = self~coerce(other)
  rb = rhs~bits
  do i = 1 to 36
    a = bits~substr(i, 1)
    b = rb~substr(i, 1)
    if a = b then iterate
    if a = "0" then return -1
    return 1
  end
  return 0

::method equals
  expose bits
  use strict arg other
  if \other~isa(.LROct) then return 0
  return bits == other~bits

/* Orderable makes == value-based through compareTo().  Keep the Object
 * hash contract aligned so equal LROct values are interchangeable keys. */
::method hashCode
  expose bits
  return bits~hashCode

::method coerce private
  use strict arg other
  if other~isa(.LROct) then return other
  return self~class~new(other)

::method validateOctal private
  use strict arg text
  if text = "" then raise syntax 40.900 array("empty octal value")
  do i = 1 to text~length
    if pos(text~substr(i, 1), "01234567") = 0 then
      raise syntax 40.900 array("invalid octal digit:" text~substr(i, 1))
  end
  return 1

::method binaryToDecimal private
  use strict arg bin
  numeric digits 30
  value = 0
  do i = 1 to bin~length
    value = value * 2
    if bin~substr(i, 1) = "1" then value = value + 1
  end
  return value
