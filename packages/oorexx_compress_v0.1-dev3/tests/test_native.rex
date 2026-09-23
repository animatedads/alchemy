/* Pure ooRexx qualification: no foreign runtime, shell, zlib or external gzip. */
numeric digits 50
codec = .Compress~new
failures = 0

if codec~provider \== 'native-oorexx' then call fail 'wrong provider: ' codec~provider
if c2x(codec~crc32('123456789')) \== '2639F4CB' then call fail 'CRC32 known vector failed'

allbytes = ''
do i = 0 to 255
  allbytes ||= d2c(i, 1)
end

cases = .array~of('', 'a', 'hello world', allbytes || allbytes, copies('abc123', 4000))
do data over cases
  fixed = codec~gzip(data, 'FIXED')
  restored = codec~gunzip(fixed)
  if restored \== data then call fail 'fixed-Huffman gzip round-trip failed at length ' || length(data)

  stored = codec~gzip(data, 'STORED')
  restored = codec~gunzip(stored)
  if restored \== data then call fail 'stored-block gzip round-trip failed at length ' || length(data)
end

/* RFC-1951 dynamic-Huffman decode fixture.  Generated once with GNU gzip
 * -9 -n from 4096 bytes of the repeating byte sequence 'abcde'.  The raw
 * DEFLATE stream starts with BFINAL=1, BTYPE=10 and is retained here so the
 * required native qualification has no dependency on an external gzip tool. */
dynamicPlain = copies('abcde', 819) || 'a'
dynamicRaw = x2c('EDC4491100000804A0ACEBD1BF823D1C7890EAD94892244992A4CF1D')
if codec~inflate(dynamicRaw) \== dynamicPlain then call fail 'dynamic-Huffman raw DEFLATE fixture failed'
dynamicGzip = x2c('1F8B0800000000000203') || dynamicRaw || x2c('585EF80E00100000')
if codec~gunzip(dynamicGzip) \== dynamicPlain then call fail 'dynamic-Huffman gzip fixture failed'

/* RFC 1951 permits one distance code length of zero when the block contains
 * literals only.  This 12-byte dynamic block contains only EOB and therefore
 * has an empty distance alphabet; it must decode to the empty string. */
literalOnlyDynamic = x2c('05C0810800000000207FEB03')
if codec~inflate(literalOnlyDynamic) \== '' then call fail 'dynamic-Huffman empty-distance fixture failed'

/* Dynamic-tree validity and hostile header checks. */
if \expectTableReject(.array~of(1,1,1), 'LENS') then call fail 'over-subscribed Huffman tree was accepted'
if \expectTableReject(.array~of(1), 'CODES') then call fail 'incomplete code-length Huffman tree was accepted'
if expectTableReject(.array~of(1), 'DISTS') then call fail 'one-symbol one-bit distance tree was rejected'
if expectTableReject(.array~of(0), 'DISTS') then call fail 'empty unused distance alphabet was rejected'

/* BFINAL=1, BTYPE=10, HLIT field=31 -> 288 literal/length codes. RFC 1951
 * permits at most 286, so this must fail before any tree material is read. */
if \expectInflateReject(x2c('FD')) then call fail 'reserved DEFLATE HLIT range was accepted'

/* Exercise gzip FHCRC parsing. */
plain = copies('header-crc-', 40)
gz = codec~gzip(plain, 'FIXED')
header = substr(gz, 1, 3) || d2c(2, 1) || substr(gz, 5, 6)
headerCrc = substr(codec~crc32(header), 1, 2)
withHeaderCrc = header || headerCrc || substr(gz, 11)
if codec~gunzip(withHeaderCrc) \== plain then call fail 'FHCRC gzip round-trip failed'

/* LZ77 must actually be active, not merely named in comments. */
repetitive = copies('abcabcabcabcabcabc', 2000)
fixed = codec~gzip(repetitive, 'FIXED')
stored = codec~gzip(repetitive, 'STORED')
if length(fixed) >= length(stored) then call fail 'LZ77/fixed-Huffman path did not beat stored mode on repetitive data'

if failures = 0 then do
  say 'PASS native bootstrap compression qualification'
  say 'provider=' codec~provider
  say 'capabilities=' codec~capabilities~toString
  say 'lz77_input_bytes=' length(repetitive) 'fixed_gzip_bytes=' length(fixed) 'stored_gzip_bytes=' length(stored)
  exit 0
end
say 'FAIL count=' failures
exit 1

expectTableReject: procedure
  signal on syntax name rejected
  use strict arg lengths, kind
  discard = .NativeDeflateHuffmanTable~new(lengths, kind)
  return .false
rejected:
  return .true

expectInflateReject: procedure
  signal on syntax name rejected
  use strict arg bytes
  codec = .Compress~new
  discard = codec~inflate(bytes)
  return .false
rejected:
  return .true

fail: procedure expose failures
  parse arg message
  failures += 1
  say 'FAIL:' message
  return

::requires '../src/Compress.cls'
