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

fail: procedure expose failures
  parse arg message
  failures += 1
  say 'FAIL:' message
  return

::requires '../src/Compress.cls'
