/* Media byte access, separate from codecs and file formats.
 * Zero-based offsets, immutable-source identity, bounded absolute reads.
 * Storage Fabric remains owner of replica selection, transport and leases.
 */
::options digits 30

::class MediaByteSource public
::method sizeBytes abstract
::method sourceIdentity abstract
::method readAt abstract

/* Adapts the existing LazyReadFile object. The caller owns its lifetime.
 * A selected block size on LazyReadFile bounds individual reads. */
::class MediaLazyReadSource subclass MediaByteSource public
::method init
  expose lazy
  use strict arg lazyArg
  lazy=lazyArg
::method sizeBytes
  expose lazy
  return lazy~sizeBytes
::method sourceIdentity
  expose lazy
  return lazy~identity
::method readAt
  expose lazy
  use strict arg offset,count
  return lazy~loadPartial(offset,count)

/* Adapts StorageByteSource.openAt/readChunk/close without adding a new
 * transport. Serialized access only: callers must not share one adapter among
 * concurrent cursors. One request is capped to avoid whole-object fetches. */
::class MediaStorageRangeSource subclass MediaByteSource public
::attribute maximumRead get
::method init
  expose source maximumRead
  use strict arg sourceArg,maximumArg=65536
  source=sourceArg
  if datatype(maximumArg,'W')=0 | maximumArg<1 | maximumArg>1048576 then -
    raise syntax 88.900 array('invalid maximum media read',maximumArg)
  maximumRead=maximumArg
::method sizeBytes
  expose source
  return source~sizeBytes
::method sourceIdentity
  expose source
  return source~resumeIdentity
::method readAt
  expose source maximumRead
  use strict arg offset,count
  if datatype(offset,'W')=0 | datatype(count,'W')=0 then -
    raise syntax 88.900 array('absolute media reads require whole numbers')
  if offset<0 | count<0 | count>maximumRead | offset+count>self~sizeBytes then -
    raise syntax 88.900 array('media range outside source/budget',offset,count)
  if count=0 then return ''
  output=''; leftBytes=count
  source~openAt(offset)
  do while leftBytes>0
    piece=source~readChunk(leftBytes)
    data=piece~data
    if data~length<1 | data~length>leftBytes then -
      raise syntax 88.900 array('short or invalid storage source progress',offset,count)
    output=output||data
    leftBytes=leftBytes-data~length
  end
  source~close
  return output
