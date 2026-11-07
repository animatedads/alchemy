/* Native MPEG-2 Transport Stream (ISO/IEC 13818-1) file model.
 * Container, PSI, PES clock and Annex-B IDR discovery are ooRexx owned.
 * The compressed H.264 video decoder is a separate Foreign Runtime provider.
 * Source ranges are zero-based, timestamps are 90 kHz integer ticks.
 * A one-time complete TS indexing pass is ONLY permitted at the resident MU.
 * A sealed, immutable-version bound sidecar then permits bounded hot jumps.
 * Neither an IDR NAL nor a TS random_access_indicator proves exact decode.
 */
::options digits 30

::class MediaTsWire public
::method packet class
  use strict arg raw
  if raw~length<>188 | substr(raw,1,1)<>x2c('47') then -
    raise syntax 88.900 array('expected 188-byte MPEG-TS packet')
  b1=c2d(substr(raw,2,1)); b2=c2d(substr(raw,3,1))
  b3=c2d(substr(raw,4,1))
  if (b1 % 128) // 2 then raise syntax 88.900 array('TS transport error bit')
  if b3 % 64<>0 then raise syntax 88.900 array("scrambled MPEG-TS packet requires decryption")
  afc=(b3 % 16) // 4
  if afc=0 then raise syntax 88.900 array('TS reserved adaptation control')
  pid=(b1 // 32)*256+b2
  pusi=(b1 % 64) // 2
  where=5
  discontinuity=.false
  if afc=2 | afc=3 then do
    extra=c2d(substr(raw,5,1))
    if extra>183 | 5+extra>188 then -
      raise syntax 88.900 array('TS invalid adaptation size',pid,extra)
    if extra>0 then do
      flags=c2d(substr(raw,6,1))
      discontinuity=((flags % 128) // 2)=1
    end
    where=6+extra
  end
  payload=''
  if (afc=1 | afc=3) & where<=188 then payload=substr(raw,where)
  info=.directory~new
  info['pid']=pid; info['pusi']=pusi; info['continuity']=b3 // 16
  info['payload']=payload
  info['payloadPresent']=(afc=1 | afc=3)
  info['discontinuity']=discontinuity
  return info

::method psiSection class
  use strict arg packets,wantedPid
  if packets~length // 188<>0 then -
    raise syntax 88.900 array('PSI scan requires aligned TS packets')
  section=''; total=0; collecting=.false
  do at=1 to packets~length by 188
    p=self~packet(substr(packets,at,188))
    if p['pid']<>wantedPid | \p['payloadPresent'] then iterate
    data=p['payload']
    if data='' then iterate
    if p['pusi']=1 then do
      pointer=c2d(substr(data,1,1))
      if pointer+1>=data~length then -
        raise syntax 88.900 array('invalid PSI pointer',wantedPid)
      section=substr(data,pointer+2)
      collecting=.true
      total=0
    end
    else do
      if \collecting then iterate
      section=section||data
    end
    if section~length>=3 & total=0 then do
      total=3+(c2d(substr(section,2,1)) // 16)*256+c2d(substr(section,3,1))
      if total<12 | total>4096 then -
        raise syntax 88.900 array('invalid PSI section length',wantedPid,total)
    end
    if total>0 & section~length>=total then do
      section=substr(section,1,total)
      if \self~validPsiCrc(section) then -
        raise syntax 88.900 array('TS PSI CRC invalid',wantedPid)
      return section
    end
  end
  return .nil

::method validPsiCrc class
  use strict arg data
  /* CRC-32/MPEG-2, poly 0x04C11DB7, init FFFFFFFF, xorout zero. */
  crc=4294967295
  do i=1 to data~length
    crc=x2d(c2x(bitxor(d2c(crc,4),substr(data,i,1)||x2c('000000'))))
    do b=1 to 8
      high=crc % 2147483648
      crc=(crc*2) // 4294967296
      if high=1 then crc=x2d(c2x(bitxor(d2c(crc,4),x2c('04C11DB7'))))
    end
  end
  return crc=0

::method pts class
  use strict arg bytes
  if bytes~length<>5 then raise syntax 88.900 array('PES PTS needs five bytes')
  a=c2d(substr(bytes,1,1)); b=c2d(substr(bytes,2,1))
  c=c2d(substr(bytes,3,1)); d=c2d(substr(bytes,4,1))
  e=c2d(substr(bytes,5,1))
  if (a // 2)<>1 | (c // 2)<>1 | (e // 2)<>1 then -
    raise syntax 88.900 array('invalid PTS marker bits')
  return ((a % 2) // 8)*1073741824 + b*4194304 + -
         (c % 2)*32768 + d*128 + e % 2

::method pesInfo class
  use strict arg payload
  if payload~length<14 | substr(payload,1,3)<>x2c('000001') then -
    raise syntax 88.900 array('TS video PES header not present')
  flags=c2d(substr(payload,8,1)) % 64
  headerLength=c2d(substr(payload,9,1))
  if flags<2 | headerLength<5 | 9+headerLength>payload~length then -
    raise syntax 88.900 array('TS PES missing complete PTS')
  p=self~pts(substr(payload,10,5)); d=p
  if flags=3 then do
    if headerLength<10 then raise syntax 88.900 array('PES DTS truncated')
    d=self~pts(substr(payload,15,5))
  end
  info=.directory~new
  info['pts']=p; info['dts']=d
  info['es']=substr(payload,10+headerLength)
  return info

::class MediaTsSeekPlan public
::attribute anchor get
::attribute sourceIdentity get
::attribute requestedTicks get
::attribute byteOffset get
::attribute status get
::attribute timeScale get
::method init
  expose anchor sourceIdentity requestedTicks byteOffset status timeScale
  use strict arg point,identity,ticks
  anchor=point; sourceIdentity=identity; requestedTicks=ticks
  byteOffset=point~byteOffset; timeScale=90000
  status='UNVERIFIED_DECODER_PREROLL'
::method canDecodeExactly
  return .false

::class MediaTsFile public
::attribute source get
::attribute identity get
::attribute sizeBytes get
::attribute packetCount get
::attribute videoPid get
::attribute audioPids get
::attribute videoCodec get
::attribute timeScale get
::attribute indexStatus get
::method init
  expose source identity sizeBytes packetCount videoPid audioPids videoCodec -
         timeScale indexStatus seekIndex accessPoints
  use strict arg byteSource
  source=byteSource; identity=source~sourceIdentity; sizeBytes=source~sizeBytes
  if sizeBytes<564 | sizeBytes // 188<>0 then -
    raise syntax 88.900 array('MPEG-TS must have complete 188-byte packets',sizeBytes)
  timeScale=90000; packetCount=sizeBytes % 188
  do at=0 to 376 by 188
    if source~readAt(at,1)<>x2c('47') then -
      raise syntax 88.900 array('MPEG-TS sync mismatch',at)
  end
  videoPid=-1; videoCodec='UNSUPPORTED'; audioPids=.array~new
  probePackets=min(packetCount,256)
  header=source~readAt(0,probePackets*188)
  if header~length<>probePackets*188 then -
    raise syntax 88.900 array('TS short PSI probe')
  pat=.MediaTsWire~psiSection(header,0)
  if pat==.nil | c2d(substr(pat,1,1))<>0 then -
    raise syntax 88.900 array('TS PAT missing')
  pmtPid=-1
  /* PAT program entries start after the eight-byte PSI prefix. */
  do i=9 to pat~length-7 by 4
    program=x2d(c2x(substr(pat,i,2)))
    if program=0 then iterate
    pmtPid=(c2d(substr(pat,i+2,1)) // 32)*256+c2d(substr(pat,i+3,1))
    leave
  end
  if pmtPid<0 then raise syntax 88.900 array('TS PAT has no program')
  pmt=.MediaTsWire~psiSection(header,pmtPid)
  if pmt==.nil | c2d(substr(pmt,1,1))<>2 then -
    raise syntax 88.900 array('TS PMT missing',pmtPid)
  infoLength=(c2d(substr(pmt,11,1)) // 16)*256+c2d(substr(pmt,12,1))
  at=13+infoLength
  do while at<=pmt~length-8
    streamType=c2d(substr(pmt,at,1))
    pid=(c2d(substr(pmt,at+1,1)) // 32)*256+c2d(substr(pmt,at+2,1))
    esLength=(c2d(substr(pmt,at+3,1)) // 16)*256+c2d(substr(pmt,at+4,1))
    if at+4+esLength>pmt~length-4 then -
      raise syntax 88.900 array('truncated TS PMT elementary stream')
    select
      when streamType=27 & videoPid<0 then do
        videoPid=pid; videoCodec='H264_ANNEXB'
      end
      when streamType=15 | streamType=17 then audioPids~append(pid)
      otherwise nop
    end
    at=at+5+esLength
  end
  if videoPid<0 then raise syntax 88.900 array('no H.264 video PID found')
  indexStatus='NOT_INDEXED'
  seekIndex=.nil; accessPoints=.array~new
::method accessPointCount
  expose accessPoints
  return accessPoints~items
::method verifySource private
  expose source identity sizeBytes
  if source~sourceIdentity<>identity | source~sizeBytes<>sizeBytes then -
    raise syntax 88.900 array('MPEG-TS source identity/size changed')
::method addPoint private
  expose seekIndex accessPoints sizeBytes
  use strict arg pts,dts,offset,ordinal
  if offset<0 | offset>=sizeBytes | offset // 188<>0 then -
    raise syntax 88.900 array('invalid TS PES anchor location',offset)
  if accessPoints~items>0 then do
    previous=accessPoints[accessPoints~items]~presentationTicks
    if pts<=previous then raise syntax 88.900 array('TS PTS wrap or discontinuity requires segmented index')
  end
  point=.MediaAccessPoint~new(pts,dts,offset,ordinal,0)
  seekIndex~addAccessPoint(point)
  accessPoints~append(point)
::method buildIndexLocal
  expose source identity sizeBytes videoPid seekIndex accessPoints indexStatus
  /* Explicit permission prevents accidental 1 GiB downloads over Fabric.
   * Run ONLY near resident source, then persist the compact index atomically. */
  use strict arg residentAuthorized,maxScanBytes
  self~verifySource
  if residentAuthorized<>.true then raise syntax 88.900 array('TS full scan requires resident-node authority')
  if \datatype(maxScanBytes,'W') | maxScanBytes<sizeBytes then -
    raise syntax 88.900 array('TS index build exceeds explicit local byte budget',sizeBytes,maxScanBytes)
  seekIndex=.MediaSeekIndex~new(identity,videoPid,90000)
  accessPoints=.array~new; indexStatus='BUILDING'
  currentPts=.nil; currentDts=.nil; currentOffset=-1
  currentIDR=.false; carry=''; ordinal=0
  previousCc=-1
  do base=0 to sizeBytes-1 by 48128
    n=min(48128,sizeBytes-base)
    bytes=source~readAt(base,n)
    if bytes~length<>n then raise syntax 88.900 array('short resident TS scan',base,n)
    do relative=1 to n by 188
      offset=base+relative-1
      packet=.MediaTsWire~packet(substr(bytes,relative,188))
      if packet['pid']<>videoPid then iterate
      if packet['discontinuity'] then raise syntax 88.900 array('TS video discontinuity; index segment first',offset)
      if packet['payloadPresent'] & packet['payload']<>'' then do
        if previousCc>=0 & packet['continuity']<>((previousCc+1) // 16) then -
          raise syntax 88.900 array('TS video continuity error',offset)
        previousCc=packet['continuity']
      end
      data=packet['payload']
      if data='' then iterate
      if packet['pusi']=1 then do
        if currentPts<>.nil & currentIDR then -
          self~addPoint(currentPts,currentDts,currentOffset,ordinal)
        ordinal=ordinal+1
        pes=.MediaTsWire~pesInfo(data)
        currentPts=pes['pts']; currentDts=pes['dts']; currentOffset=offset
        currentIDR=.false; carry=''; data=pes['es']
      end
      if currentPts==.nil | data='' then iterate
      candidate=carry||data
      seekAt=1
      do forever
        posAt=pos(x2c('000001'),candidate,seekAt)
        if posAt=0 | posAt+3>candidate~length then leave
        nalType=c2d(substr(candidate,posAt+3,1)) // 32
        if nalType=5 then currentIDR=.true
        seekAt=posAt+3
      end
      carry=right(candidate,min(4,candidate~length))
    end
  end
  if currentPts<>.nil & currentIDR then -
    self~addPoint(currentPts,currentDts,currentOffset,ordinal)
  seekIndex~seal
  indexStatus='IDR_CANDIDATES_ONLY'
  return accessPoints~items
::method planTime
  expose seekIndex indexStatus identity
  use strict arg ticks
  self~verifySource
  if indexStatus<>'IDR_CANDIDATES_ONLY' then -
    raise syntax 88.900 array('TS index not loaded/sealed')
  point=seekIndex~atOrBefore(ticks)
  if point==.nil then return .nil
  return .MediaTsSeekPlan~new(point,identity,ticks)
::method planBoundedRange
  expose sizeBytes
  use strict arg ticks,budgetBytes=2097152
  if \datatype(budgetBytes,'W') | budgetBytes<188 | budgetBytes>16777216 then -
    raise syntax 88.900 array('TS seek transfer budget must be 188..16777216')
  plan=self~planTime(ticks)
  if plan==.nil then return .nil
  out=.directory~new
  out['offset']=plan~byteOffset
  out['bytes']=min(budgetBytes,sizeBytes-plan~byteOffset)
  out['status']=plan~status
  out['sourceIdentity']=plan~sourceIdentity
  out['targetTicks']=ticks
  return out
::method exportIndexText
  expose indexStatus identity sizeBytes videoPid accessPoints
  self~verifySource
  if indexStatus<>'IDR_CANDIDATES_ONLY' then raise syntax 88.900 array('TS index is not complete')
  eol='0a'x
  out='MTSIDX|1'||eol||'IDENTITY|'||c2x(identity)||eol|| -
      'SIZE|'||sizeBytes||eol||'VIDEO_PID|'||videoPid||eol|| -
      'TIMESCALE|90000'||eol||'COUNT|'||accessPoints~items||eol
  do point over accessPoints
    out=out||'P|'||point~presentationTicks||'|'||point~decodeTicks||'|'|| -
      point~byteOffset||'|'||point~sampleOrdinal||eol
  end
  return out||'END'||eol
::method loadIndexText
  expose seekIndex accessPoints indexStatus identity sizeBytes videoPid
  use strict arg manifest
  self~verifySource
  remaining=manifest
  parse var remaining line '0a'x remaining
  if line<>'MTSIDX|1' then raise syntax 88.900 array('unknown TS index revision')
  parse var remaining line '0a'x remaining
  if line<>'IDENTITY|'||c2x(identity) then -
    raise syntax 88.900 array('stale TS index source identity')
  parse var remaining line '0a'x remaining
  if line<>'SIZE|'||sizeBytes then raise syntax 88.900 array('stale TS index source size')
  parse var remaining line '0a'x remaining
  if line<>'VIDEO_PID|'||videoPid then raise syntax 88.900 array('TS index video PID changed')
  parse var remaining line '0a'x remaining
  if line<>'TIMESCALE|90000' then raise syntax 88.900 array('TS index timebase mismatch')
  parse var remaining line '0a'x remaining
  parse var line 'COUNT|' count
  if \datatype(count,'W') | count<1 | count>10000000 then -
    raise syntax 88.900 array('TS index invalid candidate count')
  tempIndex=.MediaSeekIndex~new(identity,videoPid,90000)
  tempPoints=.array~new
  do i=1 to count
    parse var remaining line '0a'x remaining
    parse var line 'P|' pts '|' dts '|' offset '|' ordinal
    if \datatype(pts,'W') | \datatype(dts,'W') | -
       \datatype(offset,'W') | \datatype(ordinal,'W') then -
      raise syntax 88.900 array('TS index has malformed point',i)
    if offset<0 | offset>=sizeBytes | offset // 188<>0 | ordinal<1 then -
      raise syntax 88.900 array('TS index point outside source',i)
    point=.MediaAccessPoint~new(pts,dts,offset,ordinal)
    tempIndex~addAccessPoint(point)
    tempPoints~append(point)
  end
  parse var remaining line '0a'x remaining
  if line<>'END' | remaining<>'' then raise syntax 88.900 array('TS index truncated or has trailing content')
  tempIndex~seal
  seekIndex=tempIndex; accessPoints=tempPoints
  indexStatus='IDR_CANDIDATES_ONLY'
  return count
::method seekTime
  use strict arg ticks,mode='EXACT'
  raise syntax 88.900 array('TS decoded-frame seek requires qualified native H264 provider',ticks,mode)
::requires 'MediaSeekIndex.cls'