/*----------------------------------------------------------------------------*/
/* ooRexx Archive v0.1-dev1 -- native ZIP reader and confined decoder.        */
/*----------------------------------------------------------------------------*/
::class ZipArchive public

::method fromBytes class
  use strict arg bytes, maxEntries = 10000, maxEntryBytes = 536870912, maxTotalBytes = 1073741824
  return self~new(bytes, maxEntries, maxEntryBytes, maxTotalBytes)

::method fromFile class
  use strict arg path, maxEntries = 10000, maxEntryBytes = 536870912, maxTotalBytes = 1073741824
  state = stream(path, 'c', 'open read')
  if left(translate(state), 5) \== 'READY' then raise syntax 88.900 array('Cannot open ZIP input: ' || path || ' (' || state || ')')
  bytes = ''
  do while chars(path) > 0
    count = chars(path)
    if count > 1048576 then count = 1048576
    bytes ||= charin(path, , count)
  end
  call stream path, 'c', 'close'
  return self~new(bytes, maxEntries, maxEntryBytes, maxTotalBytes)

::method init
  expose bytes entries byName centralOffset centralSize archiveComment maxEntries maxEntryBytes maxTotalBytes policy codec
  numeric digits 50
  use strict arg bytes, maxEntries = 10000, maxEntryBytes = 536870912, maxTotalBytes = 1073741824
  entries = .array~new
  byName = .directory~new
  policy = .ZipPathPolicy~new
  codec = .Compress~new
  self~parseCentralDirectory
  self~validatePathGraph
  self~auditLocalRecords

::attribute entries get
::attribute centralOffset get
::attribute centralSize get
::attribute archiveComment get

::method entry
  expose byName
  use strict arg name
  if \byName~hasIndex(name) then return .nil
  return byName[name]

::method names
  expose entries
  out = .array~new
  do e over entries
    out~append(e~name)
  end
  return out

::method extractBytes
  expose bytes codec
  use strict arg entryOrName
  if entryOrName~isA(.ZipEntry) then entry = entryOrName
  else do
    entry = self~entry(entryOrName)
    if entry == .nil then raise syntax 88.900 array('ZIP entry not found: ' || entryOrName)
  end
  if entry~isDirectory then return ''
  compressed = substr(bytes, entry~localDataStart, entry~compressedSize)
  select
    when entry~method = 0 then out = compressed
    when entry~method = 8 then out = codec~inflate(compressed, entry~uncompressedSize)
    otherwise raise syntax 88.900 array('Unsupported ZIP compression method ' || entry~method || ' for ' || entry~name)
  end
  if length(out) \== entry~uncompressedSize then -
    raise syntax 88.900 array('ZIP uncompressed size mismatch for ' || entry~name || ': expected ' || entry~uncompressedSize || ' got ' || length(out))
  actualCrc = codec~crc32(out)
  if actualCrc \== entry~crc32Bytes then -
    raise syntax 88.900 array('ZIP CRC32 mismatch for ' || entry~name || ': expected ' || c2x(entry~crc32Bytes) || ' got ' || c2x(actualCrc))
  return out

::method extractFresh
  expose entries policy
  use strict arg root
  if root == '' then raise syntax 88.900 array('Fresh extraction root must not be empty')
  if pos('*', root) > 0 | pos('?', root) > 0 then raise syntax 88.900 array('Fresh extraction root must not contain wildcard characters')
  /* Fresh-root mode avoids pre-existing link traversal.  Descriptor-relative
   * no-follow extraction remains a platform capability gap documented by the
   * package.  The transaction layer should create the staging parent 0700. */
  if self~pathExists(root) then raise syntax 88.900 array('Fresh extraction root already exists: ' || root)
  rc = SysMkDir(root)
  if rc \== 0 then raise syntax 88.900 array('Cannot create fresh extraction root: ' || root || ' rc=' || rc)

  createdDirs = .directory~new
  createdDirs[''] = .true
  do entry over entries
    name = entry~name
    parents = policy~parentNames(name)
    do rel over parents
      if \createdDirs~hasIndex(rel) then do
        full = root || '/' || rel
        rc = SysMkDir(full)
        if rc \== 0 then raise syntax 88.900 array('Cannot create extraction directory: ' || full || ' rc=' || rc)
        createdDirs[rel] = .true
      end
    end

    if entry~isDirectory then do
      rel = left(name, length(name) - 1)
      if \createdDirs~hasIndex(rel) then do
        full = root || '/' || rel
        rc = SysMkDir(full)
        if rc \== 0 then raise syntax 88.900 array('Cannot create extraction directory: ' || full || ' rc=' || rc)
        createdDirs[rel] = .true
      end
      iterate
    end

    data = self~extractBytes(entry)
    path = root || '/' || name
    state = stream(path, 'c', 'open write replace')
    if left(translate(state), 5) \== 'READY' then raise syntax 88.900 array('Cannot open extracted file: ' || path || ' (' || state || ')')
    unwritten = charout(path, data)
    call stream path, 'c', 'close'
    if unwritten \== 0 then raise syntax 88.900 array('Short write extracting ZIP entry: ' || name)
  end
  return root

::method parseCentralDirectory private
  expose bytes entries byName centralOffset centralSize archiveComment maxEntries maxEntryBytes maxTotalBytes policy
  numeric digits 50
  n = length(bytes)
  if n < 22 then raise syntax 88.900 array('Input is too small to be a ZIP archive')
  eocd = self~findEocd
  disk = .ZipBinary~le16(bytes, eocd + 4)
  cdDisk = .ZipBinary~le16(bytes, eocd + 6)
  diskEntries = .ZipBinary~le16(bytes, eocd + 8)
  totalEntries = .ZipBinary~le16(bytes, eocd + 10)
  centralSize = .ZipBinary~le32(bytes, eocd + 12)
  centralOffset0 = .ZipBinary~le32(bytes, eocd + 16)
  commentLen = .ZipBinary~le16(bytes, eocd + 20)

  if eocd + 22 + commentLen - 1 \== n then raise syntax 88.900 array('ZIP trailing data or EOCD comment length mismatch')
  archiveComment = substr(bytes, eocd + 22, commentLen)
  if disk \== 0 | cdDisk \== 0 | diskEntries \== totalEntries then raise syntax 88.900 array('Multi-disk ZIP archives are not supported')
  if totalEntries = 65535 | centralSize = 4294967295 | centralOffset0 = 4294967295 then -
    raise syntax 88.900 array('ZIP64 archives are not supported by bootstrap archive v0.1')
  if totalEntries > maxEntries then raise syntax 88.900 array('ZIP entry-count limit exceeded: ' || totalEntries || ' > ' || maxEntries)

  centralOffset = centralOffset0 + 1
  if centralOffset < 1 | centralOffset + centralSize \== eocd then raise syntax 88.900 array('ZIP central directory offset/size does not terminate at EOCD')

  pos = centralOffset
  totalUncompressed = 0
  collision = .directory~new
  do index = 1 to totalEntries
    if substr(bytes, pos, 4) \== x2c('504B0102') then raise syntax 88.900 array('Missing ZIP central-directory header at byte ' || pos)
    versionMadeBy = .ZipBinary~le16(bytes, pos + 4)
    versionNeeded = .ZipBinary~le16(bytes, pos + 6)
    flags = .ZipBinary~le16(bytes, pos + 8)
    method = .ZipBinary~le16(bytes, pos + 10)
    crc = substr(bytes, pos + 16, 4)
    compressedSize = .ZipBinary~le32(bytes, pos + 20)
    uncompressedSize = .ZipBinary~le32(bytes, pos + 24)
    nameLen = .ZipBinary~le16(bytes, pos + 28)
    extraLen = .ZipBinary~le16(bytes, pos + 30)
    commentEntryLen = .ZipBinary~le16(bytes, pos + 32)
    diskStart = .ZipBinary~le16(bytes, pos + 34)
    internalAttrs = .ZipBinary~le16(bytes, pos + 36)
    externalAttrs = .ZipBinary~le32(bytes, pos + 38)
    localOffset0 = .ZipBinary~le32(bytes, pos + 42)
    recordLen = 46 + nameLen + extraLen + commentEntryLen
    .ZipBinary~requireRange(bytes, pos, recordLen)

    if compressedSize = 4294967295 | uncompressedSize = 4294967295 | localOffset0 = 4294967295 | diskStart = 65535 then -
      raise syntax 88.900 array('ZIP64 entry fields are not supported')
    if diskStart \== 0 then raise syntax 88.900 array('Multi-disk ZIP entry is not supported')
    if self~flagSet(flags, 1) | self~flagSet(flags, 64) | self~flagSet(flags, 8192) then -
      raise syntax 88.900 array('Encrypted ZIP entries are not supported')
    if method \== 0 & method \== 8 then raise syntax 88.900 array('Unsupported ZIP compression method ' || method)
    if method = 0 & compressedSize \== uncompressedSize then raise syntax 88.900 array('Stored ZIP entry has unequal compressed/uncompressed sizes')
    if uncompressedSize > maxEntryBytes then raise syntax 88.900 array('ZIP entry size limit exceeded for entry ' || index)
    totalUncompressed += uncompressedSize
    if totalUncompressed > maxTotalBytes then raise syntax 88.900 array('ZIP total uncompressed-size limit exceeded')

    name = substr(bytes, pos + 46, nameLen)
    isDirectory = right(name, 1) == '/'
    policy~validate(name, isDirectory)
    if isDirectory then do
      if compressedSize \== 0 | uncompressedSize \== 0 | crc \== x2c('00000000') then -
        raise syntax 88.900 array('ZIP directory entry must have zero sizes and CRC: ' || name)
      if method \== 0 then raise syntax 88.900 array('ZIP directory entry must use Stored method: ' || name)
    end
    if byName~hasIndex(name) then raise syntax 88.900 array('Duplicate ZIP entry name: ' || name)
    key = policy~collisionKey(name)
    if collision~hasIndex(key) then raise syntax 88.900 array('Portable case-fold path collision: ' || name || ' conflicts with ' || collision[key])
    collision[key] = name

    unixMode = .nil
    host = versionMadeBy % 256
    if host = 0 then do
      dosAttrs = externalAttrs // 256
      if self~flagSet(dosAttrs, 16) & \isDirectory then raise syntax 88.900 array('DOS directory attribute without trailing slash: ' || name)
    end
    if host = 3 then do
      unixMode = externalAttrs % 65536
      fileType = unixMode % 4096 * 4096 /* clear lower 12 permission bits */
      if fileType \== 0 then do
        if isDirectory then do
          if fileType \== 16384 then raise syntax 88.900 array('Non-directory special Unix ZIP entry rejected: ' || name)
        end
        else if fileType \== 32768 then raise syntax 88.900 array('Symlink or special Unix ZIP entry rejected: ' || name)
      end
    end

    entry = .ZipEntry~new(name, method, flags, crc, compressedSize, uncompressedSize, -
                          localOffset0, versionMadeBy, versionNeeded, externalAttrs, -
                          internalAttrs, diskStart, isDirectory, unixMode)
    entries~append(entry)
    byName[name] = entry
    pos += recordLen
  end
  if pos \== centralOffset + centralSize then raise syntax 88.900 array('ZIP central-directory size/count mismatch')
  return

::method validatePathGraph private
  expose entries policy
  kinds = .directory~new
  do entry over entries
    parents = policy~parentNames(entry~name)
    do parent over parents
      key = policy~collisionKey(parent)
      if kinds~hasIndex(key) then do
        if kinds[key] == 'F' then raise syntax 88.900 array('ZIP path descends through file entry: ' || parent || ' -> ' || entry~name)
      end
      else kinds[key] = 'D'
    end
    key = policy~collisionKey(entry~name)
    kind = 'F'
    if entry~isDirectory then kind = 'D'
    if kinds~hasIndex(key) then do
      if kinds[key] \== kind then raise syntax 88.900 array('ZIP file/directory prefix conflict at ' || entry~name)
    end
    kinds[key] = kind
  end
  return

::method auditLocalRecords private
  expose bytes entries centralOffset
  ranges = .array~new
  do entry over entries
    pos = entry~localOffset + 1
    .ZipBinary~requireRange(bytes, pos, 30)
    if substr(bytes, pos, 4) \== x2c('504B0304') then raise syntax 88.900 array('Missing local ZIP header for ' || entry~name)
    flags = .ZipBinary~le16(bytes, pos + 6)
    method = .ZipBinary~le16(bytes, pos + 8)
    nameLen = .ZipBinary~le16(bytes, pos + 26)
    extraLen = .ZipBinary~le16(bytes, pos + 28)
    .ZipBinary~requireRange(bytes, pos, 30 + nameLen + extraLen)
    localName = substr(bytes, pos + 30, nameLen)
    if localName \== entry~name then raise syntax 88.900 array('Local/central ZIP filename mismatch for ' || entry~name)
    if method \== entry~method then raise syntax 88.900 array('Local/central ZIP method mismatch for ' || entry~name)
    if flags \== entry~flags then raise syntax 88.900 array('Local/central ZIP flag mismatch for ' || entry~name)
    if self~flagSet(flags, 1) | self~flagSet(flags, 64) | self~flagSet(flags, 8192) then -
      raise syntax 88.900 array('Encrypted local ZIP record rejected for ' || entry~name)

    dataStart = pos + 30 + nameLen + extraLen
    dataEnd = dataStart + entry~compressedSize - 1
    if entry~compressedSize = 0 then dataEnd = dataStart - 1
    if dataStart > centralOffset | dataEnd >= centralOffset then raise syntax 88.900 array('ZIP entry data overlaps central directory: ' || entry~name)
    if entry~compressedSize > 0 then .ZipBinary~requireRange(bytes, dataStart, entry~compressedSize)
    recordEnd = dataEnd

    if entry~hasDataDescriptor then do
      dd = dataEnd + 1
      .ZipBinary~requireRange(bytes, dd, 12)
      if substr(bytes, dd, 4) == x2c('504B0708') then do
        .ZipBinary~requireRange(bytes, dd, 16)
        dd += 4
        recordEnd = dd + 11
      end
      else recordEnd = dd + 11
      if substr(bytes, dd, 4) \== entry~crc32Bytes then raise syntax 88.900 array('ZIP data-descriptor CRC mismatch for ' || entry~name)
      if .ZipBinary~le32(bytes, dd + 4) \== entry~compressedSize then raise syntax 88.900 array('ZIP data-descriptor compressed-size mismatch for ' || entry~name)
      if .ZipBinary~le32(bytes, dd + 8) \== entry~uncompressedSize then raise syntax 88.900 array('ZIP data-descriptor uncompressed-size mismatch for ' || entry~name)
      if recordEnd >= centralOffset then raise syntax 88.900 array('ZIP data descriptor overlaps central directory: ' || entry~name)
    end
    else do
      localCrc = substr(bytes, pos + 14, 4)
      localCompressed = .ZipBinary~le32(bytes, pos + 18)
      localUncompressed = .ZipBinary~le32(bytes, pos + 22)
      if localCrc \== entry~crc32Bytes | localCompressed \== entry~compressedSize | localUncompressed \== entry~uncompressedSize then -
        raise syntax 88.900 array('Local/central ZIP size or CRC mismatch for ' || entry~name)
    end

    entry~localDataStart = dataStart
    entry~localDataEnd = dataEnd
    range = .array~of(pos, recordEnd, entry~name)
    ranges~append(range)
  end
  self~rejectOverlaps(ranges)
  return

::method rejectOverlaps private
  use strict arg ranges
  do i = 1 to ranges~items
    a = ranges[i]
    do j = i + 1 to ranges~items
      b = ranges[j]
      if a[1] <= b[2] & b[1] <= a[2] then -
        raise syntax 88.900 array('Overlapping ZIP local records: ' || a[3] || ' and ' || b[3])
    end
  end
  return

::method findEocd private
  expose bytes
  n = length(bytes)
  start = n - 21
  minimum = n - 65557
  if minimum < 1 then minimum = 1
  do pos = start to minimum by -1
    if substr(bytes, pos, 4) == x2c('504B0506') then do
      if pos + 21 <= n then do
        commentLen = .ZipBinary~le16(bytes, pos + 20)
        if pos + 22 + commentLen - 1 = n then return pos
      end
    end
  end
  raise syntax 88.900 array('ZIP end-of-central-directory record not found')

::method flagSet private
  use strict arg value, mask
  return (value // (mask * 2)) >= mask

::method pathExists private
  use strict arg path
  call SysFileTree path, '_za_exists.', 'DO'
  return _za_exists.0 > 0

::requires 'Compress.cls'
::requires 'ZipBinary.cls'
::requires 'ZipEntry.cls'
::requires 'ZipPathPolicy.cls'
