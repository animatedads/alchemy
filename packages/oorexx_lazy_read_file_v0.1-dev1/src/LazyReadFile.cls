/* ooRexx Lazy Read File v0.1-dev1
 *
 * A tiny, read-only, block-lazy file object for very large local files.
 *
 * Design invariants:
 *   - file offsets are zero-based at this API boundary;
 *   - arithmetic is performed with enough decimal precision for 64-bit offsets;
 *   - at most one aligned source block is retained by the object;
 *   - no read/loadPartial request may exceed blockBytes;
 *   - release() drops the object's strong reference to cached file data;
 *   - no write methods are provided.
 */

::class LazyReadFileBuild public
::constant VERSION "0.1-dev1"
::constant API "lazy.read.file/0.1"
::constant DEFAULT_BLOCK_BYTES 8388608

::class LazyReadFile public
::attribute path get
::attribute sizeBytes get
::attribute blockBytes get
::attribute position get
::attribute opened get
::attribute blocksLoaded get
::attribute cacheHits get

::method init
  expose path sizeBytes blockBytes position opened cacheData cacheStart cacheBytes cacheValid blocksLoaded cacheHits canonicalPath source
  numeric digits 20
  use arg pathArg, blockArg

  path=pathArg~string
  if path="" then raise syntax 88.900 array("path must not be empty")

  if arg(2,"O") then blockBytes=.LazyReadFileBuild~DEFAULT_BLOCK_BYTES
  else blockBytes=blockArg+0
  if datatype(blockBytes,"W")=0 | blockBytes<1 then raise syntax 88.900 array("block size must be a positive whole number",blockArg)

  source=.Stream~new(path)
  canonicalPath=source~query("exists")
  if canonicalPath="" then raise syntax 88.900 array("file does not exist",path)

  qsize=source~query("size")
  if datatype(qsize,"N")=0 then raise syntax 88.900 array("file size is unavailable",path)
  sizeBytes=qsize+0
  if sizeBytes<0 then raise syntax 88.900 array("file size is invalid",path,qsize)

  answer=source~open("read")
  if left(answer,6)<>"READY:" then raise syntax 88.900 array("cannot open file for read",path,answer)

  position=0
  opened=.true
  cacheData=""
  cacheStart=-1
  cacheBytes=0
  cacheValid=.false
  blocksLoaded=0
  cacheHits=0

::method identity
  expose canonicalPath sizeBytes
  numeric digits 20
  return "LAZY_READ_FILE|"||canonicalPath||"|"||sizeBytes

::method tell
  expose position
  numeric digits 20
  return position

::method eof
  expose position sizeBytes
  numeric digits 20
  return position>=sizeBytes

::method remaining
  expose position sizeBytes
  numeric digits 20
  n=sizeBytes-position
  if n<0 then n=0
  return n

::method seek
  expose position sizeBytes opened
  numeric digits 20
  use arg offsetArg
  self~requireOpen
  offset=offsetArg+0
  if datatype(offset,"W")=0 | offset<0 | offset>sizeBytes then raise syntax 88.900 array("seek offset outside file",offsetArg,sizeBytes)
  position=offset
  return self

::method rewind
  expose position opened
  self~requireOpen
  position=0
  return self

::method skip
  expose position sizeBytes opened
  numeric digits 20
  use arg deltaArg
  self~requireOpen
  delta=deltaArg+0
  if datatype(delta,"N")=0 then raise syntax 88.900 array("skip delta must be numeric",deltaArg)
  target=position+delta
  if datatype(target,"W")=0 | target<0 | target>sizeBytes then raise syntax 88.900 array("skip target outside file",target,sizeBytes)
  position=target
  return self

/* Absolute finite read.  Offset is zero-based and does not alter the cursor.
 * To preserve the bounded-memory contract, bytes may not exceed blockBytes. */
::method loadPartial
  expose sizeBytes blockBytes cacheData cacheStart cacheBytes cacheValid opened cacheHits
  numeric digits 20
  use arg offsetArg, bytesArg
  self~requireOpen

  offset=offsetArg+0
  if datatype(offset,"W")=0 | offset<0 | offset>sizeBytes then raise syntax 88.900 array("read offset outside file",offsetArg,sizeBytes)

  if arg(2,"O") then requested=blockBytes
  else requested=bytesArg+0
  if datatype(requested,"W")=0 | requested<0 then raise syntax 88.900 array("read size must be a non-negative whole number",bytesArg)
  if requested>blockBytes then raise syntax 88.900 array("read exceeds bounded block size",requested,blockBytes)
  if requested=0 | offset>=sizeBytes then return ""

  wanted=requested
  remainingFile=sizeBytes-offset
  if wanted>remainingFile then wanted=remainingFile

  /* Fast path: requested bytes already reside in the retained block. */
  if cacheValid then do
    cacheEnd=cacheStart+cacheBytes
    if offset>=cacheStart & offset+wanted<=cacheEnd then do
      cacheHits+=1
      if offset=cacheStart & wanted=cacheBytes then return cacheData
      return substr(cacheData,offset-cacheStart+1,wanted)
    end
  end

  /* General path can cross one aligned boundary.  Since wanted<=blockBytes,
   * no request ever needs data from more than two source blocks. */
  output=""
  current=offset
  leftToRead=wanted
  do while leftToRead>0
    self~ensureBlock(current)
    within=current-cacheStart
    available=cacheBytes-within
    take=leftToRead
    if take>available then take=available
    if take<1 then raise syntax 88.900 array("internal zero-progress read",current,cacheStart,cacheBytes)

    if within=0 & take=cacheBytes & output="" & take=wanted then return cacheData
    output=output||substr(cacheData,within+1,take)
    current+=take
    leftToRead-=take
  end
  return output

/* Cursor-relative bounded read, analogous to CHARIN but zero-based internally. */
::method read
  expose position blockBytes opened
  numeric digits 20
  use arg bytesArg
  self~requireOpen
  if arg(1,"O") then requested=blockBytes
  else requested=bytesArg+0
  data=self~loadPartial(position,requested)
  position+=data~length
  return data

::method nextBlock
  expose blockBytes
  return self~read(blockBytes)

::method byteAt
  numeric digits 20
  use arg offsetArg
  return self~loadPartial(offsetArg,1)

/* Drop the object's retained block.  Any String still held by the caller is
 * naturally still live; release() cannot invalidate another object's reference. */
::method release
  expose cacheData cacheStart cacheBytes cacheValid
  cacheData=""
  cacheStart=-1
  cacheBytes=0
  cacheValid=.false
  return self

::method cachedBytes
  expose cacheBytes cacheValid
  if cacheValid then return cacheBytes
  return 0

::method cachedOffset
  expose cacheStart cacheValid
  numeric digits 20
  if cacheValid then return cacheStart
  return -1

::method close
  expose source opened
  if opened then do
    self~release
    source~close
    opened=.false
  end
  return self

::method ensureBlock private
  expose path source sizeBytes blockBytes cacheData cacheStart cacheBytes cacheValid blocksLoaded cacheHits opened
  numeric digits 20
  use arg offsetArg
  self~requireOpen
  offset=offsetArg+0
  if offset<0 | offset>=sizeBytes then raise syntax 88.900 array("block offset outside readable file",offset,sizeBytes)

  if cacheValid then do
    if offset>=cacheStart & offset<cacheStart+cacheBytes then do
      cacheHits+=1
      return
    end
  end

  base=offset-(offset//blockBytes)
  want=blockBytes
  remain=sizeBytes-base
  if want>remain then want=remain

  data=source~charin(base+1,want)
  got=data~length
  if got<>want then raise syntax 88.900 array("short file read",path,base,want,got)

  /* Assignment replaces the previous retained String. */
  cacheData=data
  cacheStart=base
  cacheBytes=got
  cacheValid=.true
  blocksLoaded+=1

::method requireOpen private
  expose opened
  if \opened then raise syntax 88.900 array("file is closed")
