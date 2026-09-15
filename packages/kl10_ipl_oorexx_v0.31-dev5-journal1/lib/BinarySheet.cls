/* BinarySheet.cls
 * Declarative binary-layout reader for ooRexx 5.3+
 * v0.4
 *
 * Byte-oriented integer fields honour sheet endianness. Packed/non-byte
 * integer fields honour bit order instead; explicit le/be on a packed field
 * is rejected because the meaning is format-specific.
 */

::class BinarySheet public

::method init
  expose endian bitOrder layouts sourceMode sourceBytes sourceStream size bitpos ownsStream
  endian = "LITTLE"
  bitOrder = "MSB"
  layouts = .directory~new
  sourceMode = "BYTES"
  sourceBytes = ""
  sourceStream = .nil
  size = 0
  bitpos = 0
  ownsStream = 0

::method useLittleEndian
  expose endian
  endian = "LITTLE"
  return self

::method useBigEndian
  expose endian
  endian = "BIG"
  return self

::method useMsbFirstBits
  expose bitOrder
  bitOrder = "MSB"
  return self

::method useLsbFirstBits
  expose bitOrder
  bitOrder = "LSB"
  return self

::method define
  expose layouts
  use arg name
  if name = .nil then raise syntax 40.900 array("empty layout name")
  if name~strip = "" then raise syntax 40.900 array("empty layout name")
  spec = ""
  do i = 2 to arg()
     if arg(i, "O") then iterate
     if spec = "" then spec = arg(i)
                  else spec = spec arg(i)
  end
  spec = spec~space
  if spec = "" then raise syntax 40.900 array("empty layout:" name)
  layouts[name~upper] = spec
  return self

::method bind
  expose sourceMode sourceBytes sourceStream size bitpos ownsStream
  use arg source
  self~close
  if source~hasMethod("CHARIN") then do
     sourceMode = "STREAM"
     sourceStream = source
     sourceBytes = ""
     size = source~chars
     bitpos = 0
     ownsStream = 0
  end
  else do
     sourceMode = "BYTES"
     sourceBytes = source
     sourceStream = .nil
     size = sourceBytes~length
     bitpos = 0
     ownsStream = 0
  end
  return self

::method bindBytes
  expose sourceMode sourceBytes sourceStream size bitpos ownsStream
  use arg bytes
  self~close
  sourceMode = "BYTES"
  sourceBytes = bytes
  sourceStream = .nil
  size = bytes~length
  bitpos = 0
  ownsStream = 0
  return self

::method bindFile
  expose sourceMode sourceBytes sourceStream size bitpos ownsStream
  use arg path
  self~close
  st = .stream~new(path)
  status = st~open("read binary")
  if status \= "READY:" then raise syntax 40.900 array("cannot open:" path status)
  sourceMode = "STREAM"
  sourceStream = st
  sourceBytes = ""
  size = st~chars
  bitpos = 0
  ownsStream = 1
  return self

::method close
  expose sourceStream ownsStream
  if ownsStream then do
     if sourceStream \= .nil then sourceStream~close
  end
  sourceStream = .nil
  ownsStream = 0
  return self

::method uninit
  self~close

::method size
  expose size
  return size

::method sizeBits
  expose size
  return size * 8

::method tellBits
  expose bitpos
  return bitpos

::method tell
  expose bitpos
  if bitpos // 8 \= 0 then return .nil
  return bitpos % 8

::method magic
  use arg at, n
  if arg(1, "O") then at = 0
  if arg(2, "O") then n = 4
  return self~slice(at, n)

::method slice
  expose sourceMode sourceBytes sourceStream size
  use arg at, n
  if \datatype(at, "W") then raise syntax 40.900 array("slice requires whole-number offsets")
  if \datatype(n, "W") then raise syntax 40.900 array("slice requires whole-number offsets")
  if at < 0 then raise syntax 40.900 array("slice OOB:" at n size)
  if n < 0 then raise syntax 40.900 array("slice OOB:" at n size)
  if at + n > size then raise syntax 40.900 array("slice OOB:" at n size)
  if n = 0 then return ""
  if sourceMode = "BYTES" then return sourceBytes~substr(at + 1, n)
  if sourceMode = "STREAM" then do
     bytes = sourceStream~charin(at + 1, n)
     if bytes~length \= n then raise syntax 40.900 array("short stream read:" at n bytes~length)
     return bytes
  end
  raise syntax 40.900 array("no binary source bound")

::method identify
  expose size
  if size >= 2 then do
     if self~magic(0, 2) = "MZ" then return "MZ"
  end
  if size >= 4 then do
     m4 = self~magic(0, 4)
     if m4 = "RIFF" then return "RIFF"
     if m4 = "OggS" then return "OGG"
  end
  return "UNKNOWN"

::method parse
  expose layouts bitpos
  use arg name, at
  if arg(2, "O") then at = 0
  if \datatype(at, "W") then raise syntax 40.900 array("bad byte offset:" at)
  if at < 0 then raise syntax 40.900 array("bad byte offset:" at)
  bitpos = at * 8
  return self~parseCurrent(name)

::method parseBits
  expose bitpos
  use arg name, atBit
  if arg(2, "O") then atBit = 0
  if \datatype(atBit, "W") then raise syntax 40.900 array("bad bit offset:" atBit)
  if atBit < 0 then raise syntax 40.900 array("bad bit offset:" atBit)
  bitpos = atBit
  return self~parseCurrent(name)

::method parseCurrent private
  expose layouts bitpos
  use arg name
  spec = layouts[name~upper]
  if spec = .nil then raise syntax 40.900 array("unknown layout:" name)
  row = .directory~new
  nw = spec~words
  i = 1
  do while i <= nw
     token = spec~word(i)
     low = token~lower
     if self~isDirective(low) then do
        self~applyDirective(low)
        i = i + 1
        iterate
     end
     if i = nw then raise syntax 40.900 array("dangling field:" token)
     type = spec~word(i + 1)~lower
     row[token] = self~readTyped(type)
     i = i + 2
  end
  row["_endbit"] = bitpos
  row["_endceil"] = (bitpos + 7) % 8
  if bitpos // 8 = 0 then row["_end"] = bitpos % 8
                       else row["_end"] = .nil
  return row

::method isDirective private
  use arg token
  if token~left(8) = "skipbits" then do
     tail = token~substr(9)
     if \datatype(tail, "W") then return 0
     return tail > 0
  end
  if token~left(4) = "skip" then do
     tail = token~substr(5)
     if \datatype(tail, "W") then return 0
     return tail > 0
  end
  if token~left(9) = "alignbits" then do
     tail = token~substr(10)
     if \datatype(tail, "W") then return 0
     return tail > 0
  end
  if token~left(5) = "align" then do
     tail = token~substr(6)
     if \datatype(tail, "W") then return 0
     return tail > 0
  end
  return 0

::method applyDirective private
  use arg token
  if token~left(8) = "skipbits" then do
     self~skipBits(self~positiveWidth(token~substr(9), token))
     return
  end
  if token~left(4) = "skip" then do
     self~skipBits(self~positiveWidth(token~substr(5), token) * 8)
     return
  end
  if token~left(9) = "alignbits" then do
     self~alignBits(self~positiveWidth(token~substr(10), token))
     return
  end
  if token~left(5) = "align" then do
     self~alignBits(self~positiveWidth(token~substr(6), token) * 8)
     return
  end
  raise syntax 40.900 array("bad directive:" token)

::method positiveWidth private
  use arg text, context
  if \datatype(text, "W") then raise syntax 40.900 array("bad width:" context)
  if text < 1 then raise syntax 40.900 array("bad width:" context)
  return text + 0

::method readTyped private
  expose endian bitOrder bitpos
  use arg type
  e = endian
  bo = bitOrder
  explicitEndian = 0

  /* Suffixes are independent: u16be, u7lsb, u16bemsb are accepted. */
  changed = 1
  do while changed
     changed = 0
     if type~length >= 3 then do
        suf3 = type~right(3)
        if suf3 = "msb" then do
           bo = "MSB"; type = type~left(type~length - 3); changed = 1; iterate
        end
        if suf3 = "lsb" then do
           bo = "LSB"; type = type~left(type~length - 3); changed = 1; iterate
        end
     end
     if type~length >= 2 then do
        suf2 = type~right(2)
        if suf2 = "le" then do
           e = "LITTLE"; type = type~left(type~length - 2); explicitEndian = 1; changed = 1; iterate
        end
        if suf2 = "be" then do
           e = "BIG"; type = type~left(type~length - 2); explicitEndian = 1; changed = 1; iterate
        end
     end
  end

  lead = type~left(1)
  if lead = "a" then do
     n = self~positiveWidth(type~substr(2), type)
     return self~needBytes(n)
  end
  if lead = "x" then do
     n = self~positiveWidth(type~substr(2), type)
     return self~needBytes(n)
  end

  if lead = "u" then do
     bits = self~positiveWidth(type~substr(2), type)
     signed = 0
     if bitpos // 8 = 0 then do
        if bits // 8 = 0 then return self~integerBytes(bits % 8, signed, e)
     end
     if explicitEndian then
        raise syntax 40.900 array("le/be is undefined for packed field:" type "at bit" bitpos)
     return self~integerBits(bits, signed, bo)
  end

  if lead = "i" then do
     bits = self~positiveWidth(type~substr(2), type)
     signed = 1
     if bitpos // 8 = 0 then do
        if bits // 8 = 0 then return self~integerBytes(bits % 8, signed, e)
     end
     if explicitEndian then
        raise syntax 40.900 array("le/be is undefined for packed field:" type "at bit" bitpos)
     return self~integerBits(bits, signed, bo)
  end

  raise syntax 40.900 array("bad type:" type)

::method decimalDigitsForBits private
  use arg bits
  /* ceil(bits * log10(2)) + guard; 0.30103 is a safe high approximation. */
  return ((bits * 30103 + 99999) % 100000) + 2

::method integerBytes private
  use arg n, signed, e
  bits = n * 8
  needDigits = self~decimalDigitsForBits(bits)
  numeric digits needDigits
  raw = self~needBytes(n)
  if e = "LITTLE" then raw = raw~reverse
  value = c2d(raw)
  if signed then do
     cap = 2 ** bits
     if value >= cap % 2 then value = value - cap
  end
  return value

::method integerBits private
  expose bitpos
  use arg bits, signed, bo
  needDigits = self~decimalDigitsForBits(bits)
  numeric digits needDigits
  value = 0
  if bo = "MSB" then do
     do k = 1 to bits
        value = value * 2 + self~nextBit("MSB")
     end
  end
  else do
     place = 1
     do k = 1 to bits
        value = value + self~nextBit("LSB") * place
        place = place * 2
     end
  end
  if signed then do
     cap = 2 ** bits
     if value >= cap % 2 then value = value - cap
  end
  return value

::method nextBit private
  expose bitpos size
  use arg bo
  if bitpos >= size * 8 then raise syntax 40.900 array("EOF at bit" bitpos)
  byteAt = bitpos % 8
  within = bitpos // 8
  byteValue = c2d(self~slice(byteAt, 1))
  if bo = "MSB" then shift = 7 - within
                else shift = within
  divisor = 2 ** shift
  bit = (byteValue % divisor) // 2
  bitpos = bitpos + 1
  return bit

::method needBytes private
  expose bitpos size
  use arg n
  if bitpos // 8 \= 0 then raise syntax 40.900 array("byte field at non-byte bit offset:" bitpos)
  at = bitpos % 8
  if n < 0 then raise syntax 40.900 array("EOF:" at n size)
  if at + n > size then raise syntax 40.900 array("EOF:" at n size)
  chunk = self~slice(at, n)
  bitpos = bitpos + n * 8
  return chunk

::method skipBits private
  expose bitpos size
  use arg n
  if n < 0 then raise syntax 40.900 array("skip OOB:" bitpos n size * 8)
  if bitpos + n > size * 8 then raise syntax 40.900 array("skip OOB:" bitpos n size * 8)
  bitpos = bitpos + n

::method alignBits private
  expose bitpos size
  use arg boundary
  if boundary < 1 then raise syntax 40.900 array("bad alignment:" boundary)
  remainder = bitpos // boundary
  if remainder \= 0 then bitpos = bitpos + boundary - remainder
  if bitpos > size * 8 then raise syntax 40.900 array("alignment past EOF:" bitpos)

::method pcm16Channels
  /* Backward-compatible raw deinterleaved channel bytes. */
  use arg at, byteLen, channels
  return self~pcm16ChannelBytes(at, byteLen, channels)

::method pcm16ChannelBytes
  use arg at, byteLen, channels
  if \datatype(channels, "W") then raise syntax 40.900 array("bad channel count")
  if channels < 1 then raise syntax 40.900 array("bad channel count")
  frameBytes = channels * 2
  if \datatype(byteLen, "W") then raise syntax 40.900 array("bad PCM16 frame length")
  if byteLen < 0 then raise syntax 40.900 array("bad PCM16 frame length")
  if byteLen // frameBytes \= 0 then raise syntax 40.900 array("bad PCM16 frame length")
  frames = byteLen % frameBytes
  out = .array~new(channels)
  do c = 1 to channels
     out[c] = ""
  end
  p = at
  do f = 1 to frames
     do c = 1 to channels
        out[c] = out[c] || self~slice(p, 2)
        p = p + 2
     end
  end
  return out
