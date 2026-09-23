/* ooRexx SFTP v0.1-dev1
 * Server-side SFTP v3 protocol engine designed to terminate in Rexx space.
 * SSH encryption/channel ownership belongs to oorexx_ssh + Foreign Runtime.
 */

::class SftpTypes public
::method INIT class; return 1
::method VERSION class; return 2
::method OPEN class; return 3
::method CLOSE class; return 4
::method READ class; return 5
::method WRITE class; return 6
::method LSTAT class; return 7
::method FSTAT class; return 8
::method SETSTAT class; return 9
::method FSETSTAT class; return 10
::method OPENDIR class; return 11
::method READDIR class; return 12
::method REMOVE class; return 13
::method MKDIR class; return 14
::method RMDIR class; return 15
::method REALPATH class; return 16
::method STAT class; return 17
::method RENAME class; return 18
::method READLINK class; return 19
::method SYMLINK class; return 20
::method STATUS class; return 101
::method HANDLE class; return 102
::method DATA class; return 103
::method NAME class; return 104
::method ATTRS class; return 105
::method EXTENDED class; return 200
::method EXTENDED_REPLY class; return 201

::class SftpStatusCodes public
::method OK class; return 0
::method EOF class; return 1
::method NO_SUCH_FILE class; return 2
::method PERMISSION_DENIED class; return 3
::method FAILURE class; return 4
::method BAD_MESSAGE class; return 5
::method NO_CONNECTION class; return 6
::method CONNECTION_LOST class; return 7
::method OP_UNSUPPORTED class; return 8

::class SftpOpenFlags public
::method READ class; return 1
::method WRITE class; return 2
::method APPEND class; return 4
::method CREAT class; return 8
::method TRUNC class; return 16
::method EXCL class; return 32
::method has class
  use strict arg value, mask
  numeric digits 20
  return c2d(d2c(value,4)~bitand(d2c(mask,4))) <> 0

::class SftpCodec public
::method u32 class
  use strict arg n
  numeric digits 20
  if n<0 | n>4294967295 then raise syntax 88.900 array('SFTP u32 out of range',n)
  return d2c(n,4)
::method u64 class
  use strict arg n
  numeric digits 30
  if n<0 | n>18446744073709551615 then raise syntax 88.900 array('SFTP u64 out of range',n)
  hi=n % 4294967296
  lo=n // 4294967296
  return d2c(hi,4)||d2c(lo,4)
::method readU32 class
  use strict arg data, offset
  numeric digits 20
  if offset<1 | offset+3>length(data) then raise syntax 88.900 array('Truncated SFTP u32')
  return c2d(substr(data,offset,4))
::method readU64 class
  use strict arg data, offset
  numeric digits 30
  if offset<1 | offset+7>length(data) then raise syntax 88.900 array('Truncated SFTP u64')
  return c2d(substr(data,offset,4))*4294967296 + c2d(substr(data,offset+4,4))
::method string class
  use strict arg value
  value=value~string
  return self~u32(length(value))||value
::method readString class
  use strict arg data, offset
  n=self~readU32(data,offset)
  start=offset+4
  if start+n-1>length(data) then raise syntax 88.900 array('Truncated SFTP string')
  d=.directory~new
  d['value']=substr(data,start,n)
  d['next']=start+n
  return d
::method frame class
  use strict arg payload
  return self~u32(length(payload))||payload
::method payload class
  use strict arg frame
  if length(frame)<4 then raise syntax 88.900 array('Truncated SFTP frame length')
  n=self~readU32(frame,1)
  if n>16777216 then raise syntax 88.900 array('SFTP frame exceeds dev1 bound',n)
  if length(frame)<>n+4 then raise syntax 88.900 array('SFTP frame length mismatch',n,length(frame)-4)
  return substr(frame,5,n)
::method request class
  use strict arg frame
  p=self~payload(frame)
  if length(p)<1 then raise syntax 88.900 array('Empty SFTP packet')
  d=.directory~new
  d['type']=c2d(substr(p,1,1))
  if d['type']=.SftpTypes~INIT then do
    if length(p)<5 then raise syntax 88.900 array('Truncated SFTP INIT')
    d['version']=self~readU32(p,2)
    d['body_offset']=6
  end
  else do
    if length(p)<5 then raise syntax 88.900 array('Truncated SFTP request id')
    d['id']=self~readU32(p,2)
    d['body_offset']=6
  end
  d['payload']=p
  return d
::method response class
  use strict arg type, id, body=''
  p=d2c(type,1)||self~u32(id)||body
  return self~frame(p)
::method versionResponse class
  use strict arg version=3
  return self~frame(d2c(.SftpTypes~VERSION,1)||self~u32(version))
::method status class
  use strict arg id, code, message='', language=''
  return self~response(.SftpTypes~STATUS,id,self~u32(code)||self~string(message)||self~string(language))
::method handle class
  use strict arg id, handle
  return self~response(.SftpTypes~HANDLE,id,self~string(handle))
::method data class
  use strict arg id, data
  return self~response(.SftpTypes~DATA,id,self~string(data))
::method attrs class
  use strict arg id, attrs
  return self~response(.SftpTypes~ATTRS,id,self~encodeAttrs(attrs))
::method name class
  use strict arg id, entries
  body=self~u32(entries~items)
  do entry over entries
    filename=entry['filename']
    longname=entry['longname']
    if longname==.nil then longname=filename
    attrs=entry['attrs']
    if attrs==.nil then attrs=.directory~new
    body=body||self~string(filename)||self~string(longname)||self~encodeAttrs(attrs)
  end
  return self~response(.SftpTypes~NAME,id,body)
::method encodeAttrs class
  use strict arg attrs
  numeric digits 30
  flags=0; body=''
  if attrs~hasIndex('size') then do
    flags=flags+1
    body=body||self~u64(attrs['size'])
  end
  if attrs~hasIndex('permissions') then do
    flags=flags+4
    body=body||self~u32(attrs['permissions'])
  end
  if attrs~hasIndex('atime') & attrs~hasIndex('mtime') then do
    flags=flags+8
    body=body||self~u32(attrs['atime'])||self~u32(attrs['mtime'])
  end
  return self~u32(flags)||body

::class SftpPath public
::method canonical class
  use strict arg path
  if pos('00'x,path)>0 then raise syntax 88.900 array('NUL in SFTP path')
  path=path~changeStr('\\','/')
  if path=='' then path='/'
  parts=.array~new
  rest=path
  do while rest<>''
    parse var rest seg '/' rest
    if seg=='' | seg=='.' then iterate
    if seg=='..' then do
      if parts~items=0 then raise syntax 88.900 array('SFTP path escapes virtual root',path)
      parts~remove(parts~items)
      iterate
    end
    parts~append(seg)
  end
  out='/'
  do i=1 to parts~items
    if i>1 then out=out||'/'
    out=out||parts[i]
  end
  return out
::method parent class
  use strict arg path
  path=self~canonical(path)
  if path='/' then return '/'
  p=path~lastPos('/')
  if p<=1 then return '/'
  return left(path,p-1)
::method basename class
  use strict arg path
  path=self~canonical(path)
  if path='/' then return '/'
  p=path~lastPos('/')
  return substr(path,p+1)

::class SftpBackend public
::method stat
  use strict arg path
  raise syntax 88.900 array('SFTP backend stat not implemented')
::method open
  use strict arg path, pflags
  raise syntax 88.900 array('SFTP backend open not implemented')
::method read
  use strict arg path, offset, count
  raise syntax 88.900 array('SFTP backend read not implemented')
::method write
  use strict arg path, offset, data, append=.false
  raise syntax 88.900 array('SFTP backend write not implemented')
::method remove
  use strict arg path
  raise syntax 88.900 array('SFTP backend remove not implemented')
::method mkdir
  use strict arg path
  raise syntax 88.900 array('SFTP backend mkdir not implemented')
::method rmdir
  use strict arg path
  raise syntax 88.900 array('SFTP backend rmdir not implemented')
::method rename
  use strict arg oldPath,newPath
  raise syntax 88.900 array('SFTP backend rename not implemented')
::method list
  use strict arg path
  raise syntax 88.900 array('SFTP backend list not implemented')

::class SftpMemoryBackend subclass SftpBackend public
::method init
  expose _files _dirs
  _files=.directory~new
  _dirs=.directory~new
  _dirs['/']=.true
::method put
  expose _files _dirs
  use strict arg path, data
  path=.SftpPath~canonical(path)
  parent=.SftpPath~parent(path)
  if _dirs[parent]<>.true then raise syntax 88.900 array('Parent directory does not exist',parent)
  _files[path]=data
  return self
::method exists
  expose _files _dirs
  use strict arg path
  path=.SftpPath~canonical(path)
  return _files~hasIndex(path) | _dirs~hasIndex(path)
::method stat
  expose _files _dirs
  use strict arg path
  path=.SftpPath~canonical(path)
  a=.directory~new
  if _files~hasIndex(path) then do
    a['type']='file'; a['size']=length(_files[path]); a['permissions']=33188
    return a
  end
  if _dirs~hasIndex(path) then do
    a['type']='directory'; a['size']=0; a['permissions']=16877
    return a
  end
  return .nil
::method open
  expose _files _dirs
  use strict arg path, pflags
  path=.SftpPath~canonical(path)
  if _dirs~hasIndex(path) then return .false
  exists=_files~hasIndex(path)
  if \exists then do
    if \.SftpOpenFlags~has(pflags,.SftpOpenFlags~CREAT) then return .false
    parent=.SftpPath~parent(path)
    if _dirs[parent]<>.true then return .false
    _files[path]=''
  end
  else if .SftpOpenFlags~has(pflags,.SftpOpenFlags~EXCL) & .SftpOpenFlags~has(pflags,.SftpOpenFlags~CREAT) then return .false
  if .SftpOpenFlags~has(pflags,.SftpOpenFlags~TRUNC) then _files[path]=''
  return .true
::method read
  expose _files
  use strict arg path, offset, count
  numeric digits 30
  path=.SftpPath~canonical(path)
  if \_files~hasIndex(path) then return .nil
  data=_files[path]
  if offset>=length(data) then return ''
  remaining=length(data)-offset
  if count>remaining then count=remaining
  return substr(data,offset+1,count)
::method write
  expose _files
  use strict arg path, offset, data, append=.false
  numeric digits 30
  path=.SftpPath~canonical(path)
  if \_files~hasIndex(path) then return .false
  old=_files[path]
  if append then offset=length(old)
  if offset>length(old) then old=old||copies('00'x,offset-length(old))
  prefix=left(old,offset)
  suffixStart=offset+length(data)+1
  if suffixStart<=length(old) then suffix=substr(old,suffixStart)
  else suffix=''
  _files[path]=prefix||data||suffix
  return .true
::method remove
  expose _files
  use strict arg path
  path=.SftpPath~canonical(path)
  if \_files~hasIndex(path) then return .false
  _files~remove(path)
  return .true
::method mkdir
  expose _dirs _files
  use strict arg path
  path=.SftpPath~canonical(path)
  if _dirs~hasIndex(path) | _files~hasIndex(path) then return .false
  if _dirs[.SftpPath~parent(path)]<>.true then return .false
  _dirs[path]=.true
  return .true
::method rmdir
  expose _dirs _files
  use strict arg path
  path=.SftpPath~canonical(path)
  if path='/' | \_dirs~hasIndex(path) then return .false
  prefix=path||'/'
  do k over _dirs
    if left(k,length(prefix))==prefix then return .false
  end
  do k over _files
    if left(k,length(prefix))==prefix then return .false
  end
  _dirs~remove(path)
  return .true
::method rename
  expose _dirs _files
  use strict arg oldPath,newPath
  oldPath=.SftpPath~canonical(oldPath); newPath=.SftpPath~canonical(newPath)
  if _files~hasIndex(oldPath) then do
    if _files~hasIndex(newPath) | _dirs~hasIndex(newPath) then return .false
    if _dirs[.SftpPath~parent(newPath)]<>.true then return .false
    _files[newPath]=_files[oldPath]; _files~remove(oldPath); return .true
  end
  return .false
::method list
  expose _dirs _files
  use strict arg path
  path=.SftpPath~canonical(path)
  if \_dirs~hasIndex(path) then return .nil
  prefix=path
  if prefix<>'/' then prefix=prefix||'/'
  else prefix='/'
  out=.array~new
  seen=.directory~new
  do k over _dirs
    if k=path | left(k,length(prefix))<>prefix then iterate
    rest=substr(k,length(prefix)+1)
    if rest=='' | pos('/',rest)>0 then iterate
    if \seen~hasIndex(rest) then do
      e=.directory~new; e['filename']=rest; e['longname']=rest; e['attrs']=self~stat(k)
      out~append(e); seen[rest]=.true
    end
  end
  do k over _files
    if left(k,length(prefix))<>prefix then iterate
    rest=substr(k,length(prefix)+1)
    if rest=='' | pos('/',rest)>0 then iterate
    if \seen~hasIndex(rest) then do
      e=.directory~new; e['filename']=rest; e['longname']=rest; e['attrs']=self~stat(k)
      out~append(e); seen[rest]=.true
    end
  end
  return out
::method content
  expose _files
  use strict arg path
  path=.SftpPath~canonical(path)
  if \_files~hasIndex(path) then return .nil
  return _files[path]

::class SftpEndpoint public
::method init
  expose _backend _handles _nextHandle _initialized _maxRead _maxWrite
  use strict arg backend, maxRead=1048576, maxWrite=1048576
  _backend=backend
  _handles=.directory~new
  _nextHandle=1
  _initialized=.false
  _maxRead=maxRead
  _maxWrite=maxWrite
::method backend; expose _backend; return _backend
::method initialized; expose _initialized; return _initialized
::method newHandle private
  expose _handles _nextHandle
  use strict arg kind,path,extra=.nil
  h='H'||right(_nextHandle,8,'0')
  _nextHandle=_nextHandle+1
  d=.directory~new; d['kind']=kind; d['path']=path; d['extra']=extra
  _handles[h]=d
  return h
::method handleRecord private
  expose _handles
  use strict arg h
  return _handles[h]
::method consume
  expose _backend _handles _initialized _maxRead _maxWrite
  use strict arg frame
  req=.SftpCodec~request(frame)
  t=req['type']; p=req['payload']; o=req['body_offset']
  if t=.SftpTypes~INIT then do
    if _initialized then return .SftpCodec~status(0,.SftpStatusCodes~BAD_MESSAGE,'duplicate INIT')
    if req['version']<3 then do
      _initialized=.true
      return .SftpCodec~versionResponse(3)
    end
    _initialized=.true
    return .SftpCodec~versionResponse(3)
  end
  id=req['id']
  if \_initialized then return .SftpCodec~status(id,.SftpStatusCodes~NO_CONNECTION,'SFTP INIT required')

  if t=.SftpTypes~REALPATH then do
    s=.SftpCodec~readString(p,o); path=.SftpPath~canonical(s['value'])
    e=.directory~new; e['filename']=path; e['longname']=path; e['attrs']=_backend~stat(path)
    if e['attrs']==.nil then e['attrs']=.directory~new
    return .SftpCodec~name(id,.array~of(e))
  end

  if t=.SftpTypes~STAT | t=.SftpTypes~LSTAT then do
    s=.SftpCodec~readString(p,o); path=.SftpPath~canonical(s['value'])
    a=_backend~stat(path)
    if a==.nil then return .SftpCodec~status(id,.SftpStatusCodes~NO_SUCH_FILE,'not found')
    return .SftpCodec~attrs(id,a)
  end

  if t=.SftpTypes~OPEN then do
    s=.SftpCodec~readString(p,o); path=.SftpPath~canonical(s['value']); o=s['next']
    flags=.SftpCodec~readU32(p,o)
    if \_backend~open(path,flags) then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'open failed')
    extra=.directory~new; extra['flags']=flags
    h=self~newHandle('file',path,extra)
    return .SftpCodec~handle(id,h)
  end

  if t=.SftpTypes~CLOSE then do
    s=.SftpCodec~readString(p,o); h=s['value']
    if _handles[h]==.nil then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'unknown handle')
    _handles~remove(h)
    return .SftpCodec~status(id,.SftpStatusCodes~OK)
  end

  if t=.SftpTypes~FSTAT then do
    s=.SftpCodec~readString(p,o); rec=self~handleRecord(s['value'])
    if rec==.nil then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'unknown handle')
    a=_backend~stat(rec['path'])
    if a==.nil then return .SftpCodec~status(id,.SftpStatusCodes~NO_SUCH_FILE,'not found')
    return .SftpCodec~attrs(id,a)
  end

  if t=.SftpTypes~READ then do
    s=.SftpCodec~readString(p,o); rec=self~handleRecord(s['value']); o=s['next']
    if rec==.nil | rec['kind']<>'file' then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'bad file handle')
    offset=.SftpCodec~readU64(p,o); o=o+8; count=.SftpCodec~readU32(p,o)
    if count>_maxRead then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'read exceeds bound')
    data=_backend~read(rec['path'],offset,count)
    if data==.nil then return .SftpCodec~status(id,.SftpStatusCodes~NO_SUCH_FILE,'not found')
    if data=='' then return .SftpCodec~status(id,.SftpStatusCodes~EOF)
    return .SftpCodec~data(id,data)
  end

  if t=.SftpTypes~WRITE then do
    s=.SftpCodec~readString(p,o); rec=self~handleRecord(s['value']); o=s['next']
    if rec==.nil | rec['kind']<>'file' then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'bad file handle')
    offset=.SftpCodec~readU64(p,o); o=o+8; d=.SftpCodec~readString(p,o); data=d['value']
    if length(data)>_maxWrite then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'write exceeds bound')
    flags=rec['extra']['flags']; append=.SftpOpenFlags~has(flags,.SftpOpenFlags~APPEND)
    if \_backend~write(rec['path'],offset,data,append) then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'write failed')
    return .SftpCodec~status(id,.SftpStatusCodes~OK)
  end

  if t=.SftpTypes~OPENDIR then do
    s=.SftpCodec~readString(p,o); path=.SftpPath~canonical(s['value'])
    entries=_backend~list(path)
    if entries==.nil then return .SftpCodec~status(id,.SftpStatusCodes~NO_SUCH_FILE,'directory not found')
    extra=.directory~new; extra['entries']=entries; extra['sent']=.false
    h=self~newHandle('directory',path,extra)
    return .SftpCodec~handle(id,h)
  end

  if t=.SftpTypes~READDIR then do
    s=.SftpCodec~readString(p,o); rec=self~handleRecord(s['value'])
    if rec==.nil | rec['kind']<>'directory' then return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'bad directory handle')
    if rec['extra']['sent'] then return .SftpCodec~status(id,.SftpStatusCodes~EOF)
    rec['extra']['sent']=.true
    return .SftpCodec~name(id,rec['extra']['entries'])
  end

  if t=.SftpTypes~REMOVE then do
    s=.SftpCodec~readString(p,o); path=.SftpPath~canonical(s['value'])
    if _backend~remove(path) then return .SftpCodec~status(id,.SftpStatusCodes~OK)
    return .SftpCodec~status(id,.SftpStatusCodes~NO_SUCH_FILE,'remove failed')
  end

  if t=.SftpTypes~MKDIR then do
    s=.SftpCodec~readString(p,o); path=.SftpPath~canonical(s['value'])
    if _backend~mkdir(path) then return .SftpCodec~status(id,.SftpStatusCodes~OK)
    return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'mkdir failed')
  end

  if t=.SftpTypes~RMDIR then do
    s=.SftpCodec~readString(p,o); path=.SftpPath~canonical(s['value'])
    if _backend~rmdir(path) then return .SftpCodec~status(id,.SftpStatusCodes~OK)
    return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'rmdir failed')
  end

  if t=.SftpTypes~RENAME then do
    s=.SftpCodec~readString(p,o); oldPath=.SftpPath~canonical(s['value']); o=s['next']
    s=.SftpCodec~readString(p,o); newPath=.SftpPath~canonical(s['value'])
    if _backend~rename(oldPath,newPath) then return .SftpCodec~status(id,.SftpStatusCodes~OK)
    return .SftpCodec~status(id,.SftpStatusCodes~FAILURE,'rename failed')
  end

  return .SftpCodec~status(id,.SftpStatusCodes~OP_UNSUPPORTED,'operation unsupported in dev1')

::class SftpSubsystemHandler public
::method init
  expose _backendFactory
  use strict arg backendFactory
  _backendFactory=backendFactory
::method endpoint
  expose _backendFactory
  backend=_backendFactory~newBackend
  return .SftpEndpoint~new(backend)
::method subsystemName
  return 'sftp'

::requires 'SshCore.cls'

::class SftpFramer public
::method init
  expose _buffer _maxFrame
  use strict arg maxFrame=16777216
  _buffer=''
  _maxFrame=maxFrame
::method pendingBytes
  expose _buffer
  return length(_buffer)
::method feed
  expose _buffer _maxFrame
  use strict arg bytes
  _buffer=_buffer||bytes
  frames=.array~new
  do while length(_buffer)>=4
    n=.SftpCodec~readU32(_buffer,1)
    if n>_maxFrame then raise syntax 88.900 array('SFTP frame exceeds channel bound',n)
    need=n+4
    if length(_buffer)<need then leave
    frames~append(substr(_buffer,1,need))
    if length(_buffer)=need then _buffer=''
    else _buffer=substr(_buffer,need+1)
  end
  return frames

::class SftpChannelService public
::method init
  expose _endpoint _framer
  use strict arg endpoint, maxFrame=16777216
  _endpoint=endpoint
  _framer=.SftpFramer~new(maxFrame)
::method endpoint
  expose _endpoint
  return _endpoint
::method receive
  expose _endpoint _framer
  use strict arg bytes
  inbound=_framer~feed(bytes)
  outbound=.array~new
  do frame over inbound
    outbound~append(_endpoint~consume(frame))
  end
  return outbound
::method pendingBytes
  expose _framer
  return _framer~pendingBytes
