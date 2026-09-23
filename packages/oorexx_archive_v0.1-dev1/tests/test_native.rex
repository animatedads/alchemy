/* Pure ooRexx ZIP qualification. No unzip, Python, Java, zlib, or shell. */
numeric digits 50
failures = 0

/* Writer -> reader: Stored, directory, fixed-Huffman Method 8. */
w = .Archive~zipWriter
w~addBytes('hello.txt', 'hello world', 0)
w~addBytes('tree/', '', 0)
repeatData = copies('abc123', 1000)
w~addBytes('tree/repeat.bin', repeatData, 8)
zipBytes = w~bytes
za = .Archive~parseZip(zipBytes)
if za~entries~items \== 3 then call fail 'writer/reader entry count'
if za~extractBytes('hello.txt') \== 'hello world' then call fail 'stored entry round-trip'
if za~extractBytes('tree/repeat.bin') \== repeatData then call fail 'fixed-Huffman Method-8 round-trip'
if za~extractBytes('tree/') \== '' then call fail 'directory extraction should be empty'

/* Dynamic-Huffman Method 8 fixture from ooRexx Compress dev3 qualification. */
dynamicPlain = copies('abcde', 819) || 'a'
dynamicRaw = x2c('EDC4491100000804A0ACEBD1BF823D1C7890EAD94892244992A4CF1D')
dynamicZip = buildSingleZip('dynamic.bin', dynamicPlain, 8, 0, 20, 0, dynamicRaw)
dz = .Archive~parseZip(dynamicZip)
if dz~extractBytes('dynamic.bin') \== dynamicPlain then call fail 'dynamic-Huffman ZIP Method-8 fixture'

/* Data descriptor form: sizes/CRC are authoritative from the central record. */
ddData = copies('descriptor-', 200)
ddZip = buildSingleZip('descriptor.bin', ddData, 8, 8, 20, 0, .nil)
dda = .Archive~parseZip(ddZip)
if dda~extractBytes('descriptor.bin') \== ddData then call fail 'data-descriptor ZIP entry'

/* CRC corruption must be caught during extraction, not accepted as bytes. */
cw = .Archive~zipWriter
cw~addBytes('crc.bin', 'abcdef', 0)
cz = cw~bytes
payloadPos = pos('abcdef', cz)
cz = overlay('abcdeg', cz, payloadPos)
ca = .Archive~parseZip(cz)
if \expectExtractReject(ca, 'crc.bin') then call fail 'corrupt payload CRC was accepted'

/* Lexical traversal and cross-platform path hazards are rejected on open. */
sw = .Archive~zipWriter
sw~addBytes('safe.txt', 'x', 0)
safeZip = sw~bytes
traversalZip = changestr('safe.txt', safeZip, '../x.txt')
if \expectParseReject(traversalZip) then call fail 'dot-dot traversal entry accepted'
absoluteZip = changestr('safe.txt', safeZip, '/abs.txt')
if \expectParseReject(absoluteZip) then call fail 'absolute entry accepted'

/* ASCII case-fold collision: portable package extraction must not be target-dependent. */
ww = .Archive~zipWriter
ww~addBytes('AA.txt', 'A', 0)
ww~addBytes('bb.txt', 'B', 0)
twoZip = ww~bytes
collisionZip = changestr('bb.txt', twoZip, 'aa.txt')
if \expectParseReject(collisionZip) then call fail 'case-fold collision accepted'

/* A file path cannot also be an ancestor directory of another entry. */
pw = .Archive~zipWriter
pw~addBytes('aa', 'x', 0)
pw~addBytes('bb/cc', 'y', 0)
prefixZip = pw~bytes
/* same lengths: turn aa into bb so bb and bb/cc conflict */
prefixZip = changestr('aa', prefixZip, 'bb')
if \expectParseReject(prefixZip) then call fail 'file/descendant prefix conflict accepted'

/* Unix symlink mode in central metadata is rejected. */
symlinkMode = 40960 + 511 /* S_IFLNK | 0777 */
symlinkExternal = symlinkMode * 65536
symlinkMadeBy = 3 * 256 + 20
symlinkZip = buildSingleZip('link', 'target', 0, 0, symlinkMadeBy, symlinkExternal, .nil)
if \expectParseReject(symlinkZip) then call fail 'Unix symlink ZIP entry accepted'

/* Declared size is also a live DEFLATE output ceiling, not merely metadata. */
bombData = copies('bomb-proof-', 2000)
bombZip = buildDishonestZip('bomb.bin', bombData, 9)
bomba = .Archive~parseZip(bombZip)
if \expectExtractReject(bomba, 'bomb.bin') then call fail 'dishonest small declared size allowed oversized inflate'

/* Resource limits are enforced before decompression. */
if \expectParseRejectWithLimit(zipBytes, 2, 1000000, 1000000) then call fail 'entry-count limit not enforced'
if \expectParseRejectWithLimit(zipBytes, 100, 5, 1000000) then call fail 'per-entry size limit not enforced'
if \expectParseRejectWithLimit(zipBytes, 100, 1000000, 10) then call fail 'total size limit not enforced'

/* Trailing bytes after EOCD are rejected. */
if \expectParseReject(zipBytes || 'junk') then call fail 'trailing bytes after EOCD accepted'

/* Fresh-root extraction: root must not pre-exist and nested files are written. */
root = '/tmp/oorexx-archive-' || random(100000,999999)
call SysFileTree root, '_old.', 'DO'
if _old.0 > 0 then call fail 'temporary root collision before extraction'
else do
  za~extractFresh(root)
  if readFile(root || '/hello.txt') \== 'hello world' then call fail 'fresh extraction stored file'
  if readFile(root || '/tree/repeat.bin') \== repeatData then call fail 'fresh extraction nested deflated file'
  if \expectFreshReject(za, root) then call fail 'extractFresh accepted an existing root'
  call SysFileDelete root || '/hello.txt'
  call SysFileDelete root || '/tree/repeat.bin'
  call SysRmDir root || '/tree'
  call SysRmDir root
end

if failures = 0 then do
  say 'PASS native ZIP reader/writer qualification'
  say 'entries=' za~entries~items 'archive_bytes=' length(zipBytes)
  say 'method8_dynamic_bytes=' length(dynamicRaw) 'dynamic_plain_bytes=' length(dynamicPlain)
  exit 0
end
say 'FAIL count=' failures
exit 1


buildDishonestZip: procedure
  numeric digits 50
  use strict arg name, data, declaredSize
  codec = .Compress~new
  packed = codec~deflateFixed(data)
  crc = codec~crc32(data)
  local = x2c('504B0304') || .ZipBinary~put16(20) || .ZipBinary~put16(0) || .ZipBinary~put16(8) || -
          .ZipBinary~put16(0) || .ZipBinary~put16(33) || crc || .ZipBinary~put32(length(packed)) || -
          .ZipBinary~put32(declaredSize) || .ZipBinary~put16(length(name)) || .ZipBinary~put16(0) || name || packed
  central = x2c('504B0102') || .ZipBinary~put16(20) || .ZipBinary~put16(20) || .ZipBinary~put16(0) || .ZipBinary~put16(8) || -
            .ZipBinary~put16(0) || .ZipBinary~put16(33) || crc || .ZipBinary~put32(length(packed)) || .ZipBinary~put32(declaredSize) || -
            .ZipBinary~put16(length(name)) || .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put16(0) || -
            .ZipBinary~put32(0) || .ZipBinary~put32(0) || name
  eocd = x2c('504B0506') || .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put16(1) || .ZipBinary~put16(1) || -
         .ZipBinary~put32(length(central)) || .ZipBinary~put32(length(local)) || .ZipBinary~put16(0)
  return local || central || eocd

buildSingleZip: procedure
  numeric digits 50
  use strict arg name, data, method, flags, madeBy, externalAttrs, packedOverride = .nil
  codec = .Compress~new
  if packedOverride \== .nil then packed = packedOverride
  else if method = 0 then packed = data
  else if method = 8 then packed = codec~deflateFixed(data)
  else raise syntax 88.900 array('fixture method unsupported')
  crc = codec~crc32(data)
  if (flags // 16) >= 8 then do
    localCrc = x2c('00000000'); localComp = 0; localUncomp = 0
  end
  else do
    localCrc = crc; localComp = length(packed); localUncomp = length(data)
  end
  local = x2c('504B0304') || .ZipBinary~put16(20) || .ZipBinary~put16(flags) || .ZipBinary~put16(method) || -
          .ZipBinary~put16(0) || .ZipBinary~put16(33) || localCrc || .ZipBinary~put32(localComp) || -
          .ZipBinary~put32(localUncomp) || .ZipBinary~put16(length(name)) || .ZipBinary~put16(0) || name || packed
  descriptor = ''
  if (flags // 16) >= 8 then descriptor = x2c('504B0708') || crc || .ZipBinary~put32(length(packed)) || .ZipBinary~put32(length(data))
  centralOffset = length(local) + length(descriptor)
  central = x2c('504B0102') || .ZipBinary~put16(madeBy) || .ZipBinary~put16(20) || .ZipBinary~put16(flags) || .ZipBinary~put16(method) || -
            .ZipBinary~put16(0) || .ZipBinary~put16(33) || crc || .ZipBinary~put32(length(packed)) || .ZipBinary~put32(length(data)) || -
            .ZipBinary~put16(length(name)) || .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put16(0) || -
            .ZipBinary~put32(externalAttrs) || .ZipBinary~put32(0) || name
  eocd = x2c('504B0506') || .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put16(1) || .ZipBinary~put16(1) || -
         .ZipBinary~put32(length(central)) || .ZipBinary~put32(centralOffset) || .ZipBinary~put16(0)
  return local || descriptor || central || eocd

expectParseReject: procedure
  signal on syntax name rejected
  use strict arg bytes
  discard = .Archive~parseZip(bytes)
  return .false
rejected:
  return .true

expectParseRejectWithLimit: procedure
  signal on syntax name rejected
  use strict arg bytes, maxEntries, maxEntry, maxTotal
  discard = .ZipArchive~fromBytes(bytes, maxEntries, maxEntry, maxTotal)
  return .false
rejected:
  return .true

expectExtractReject: procedure
  signal on syntax name rejected
  use strict arg archive, name
  discard = archive~extractBytes(name)
  return .false
rejected:
  return .true

expectFreshReject: procedure
  signal on syntax name rejected
  use strict arg archive, root
  discard = archive~extractFresh(root)
  return .false
rejected:
  return .true

readFile: procedure
  use strict arg path
  state = stream(path, 'c', 'open read')
  if left(translate(state), 5) \== 'READY' then return .nil
  data = ''
  do while chars(path) > 0
    count = chars(path)
    if count > 1048576 then count = 1048576
    data ||= charin(path, , count)
  end
  call stream path, 'c', 'close'
  return data

fail: procedure expose failures
  parse arg message
  failures += 1
  say 'FAIL:' message
  return

::requires '../src/Archive.cls'
