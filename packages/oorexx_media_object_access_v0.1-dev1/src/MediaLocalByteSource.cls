/* Local, bounded file adapter for tests and resident-MU reads.
 * NOT a cross-node immutable Storage Fabric identity: use a pinned
 * MediaStorageRangeSource for distributed index/cache operations.
 */
::options digits 30
::class MediaLocalByteSource subclass MediaByteSource public
::attribute path get
::method init
  expose path bytes identity
  use strict arg filename
  path=filename
  bytes=stream(path,'C','QUERY SIZE')
  if datatype(bytes,'W')=0 | bytes<0 then -
    raise syntax 88.900 array('cannot query local file',path)
  state=stream(path,'C','OPEN READ')
  if left(state,5)<>'READY' then raise syntax 88.900 array('cannot open local media source',path,state)
  identity='LOCAL_ONLY:'||path||':'||bytes
::method sizeBytes
  expose bytes
  return bytes
::method sourceIdentity
  expose identity
  return identity
::method readAt
  expose path bytes
  use strict arg offset,count
  if \datatype(offset,'W') | \datatype(count,'W') | -
     offset<0 | count<0 | count>65536 | offset+count>bytes then -
    raise syntax 88.900 array('local bounded read invalid',offset,count,bytes)
  if count=0 then return ''
  data=charin(path,offset+1,count)
  if data~length<>count then raise syntax 88.900 array('short local media read',offset,count)
  return data
::method close
  expose path
  ignored=stream(path,'C','CLOSE')
  return self
::requires 'MediaByteSource.cls'