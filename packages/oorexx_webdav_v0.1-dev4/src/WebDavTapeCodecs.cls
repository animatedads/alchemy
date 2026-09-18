/* Hercules-compatible AWSTAPE/HET representation codecs.
 * Canonical authority remains StorageSequentialMedia TAPE_VOLUME.
 *
 * AWSTAPE/HET headers are six bytes:
 *   current chunk length LE16
 *   previous chunk length LE16
 *   flags1
 *   flags2
 *
 * This package implements plain AWSTAPE and uncompressed HET.  HET
 * compression flags are recognised and rejected unless/until a real
 * compression provider is installed; compressed bytes are never mistaken
 * for canonical tape blocks.
 */
::class WebDavTapeFormat public
::constant AWSTAPE "AWSTAPE"
::constant HET "HET"
::constant AWSTAPE_TYPE "application/vnd.hercules.awstape"
::constant HET_TYPE "application/vnd.hercules.het"

::class WebDavTapeHeader public
::constant NEWREC 128
::constant TAPEMARK 64
::constant ENDREC 32
::constant HET_COMPRESS_MASK 3
::constant HET_BZLIB 2
::constant HET_ZLIB 1
::constant HET_FLAGS2_COMPRESS 128
::method le16 class
  use arg nArg
  n=nArg+0
  if n<0 | n>65535 then raise syntax 88.900 array("16-bit tape length out of range")
  return d2c(n//256)||d2c(n%256)
::method fromLe16 class
  use arg sArg
  s=sArg~string
  if s~length<>2 then raise syntax 88.900 array("two-byte tape length required")
  return c2d(s~substr(1,1)) + (256*c2d(s~substr(2,1)))
::method hasFlag class
  use arg flagsArg, maskArg
  return bitand(d2c(flagsArg+0),d2c(maskArg+0))<>"00"x
::method make class
  use arg currentArg, previousArg, flags1Arg, flags2Arg=0
  return self~le16(currentArg)||self~le16(previousArg)||d2c(flags1Arg+0)||d2c(flags2Arg+0)

::class WebDavAwsTapeCodec public
::method render class
  use arg tapeArg
  self~validateTape(tapeArg)
  out=""; previous=0
  do r over tapeArg~records
    if r~kind=.StorageSequentialMediaRecordKind~FILEMARK then do
      out=out||.WebDavTapeHeader~make(0,previous,.WebDavTapeHeader~TAPEMARK,0)
      previous=0
    end
    else if r~kind=.StorageSequentialMediaRecordKind~DATA then do
      n=r~data~length
      /* Hercules AWSTAPE writer uses one 16-bit chunk per record. Fail rather
       * than inventing segmentation for a block the target cannot write. */
      if n>65535 then raise syntax 88.900 array("AWSTAPE block exceeds 65535 bytes")
      flags=.WebDavTapeHeader~NEWREC+.WebDavTapeHeader~ENDREC
      out=out||.WebDavTapeHeader~make(n,previous,flags,0)||r~data
      previous=n
    end
    else raise syntax 88.900 array("invalid record kind in canonical tape")
  end
  return out
::method parse class
  use arg mediaIdArg, bytesArg, sourceRefArg=.nil
  bytes=bytesArg~string; p=1; previous=0
  tape=.StorageTapeVolumeCodec~newVolume(mediaIdArg,.StorageSequentialMediaEncoding~BINARY,sourceRefArg)
  do while p<=bytes~length
    if bytes~length-p+1<6 then raise syntax 88.900 array("truncated AWSTAPE header")
    cur=.WebDavTapeHeader~fromLe16(bytes~substr(p,2))
    prv=.WebDavTapeHeader~fromLe16(bytes~substr(p+2,2))
    f1=c2d(bytes~substr(p+4,1)); f2=c2d(bytes~substr(p+5,1)); p+=6
    if f2<>0 then raise syntax 88.900 array("unsupported AWSTAPE flags2")
    if prv<>previous then raise syntax 88.900 array("AWSTAPE previous-length chain mismatch")
    isMark=.WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~TAPEMARK)
    if isMark then do
      if cur<>0 then raise syntax 88.900 array("AWSTAPE tapemark must have zero length")
      .StorageTapeVolumeCodec~filemark(tape); previous=0
      iterate
    end
    if \.WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~NEWREC) | \.WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~ENDREC) then
      raise syntax 88.900 array("segmented AWSTAPE record not supported by this codec")
    if bytes~length-p+1<cur then raise syntax 88.900 array("truncated AWSTAPE data block")
    data=bytes~substr(p,cur); p+=cur
    .StorageTapeVolumeCodec~addBlock(tape,data)
    previous=cur
  end
  return tape
::method validateTape class private
  use arg tapeArg
  if tapeArg==.nil | tapeArg~family<>.StorageSequentialMediaFamily~TAPE_VOLUME then raise syntax 88.900 array("canonical tape volume required")
  return .true

::class WebDavHetTapeCodec public subclass WebDavAwsTapeCodec
::method render class
  use arg tapeArg
  /* A no-compression HET stream uses the HET header/chunk contract with zero
   * compression bits. Keep HET separate from AWS so compressed support can be
   * injected later without changing DAV representation dispatch. */
  self~validateTape(tapeArg)
  out=""; previous=0
  do r over tapeArg~records
    if r~kind=.StorageSequentialMediaRecordKind~FILEMARK then do
      out=out||.WebDavTapeHeader~make(0,previous,.WebDavTapeHeader~TAPEMARK,0); previous=0
    end
    else if r~kind=.StorageSequentialMediaRecordKind~DATA then do
      data=r~data; total=data~length
      if total=0 then raise syntax 88.900 array("zero-length HET data record is ambiguous with tape mark")
      offset=1; first=.true
      do while offset<=total
        n=total-offset+1; if n>65535 then n=65535
        flags=0
        if first then flags+=.WebDavTapeHeader~NEWREC
        if offset+n-1=total then flags+=.WebDavTapeHeader~ENDREC
        out=out||.WebDavTapeHeader~make(n,previous,flags,0)||data~substr(offset,n)
        previous=n; offset+=n; first=.false
      end
    end
    else raise syntax 88.900 array("invalid record kind in canonical tape")
  end
  return out
::method parse class
  use arg mediaIdArg, bytesArg, sourceRefArg=.nil
  bytes=bytesArg~string; p=1; previous=0; assembling=""; inRecord=.false
  tape=.StorageTapeVolumeCodec~newVolume(mediaIdArg,.StorageSequentialMediaEncoding~BINARY,sourceRefArg)
  do while p<=bytes~length
    if bytes~length-p+1<6 then raise syntax 88.900 array("truncated HET header")
    cur=.WebDavTapeHeader~fromLe16(bytes~substr(p,2)); prv=.WebDavTapeHeader~fromLe16(bytes~substr(p+2,2))
    f1=c2d(bytes~substr(p+4,1)); f2=c2d(bytes~substr(p+5,1)); p+=6
    if prv<>previous then raise syntax 88.900 array("HET previous-length chain mismatch")
    if .WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~HET_ZLIB) | .WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~HET_BZLIB) | .WebDavTapeHeader~hasFlag(f2,.WebDavTapeHeader~HET_FLAGS2_COMPRESS) then
      raise syntax 88.900 array("compressed HET requires an explicit compression codec provider")
    if .WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~TAPEMARK) then do
      if cur<>0 | inRecord then raise syntax 88.900 array("invalid HET tapemark placement")
      .StorageTapeVolumeCodec~filemark(tape); previous=0; iterate
    end
    bor=.WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~NEWREC)
    eor=.WebDavTapeHeader~hasFlag(f1,.WebDavTapeHeader~ENDREC)
    if \inRecord & \bor then raise syntax 88.900 array("HET beginning-of-record flag missing")
    if inRecord & bor then raise syntax 88.900 array("unexpected HET beginning-of-record flag")
    if bytes~length-p+1<cur then raise syntax 88.900 array("truncated HET chunk")
    if bor then do; assembling=""; inRecord=.true; end
    assembling=assembling||bytes~substr(p,cur); p+=cur; previous=cur
    if eor then do
      .StorageTapeVolumeCodec~addBlock(tape,assembling); assembling=""; inRecord=.false
    end
  end
  if inRecord then raise syntax 88.900 array("unterminated HET record")
  return tape
::method validateTape class private
  use arg tapeArg
  if tapeArg==.nil | tapeArg~family<>.StorageSequentialMediaFamily~TAPE_VOLUME then raise syntax 88.900 array("canonical tape volume required")
  return .true

::requires 'StorageSequentialMedia.cls'
