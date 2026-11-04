/* Single Time Service v0.8 — read-only pinned TZif rule archives.
 * Snapshot publication and full SHA-256 verification are performed by the
 * independent offline tools/time_snapshot.py. The ooRexx runtime checks size,
 * Adler32 and TZif structure; Adler32 is NOT authentication. It parses the
 * very same bytes it checks, avoiding an internal digest/read race.
 * A trusted filesystem and verified installed archive are prerequisites.
 * No host clock, system timezone, scheduler or connector side effects. */
::requires 'TzifZoneProvider.cls'

::class 'TimeRuleSnapshotCatalog' public
::method init
  expose root
  use strict arg root
  if root == '' then raise syntax 93.900 array ('trusted snapshot root required')

::attribute root get

::method checkedToken private
  use strict arg value, label
  if value == '' | value == '.' | value == '..' | value~length > 80 then raise syntax 93.900 array ('invalid' label)
  if verify(value,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-') > 0 then raise syntax 93.900 array ('unsafe' label)
  return value

::method checkedZone private
  use strict arg value
  if value == '' | left(value,1) == '/' | right(value,1) == '/' | value~length > 255 then raise syntax 93.900 array ('invalid zone')
  rest=value
  do while rest \== ''
    parse var rest part '/' rest
    if part == '' | part == '.' | part == '..' then raise syntax 93.900 array ('unsafe zone segment')
    if verify(part,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-') > 0 then raise syntax 93.900 array ('unsafe zone')
  end
  return value

/* Manifest is canonical US-ASCII lines: snapshot is one lexical component;
 * entries are sorted, unique, and have full SHA-256 and Adler32 witnesses. */
::method inspect
  expose root
  use strict arg snapshot
  snapshot=self~checkedToken(snapshot,'snapshot')
  filename=root || '/' || snapshot || '/MANIFEST.tsv'
  if stream(filename,'C','QUERY EXISTS') == '' then raise syntax 93.900 array ('snapshot manifest missing')
  opened=stream(filename,'C','OPEN READ')
  if left(opened,6) == 'ERROR:' then raise syntax 93.900 array ('cannot open snapshot manifest')
  header=linein(filename)
  parse var header magic '|' storedId '|' edition
  if magic \== 'SINGLE_TIME_TZIF_V1' | storedId \== snapshot then raise syntax 93.900 array ('snapshot manifest header mismatch')
  edition=self~checkedToken(edition,'edition')
  entries=.directory~new
  zoneOrder=.array~new
  seenEnd=.false
  do while lines(filename) > 0
    line=linein(filename)
    if line~length > 512 then raise syntax 93.900 array ('oversized manifest record')
    if left(line,4) == 'END|' then do
      parse var line marker '|' count
      if \datatype(count,'W') | count \== zoneOrder~items then raise syntax 93.900 array ('manifest count mismatch')
      if lines(filename) > 0 then raise syntax 93.900 array ('manifest records after END')
      seenEnd=.true
      leave
    end
    parse var line kind '|' zone '|' lengthValue '|' sha '|' adler
    if kind \== 'ZONE' then raise syntax 93.900 array ('invalid zone manifest record')
    zone=self~checkedZone(zone)
    if entries~hasIndex(zone) then raise syntax 93.900 array ('duplicate zone manifest record')
    if zoneOrder~items > 0 then do
      if zone <= zoneOrder[zoneOrder~items] then raise syntax 93.900 array ('manifest records must be sorted')
    end
    if \datatype(lengthValue,'W') | lengthValue < 44 | lengthValue > 16777216 then raise syntax 93.900 array ('invalid zone size')
    if length(lengthValue) > 1 & left(lengthValue,1) == '0' then raise syntax 93.900 array ('noncanonical zone length')
    if sha~length \= 64 | verify(sha,'0123456789abcdef') > 0 then raise syntax 93.900 array ('invalid SHA-256 manifest witness')
    if adler~length \= 8 | verify(adler,'0123456789ABCDEF') > 0 then raise syntax 93.900 array ('invalid Adler32 witness')
    item=.directory~new
    item['size']=lengthValue+0
    item['sha256']=sha
    item['adler32']=adler
    entries[zone]=item
    zoneOrder~append(zone)
    if zoneOrder~items > 512 then raise syntax 93.900 array ('too many zones in snapshot')
  end
  unused=stream(filename,'C','CLOSE')
  if \seenEnd | zoneOrder~items < 1 then raise syntax 93.900 array ('incomplete snapshot manifest')
  result=.directory~new
  result['snapshotId']=snapshot
  result['edition']=edition
  result['entries']=entries
  result['zoneOrder']=zoneOrder
  result['integrity']='ADLER32_RUNTIME_SHA256_OFFLINE'
  result['publication']='CREATE_ONLY'
  return result

::method readCheckedZone private
  expose root
  use strict arg snapshot, zone, item
  numeric digits 30
  filename=root || '/' || snapshot || '/zones/' || zone
  file=.stream~new(filename)
  if file~open('read') \== 'READY:' then raise syntax 93.900 array ('snapshot zone missing')
  size=file~query('size')
  if \datatype(size,'W') | size \= item['size'] then do
    file~close
    raise syntax 93.900 array ('snapshot zone size mismatch')
  end
  bytes=file~charin(,size)
  file~close
  if bytes~length \= size then raise syntax 93.900 array ('short snapshot read')
  first=1; second=0
  do i=1 to bytes~length
    first=(first+c2d(substr(bytes,i,1))) // 65521
    second=(second+first) // 65521
  end
  observed=d2x(second*65536+first,8)
  if observed \== item['adler32'] then raise syntax 93.900 array ('snapshot zone checksum mismatch')
  return bytes

::method loadService
  use strict arg snapshot, selectedZones
  if \selectedZones~isA(.Array) | selectedZones~items < 1 | selectedZones~items > 512 then raise syntax 93.900 array ('explicit array of zones required')
  info=self~inspect(snapshot)
  entries=info['entries']
  selected=.directory~new
  service=.SingleTimeService~new
  do zone over selectedZones
    zone=self~checkedZone(zone)
    if selected~hasIndex(zone) then raise syntax 93.900 array ('duplicate requested zone')
    selected[zone]=.true
    if \entries~hasIndex(zone) then raise syntax 93.900 array ('zone absent from snapshot')
    metadata=entries[zone]
    bytes=self~readCheckedZone(snapshot,zone,metadata)
    edition=info['edition'] || '@' || snapshot || '#sha256:' || metadata['sha256']
    provider=.TzifZoneProvider~new('ARCHIVED',edition)
    rules=provider~loadBytes(bytes,zone,'SNAPSHOT:' || snapshot || '/' || zone)
    service~registerZone(rules)
  end
  return service
