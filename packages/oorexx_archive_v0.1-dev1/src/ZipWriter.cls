/*----------------------------------------------------------------------------*/
/* Small native ZIP writer used by bootstrap packaging and qualification.     */
/* Method 0 (Stored) and Method 8 (fixed-Huffman DEFLATE) only.               */
/*----------------------------------------------------------------------------*/
::class ZipWriter public

::method init
  expose items codec policy
  items = .array~new
  codec = .Compress~new
  policy = .ZipPathPolicy~new

::method addBytes
  expose items policy
  use strict arg name, data, method = 0
  isDirectory = right(name, 1) == '/'
  policy~validate(name, isDirectory)
  if isDirectory & length(data) \== 0 then raise syntax 88.900 array('ZIP directory entries must have empty payloads')
  if method \== 0 & method \== 8 then raise syntax 88.900 array('ZipWriter supports only methods 0 and 8')
  items~append(.array~of(name, data, method))
  return self

::method bytes
  expose items codec
  numeric digits 50
  locals = ''
  centrals = ''
  offset = 0
  seen = .directory~new
  policy = .ZipPathPolicy~new
  do item over items
    name = item[1]; data = item[2]; method = item[3]
    key = policy~collisionKey(name)
    if seen~hasIndex(key) then raise syntax 88.900 array('Duplicate/colliding ZipWriter entry: ' || name)
    seen[key] = .true
    if method = 0 then packed = data
    else packed = codec~deflateFixed(data)
    crc = codec~crc32(data)
    nameLen = length(name)
    local = x2c('504B0304') || .ZipBinary~put16(20) || .ZipBinary~put16(0) || .ZipBinary~put16(method) || -
            .ZipBinary~put16(0) || .ZipBinary~put16(33) || crc || .ZipBinary~put32(length(packed)) || -
            .ZipBinary~put32(length(data)) || .ZipBinary~put16(nameLen) || .ZipBinary~put16(0) || name
    external = 0
    if right(name, 1) == '/' then external = 16
    central = x2c('504B0102') || .ZipBinary~put16(20) || .ZipBinary~put16(20) || .ZipBinary~put16(0) || .ZipBinary~put16(method) || -
              .ZipBinary~put16(0) || .ZipBinary~put16(33) || crc || .ZipBinary~put32(length(packed)) || -
              .ZipBinary~put32(length(data)) || .ZipBinary~put16(nameLen) || .ZipBinary~put16(0) || .ZipBinary~put16(0) || -
              .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put32(external) || .ZipBinary~put32(offset) || name
    locals ||= local || packed
    centrals ||= central
    offset += length(local) + length(packed)
  end
  count = items~items
  if count > 65534 then raise syntax 88.900 array('ZipWriter ZIP64 threshold exceeded')
  if length(locals) > 4294967294 | length(centrals) > 4294967294 then raise syntax 88.900 array('ZipWriter ZIP64 threshold exceeded')
  eocd = x2c('504B0506') || .ZipBinary~put16(0) || .ZipBinary~put16(0) || .ZipBinary~put16(count) || .ZipBinary~put16(count) || -
         .ZipBinary~put32(length(centrals)) || .ZipBinary~put32(length(locals)) || .ZipBinary~put16(0)
  return locals || centrals || eocd

::method writeFile
  use strict arg path
  data = self~bytes
  state = stream(path, 'c', 'open write replace')
  if left(translate(state), 5) \== 'READY' then raise syntax 88.900 array('Cannot open ZIP output: ' || path || ' (' || state || ')')
  unwritten = charout(path, data)
  call stream path, 'c', 'close'
  if unwritten \== 0 then raise syntax 88.900 array('Short write creating ZIP: ' || path)
  return path

::requires 'Compress.cls'
::requires 'ZipBinary.cls'
::requires 'ZipPathPolicy.cls'
