/* Small bounded read-through cache for arbitrary MediaByteSource instances.
 * Zero-based absolute offsets. No eager file download or sequential prefetch.
 * Not a replacement for Storage Fabric's replica selection or native cache.
 * The source must provide a stable version/content identity to prevent stale
 * blocks after mutation.
 */
::options digits 30
::class MediaRangeCacheSource subclass MediaByteSource public
::attribute blockBytes get
::attribute maxBlocks get
::attribute cacheHits get
::attribute cacheMisses get
::attribute bytesFetched get
::attribute blocksRetained get
::method init
  expose source identity fileBytes blockBytes maxBlocks entries cacheHits cacheMisses -
         bytesFetched blocksRetained clock
  use strict arg sourceArg,blockArg=16384,blocksArg=16
  source=sourceArg
  if datatype(blockArg,'W')=0 | datatype(blocksArg,'W')=0 | -
     blockArg<1 | blockArg>65536 | blocksArg<1 | blockArg*blocksArg>4194304 then -
    raise syntax 88.900 array('invalid bounded media cache budget',blockArg,blocksArg)
  blockBytes=blockArg; maxBlocks=blocksArg
  identity=source~sourceIdentity
  fileBytes=source~sizeBytes
  if datatype(fileBytes,'W')=0 | fileBytes<0 then -
    raise syntax 88.900 array('invalid cached media source size')
  entries=.directory~new
  cacheHits=0; cacheMisses=0; bytesFetched=0; blocksRetained=0; clock=0
::method sourceIdentity
  expose identity
  self~verifySource
  return identity
::method sizeBytes
  expose fileBytes
  self~verifySource
  return fileBytes
::method verifySource private
  expose source identity fileBytes
  if source~sourceIdentity<>identity | source~sizeBytes<>fileBytes then -
    raise syntax 88.900 array('cached media source identity has changed')
::method readAt
  expose blockBytes fileBytes
  use strict arg offset,count
  self~verifySource
  if datatype(offset,'W')=0 | datatype(count,'W')=0 | -
     offset<0 | count<0 | offset+count>fileBytes | count>4194304 then -
    raise syntax 88.900 array('bounded cache read outside source or budget',offset,count)
  if count=0 then return ''
  out=''; current=offset; leftBytes=count
  do while leftBytes>0
    base=current-(current//blockBytes)
    block=self~blockAt(base)
    within=current-base
    take=min(leftBytes,block~length-within)
    if take<1 then raise syntax 88.900 array('cache zero-progress read')
    out=out||substr(block,within+1,take)
    current=current+take
    leftBytes=leftBytes-take
  end
  return out
::method blockAt private
  expose source entries blockBytes fileBytes maxBlocks blocksRetained -
         cacheHits cacheMisses bytesFetched clock
  use strict arg base
  self~verifySource
  key='B'||base
  clock=clock+1
  if entries~hasIndex(key) then do
    record=entries[key]
    record['TOUCH']=clock
    cacheHits=cacheHits+1
    return record['DATA']
  end
  want=min(blockBytes,fileBytes-base)
  data=source~readAt(base,want)
  if data~length<>want then -
    raise syntax 88.900 array('short or invalid cached media range',base,want,data~length)
  cacheMisses=cacheMisses+1; bytesFetched=bytesFetched+want
  if blocksRetained>=maxBlocks then do
    keys=entries~allIndexes
    oldest=clock+1; victim=''
    do i=1 to keys~items
      k=keys[i]
      entry=entries[k]
      if entry['TOUCH']<oldest then do
        oldest=entry['TOUCH']; victim=k
      end
    end
    if victim='' then raise syntax 88.900 array('cache eviction failed')
    discard=entries~remove(victim)
    blocksRetained=blocksRetained-1
  end
  record=.directory~new
  record['DATA']=data; record['TOUCH']=clock
  entries[key]=record
  blocksRetained=blocksRetained+1
  return data
::method release
  expose entries blocksRetained
  entries=.directory~new
  blocksRetained=0
  return self
