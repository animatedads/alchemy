/*----------------------------------------------------------------------------*/
/* Canonical DEFLATE Huffman decode table.                                    */
/*                                                                            */
/* DEFLATE transmits Huffman code bits most-significant bit first even though */
/* non-Huffman bit fields are packed least-significant bit first.             */
/* NativeBitReader~readBits(1) therefore yields Huffman bits in canonical     */
/* code order, and decode() accumulates them left-to-right.                    */
/*----------------------------------------------------------------------------*/
::class NativeDeflateHuffmanTable public

::method init
  expose lookup maxBits empty kind
  use strict arg lengths, kind = 'GENERIC'
  numeric digits 50
  kind = translate(kind)
  lookup = .directory~new
  counts = .array~new(15)~fill(0)
  maxBits = 0
  used = 0

  do i = 1 to lengths~items
    len = lengths[i]
    if \datatype(len, 'W') | len < 0 | len > 15 then -
      raise syntax 88.900 array('Invalid DEFLATE Huffman code length ' || len || ' at symbol ' || (i - 1))
    if len > 0 then do
      counts[len] += 1
      used += 1
      if len > maxBits then maxBits = len
    end
  end

  if used = 0 then do
    empty = .true
    if kind \== 'DISTS' then -
      raise syntax 88.900 array('Empty DEFLATE Huffman alphabet is only valid for an unused distance alphabet')
    return
  end
  empty = .false

  /* RFC 1951 validity rule: over-subscribed trees always fail.               */
  /* The accepted incomplete form is the one-symbol, one-bit LENS/DISTS tree. */
  /* The code-length alphabet itself must be complete.                         */
  left = 1
  do bits = 1 to 15
    left = left * 2 - counts[bits]
    if left < 0 then raise syntax 88.900 array('Over-subscribed DEFLATE Huffman code set')
  end
  if left > 0 then do
    if kind == 'CODES' | maxBits \== 1 then -
      raise syntax 88.900 array('Incomplete DEFLATE Huffman code set')
  end

  nextCode = .array~new(15)~fill(0)
  code = 0
  previousCount = 0
  do bits = 1 to 15
    code = (code + previousCount) * 2
    nextCode[bits] = code
    previousCount = counts[bits]
  end

  do symbolIndex = 1 to lengths~items
    len = lengths[symbolIndex]
    if len = 0 then iterate
    symbolCode = nextCode[len]
    nextCode[len] += 1
    key = len || ':' || symbolCode
    if lookup~hasIndex(key) then -
      raise syntax 88.900 array('Duplicate DEFLATE Huffman code assignment')
    lookup[key] = symbolIndex - 1
  end

::method decode
  expose lookup maxBits empty
  use strict arg reader
  if empty then raise syntax 88.900 array('DEFLATE stream attempted to use an empty distance alphabet')
  code = 0
  do bits = 1 to maxBits
    code = code * 2 + reader~readBits(1)
    key = bits || ':' || code
    if lookup~hasIndex(key) then return lookup[key]
  end
  raise syntax 88.900 array('Invalid DEFLATE Huffman prefix')

::method isEmpty
  expose empty
  return empty
