/*----------------------------------------------------------------------------*/
/* ooRexx Unix Domain Socket library v0.6                                    */
/*                                                                            */
/* AF_UNIX implemented in ooRexx over Foreign Runtime v0.22.6 + libc.        */
/* No Unix-socket-specific native extension is used.                          */
/* ABI-sensitive layouts/constants are Foreign Runtime-qualified profiles.    */
/*----------------------------------------------------------------------------*/

::class UnixForeignRuntime private

::method configure class
  expose bridge library
  use strict arg path
  if symbol('library') = 'VAR' then raise syntax 40.900 array('Unix Foreign Runtime already loaded')
  bridge = path
  return 0

::method library class unguarded
  expose bridge library lastErrno lastError
  if symbol('library') \= 'VAR' then do
    if symbol('bridge') \= 'VAR' then do
      bridge = value('OOREXX_UNIX_SOCKET_BRIDGE',, 'ENVIRONMENT')
      if bridge == '' then do
        parse source . . sourceFile
        bridge = filespec('location', sourceFile) || 'bridge/libc-af-unix.bridge.json'
      end
    end
    info = .foreign~runtimeInfo
    caps = .foreign~capabilities
    foundGraph = .false; foundSlices = .false; foundAbi = .false; foundLayouts = .false; foundConstants = .false; foundNativeScalars = .false
    do i = 1 to caps~items
      if caps[i] == 'transitive-struct-pinning' then foundGraph = .true
      if caps[i] == 'binary-buffer-slices' then foundSlices = .true
      if caps[i] == 'abi-profile-enforcement' then foundAbi = .true
      if caps[i] == 'profile-scoped-layouts' then foundLayouts = .true
      if caps[i] == 'profile-scoped-constants' then foundConstants = .true
      if caps[i] == 'abi-native-c-scalars' then foundNativeScalars = .true
    end
    if \foundGraph | \foundSlices | \foundAbi | \foundLayouts | \foundConstants | \foundNativeScalars then ,
      raise syntax 40.900 array('UnixSocket v0.6 requires Foreign Runtime managed struct graphs, binary slices, executable ABI profiles, and ABI-native C scalars')
    library = .foreign~load(bridge)
    if \library~abiQualified | library~abiProfile \== info~abiProfile then ,
      raise syntax 40.900 array('UnixSocket v0.6 requires a Foreign Runtime-qualified bridge for runtime ABI ' || info~abiProfile)
    lastErrno = 0
    lastError = ''
  end
  return library

::method constant class unguarded
  expose constantCache
  use strict arg name
  if symbol('constantCache') \= 'VAR' then constantCache = .directory~new
  value = constantCache[name]
  if value == .nil then do
    value = self~library~constant(name)~value
    constantCache[name] = value
  end
  return value

::method call class unguarded
  expose lastErrno lastError
  use strict arg name, ...
  args = .array~new
  do i = 2 to arg()
    args~append(arg(i))
  end
  r = self~library~invokeArray(name, args)
  if r~isA(.ForeignResult) then do
    lastErrno = r~errno
    lastError = r~errorMessage
  end
  else do
    lastErrno = 0
    lastError = ''
  end
  return r

::method lastErrno class
  expose lastErrno
  if symbol('lastErrno') \= 'VAR' then return 0
  return lastErrno

::method setError class
  expose lastErrno lastError
  use strict arg error
  lastErrno = error
  if error = 0 then lastError = ''
  else lastError = self~errorText(error)
  return error

::method errorText class
  use strict arg error = .nil
  if error == .nil then error = self~lastErrno
  return self~library~posix_strerror(error)

::method adoptRawFd class
  use strict arg rawFd
  dup = self~call('posix_fcntl_dup', rawFd, self~constant('F_DUPFD_CLOEXEC'), 0)
  handle = dup~returnValue
  ignored = self~call('posix_close_raw', rawFd)
  if handle~isA(.ForeignHandle) then return handle
  return .nil


::class UnixAddress public

::attribute name get
::attribute namespace get

::method pathname class
  use strict arg name
  return self~new(name, 'PATHNAME')

::method abstract class
  use strict arg name
  return self~new(name, 'ABSTRACT')

::method unnamed class
  use strict arg
  return self~new('', 'UNNAMED')

::method init
  expose name namespace
  use strict arg name, namespace = 'PATHNAME'
  namespace = namespace~upper
  if namespace \== 'PATHNAME' & namespace \== 'ABSTRACT' & namespace \== 'UNNAMED' then ,
    raise syntax 93.914 array('namespace', 'PATHNAME, ABSTRACT, UNNAMED', namespace)
  if namespace \== 'UNNAMED' & name == '' then ,
    raise syntax 93.953 array(1, 'non-empty Unix-domain socket name')
  if namespace == 'UNNAMED' & name \== '' then ,
    raise syntax 93.953 array(1, 'empty name for UNNAMED Unix-domain address')
  if namespace == 'PATHNAME' & pos('00'x, name) > 0 then ,
    raise syntax 93.953 array(1, 'pathname Unix-domain socket name without NUL bytes')
  pathCapacity = _uxConst('SUN_PATH_CAPACITY')
  if namespace == 'PATHNAME' & name~length >= pathCapacity then ,
    raise syntax 40.900 array('Unix pathname exceeds qualified sockaddr_un.sun_path capacity')
  if namespace == 'ABSTRACT' & name~length > pathCapacity - 1 then ,
    raise syntax 40.900 array('Abstract Unix-domain name exceeds qualified sockaddr_un.sun_path capacity')
  return

::method isAbstract
  expose namespace
  return namespace == 'ABSTRACT'

::method isUnnamed
  expose namespace
  return namespace == 'UNNAMED'

::method string
  expose name namespace
  if namespace == 'ABSTRACT' then return '@' || name
  return name

::method native
  expose name namespace
  use strict arg
  sockaddrSize = _uxConst('SOCKADDR_UN_SIZE')
  familyOffset = _uxConst('SUN_FAMILY_OFFSET')
  pathOffset = _uxConst('SUN_PATH_OFFSET')
  familySize = _uxTypeSize('unsigned short')
  b = .foreign~buffer(sockaddrSize)
  b~putBytes(familyOffset, _uxPackNative(_uxConst('AF_UNIX'), familySize))
  if namespace == 'PATHNAME' then do
    b~putBytes(pathOffset, name || '00'x)
    n = pathOffset + name~length + 1
  end
  else if namespace == 'ABSTRACT' then do
    b~putBytes(pathOffset, '00'x || name)
    n = pathOffset + 1 + name~length
  end
  else n = pathOffset
  return .array~of(b, n)

::method fromNative class
  use strict arg b, n
  pathOffset = _uxConst('SUN_PATH_OFFSET')
  if n <= pathOffset then return self~unnamed
  bytes = b~getBytes(pathOffset, n - pathOffset)
  if bytes~length = 0 then return self~unnamed
  if substr(bytes, 1, 1) == '00'x then return self~abstract(substr(bytes, 2))
  z = pos('00'x, bytes)
  if z > 0 then bytes = substr(bytes, 1, z - 1)
  if bytes == '' then return self~unnamed
  return self~pathname(bytes)


::class UnixDescriptor public

::method init
  expose handle closed
  use strict arg handle
  if \handle~isA(.ForeignHandle) then raise syntax 93.914 array('handle', 'ForeignHandle', handle~class~id)
  closed = .false

::method fromHandle class
  use strict arg handle
  return self~new(handle)

::method adopt class
  use strict arg fd
  if fd~datatype('W') \= 1 | fd < 0 then raise syntax 93.905 array('fd', fd)
  h = .UnixForeignRuntime~adoptRawFd(fd)
  if h == .nil then return .nil
  return self~new(h)

::method fd
  expose handle closed
  if closed then return -1
  return handle~value

::method close
  expose handle closed
  use strict arg
  if closed then return 0
  handle~close
  closed = .true
  return 0

::method release
  expose handle closed
  use strict arg
  if closed then return -1
  /* Produce a caller-owned CLOEXEC scalar, then retire the managed original. */
  r = .UnixForeignRuntime~call('posix_fcntl_dup_raw', self~fd, _uxConst('F_DUPFD_CLOEXEC'), 0)
  if r~returnValue < 0 then return -1
  raw = r~returnValue
  handle~close
  handle = .nil
  closed = .true
  return raw

::method transferHandle
  expose handle closed
  use strict arg
  if closed then return .nil
  h = handle
  closed = .true
  handle = .nil
  return h

::method isClosed
  expose closed
  return closed

::method isCloseOnExec
  if self~fd < 0 then return .false
  r = .UnixForeignRuntime~call('posix_fcntl_get', self~fd, _uxConst('F_GETFD'))
  if r~returnValue < 0 then return .false
  return _uxHasBit(r~returnValue, _uxConst('FD_CLOEXEC'))

::method string
  return self~fd

::method uninit
  expose handle closed
  if symbol('closed') = 'VAR' then if \closed then handle~close


::class UnixMessage public
::attribute data get
::attribute address get
::attribute descriptors get
::attribute flags get
::attribute truncated get
::attribute credentials get

::method init
  expose data address descriptors flags truncated credentials
  use strict arg data, address = .nil, descriptors = .nil, flags = 0, truncated = .false, credentials = .nil
  if descriptors == .nil then descriptors = .array~new

::method hasCredentials
  expose credentials
  return credentials \== .nil

::method hasDescriptors
  expose descriptors
  return descriptors~items > 0


::class UnixPollWatch public
::attribute target get
::attribute events get

::method read class
  use strict arg target
  return self~new(target, 'READ')
::method write class
  use strict arg target
  return self~new(target, 'WRITE')
::method readWrite class
  use strict arg target
  return self~new(target, 'READ_WRITE')
::method priority class
  use strict arg target
  return self~new(target, 'PRIORITY')

::method init
  expose target events
  use strict arg target, events = 'READ'
  if target~fd < 0 then raise syntax 93.905 array('fd', target~fd)
  events = events~upper
  if events \== 'READ' & events \== 'WRITE' & events \== 'READ_WRITE' & events \== 'PRIORITY' then ,
    raise syntax 93.914 array('events', 'READ, WRITE, READ_WRITE, PRIORITY', events)

::method fd
  expose target
  return target~fd


::class UnixPollResult public
::attribute watch get
::attribute target get
::attribute fd get
::attribute readable get
::attribute writable get
::attribute priority get
::attribute error get
::attribute hangup get
::attribute invalid get
::attribute rawEvents get

::method init
  expose watch target fd readable writable priority error hangup invalid rawEvents
  use strict arg watch, fd, readable, writable, priority, error, hangup, invalid, rawEvents
  target = watch~target


::class UnixPoll public

::method wait class unguarded
  use strict arg watches, timeoutMs = .nil
  if timeoutMs == .nil then timeoutMs = -1
  if timeoutMs~datatype('W') \= 1 | timeoutMs < -1 | timeoutMs > 2147483647 then ,
    raise syntax 93.905 array('timeoutMs', timeoutMs)
  if watches~items = 0 then return .array~new
  lib = .UnixForeignRuntime~library
  fds = lib~structArray('pollfd', watches~items)
  do i = 1 to watches~items
    watch = watches[i]
    events = 0
    select
      when watch~events == 'READ' then events = _uxConst('POLLIN')
      when watch~events == 'WRITE' then events = _uxConst('POLLOUT')
      when watch~events == 'READ_WRITE' then events = _uxBitOr(_uxConst('POLLIN'), _uxConst('POLLOUT'))
      when watch~events == 'PRIORITY' then events = _uxConst('POLLPRI')
    end
    fds~set(i, 'fd', watch~fd)
    fds~set(i, 'events', events)
    fds~set(i, 'revents', 0)
  end
  r = .UnixForeignRuntime~call('posix_poll', fds, watches~items, timeoutMs)
  if r~returnValue < 0 then do; fds~close; return .nil; end
  ready = .array~new
  do i = 1 to watches~items
    raw = fds~get(i, 'revents')
    if raw \= 0 then ready~append(.UnixPollResult~new(watches[i], watches[i]~fd, ,
      _uxHasBit(raw,_uxConst('POLLIN')), _uxHasBit(raw,_uxConst('POLLOUT')), _uxHasBit(raw,_uxConst('POLLPRI')), _uxHasBit(raw,_uxConst('POLLERR')), ,
      _uxHasBit(raw,_uxConst('POLLHUP')), _uxHasBit(raw,_uxConst('POLLNVAL')), raw))
  end
  fds~close
  return ready

::method errno class
  return .UnixForeignRuntime~lastErrno

::method errorText class
  use strict arg error = .nil
  return .UnixForeignRuntime~errorText(error)


::class UnixSocket public

::method configureBridge class
  use strict arg path
  return .UnixForeignRuntime~configure(path)

::method implementation class
  return 'FOREIGN_RUNTIME'

::method foreignRuntimeVersion class
  return .foreign~runtimeInfo~runtimeVersion

::method providerPath class
  return .UnixForeignRuntime~library~providerPath

::method abiProfile class
  return .UnixForeignRuntime~library~abiProfile

::method abiQualified class
  return .UnixForeignRuntime~library~abiQualified

::method init
  expose handle type errno closed
  use strict arg type = 'SOCK_STREAM', existingHandle = .nil
  type = type~upper
  sockType = _uxSocketType(type)
  errno = 0
  closed = .false
  if existingHandle == .nil then do
    r = .UnixForeignRuntime~call('posix_socket', _uxConst('AF_UNIX'), _uxBitOr(sockType,_uxConst('SOCK_CLOEXEC')), 0)
    errno = r~errno
    if \r~returnValue~isA(.ForeignHandle) then do
      handle = .nil; closed = .true
      return
    end
    handle = r~returnValue
  end
  else do
    if \existingHandle~isA(.ForeignHandle) then raise syntax 93.914 array('handle','ForeignHandle',existingHandle~class~id)
    handle = existingHandle
  end

::method fromHandle class
  use strict arg handle, type = 'SOCK_STREAM'
  return self~new(type, handle)

::method adopt class
  use strict arg fd, type = 'SOCK_STREAM'
  if fd~datatype('W') \= 1 | fd < 0 then raise syntax 93.905 array('fd', fd)
  h = .UnixForeignRuntime~adoptRawFd(fd)
  if h == .nil then return .nil
  return self~new(type, h)

::method socketPair class
  use strict arg type = 'SOCK_STREAM'
  sockType = _uxSocketType(type~upper)
  fdSize = _uxConst('FD_SIZE')
  raw = .foreign~buffer(fdSize * 2)
  r = .UnixForeignRuntime~call('posix_socketpair', _uxConst('AF_UNIX'), _uxBitOr(sockType,_uxConst('SOCK_CLOEXEC')), 0, raw)
  if r~returnValue \= 0 then do; raw~close; return .nil; end
  fd1 = _uxUIntNative(raw~getBytes(0,fdSize)); fd2 = _uxUIntNative(raw~getBytes(fdSize,fdSize)); raw~close
  h1 = .UnixForeignRuntime~adoptRawFd(fd1)
  h2 = .UnixForeignRuntime~adoptRawFd(fd2)
  if h1 == .nil | h2 == .nil then do
    if h1 \== .nil then h1~close
    if h2 \== .nil then h2~close
    return .nil
  end
  return .array~of(self~fromHandle(h1,type), self~fromHandle(h2,type))

::method type
  expose type
  return type

::method fd
  expose handle closed
  if closed then return -1
  return handle~value

::method errno
  expose errno
  return errno

::method setNonBlocking
  expose errno
  use strict arg enabled = .true
  g = .UnixForeignRuntime~call('posix_fcntl_get', self~fd, _uxConst('F_GETFL'))
  errno = g~errno
  if g~returnValue < 0 then return -1
  flags = g~returnValue
  nonblockFlag = _uxConst('O_NONBLOCK')
  if enabled then flags = _uxBitOr(flags,nonblockFlag)
  else if _uxHasBit(flags,nonblockFlag) then flags = flags - nonblockFlag
  s = .UnixForeignRuntime~call('posix_fcntl_set', self~fd, _uxConst('F_SETFL'), flags)
  errno = s~errno
  return s~returnValue

::method isNonBlocking
  expose errno
  g = .UnixForeignRuntime~call('posix_fcntl_get', self~fd, _uxConst('F_GETFL'))
  errno = g~errno
  if g~returnValue < 0 then return .nil
  return _uxHasBit(g~returnValue,_uxConst('O_NONBLOCK'))

::method wouldBlock
  expose errno
  use strict arg error = .nil
  if error == .nil then error = errno
  return error = _uxConst('EAGAIN') | error = _uxConst('EWOULDBLOCK')

::method bind
  expose errno
  use strict arg address
  native = address~native; b = native[1]; n = native[2]
  if address~isUnnamed then do; b~close; errno=_uxConst('EINVAL'); return -1; end
  r = .UnixForeignRuntime~call('posix_bind', self~fd, b, n)
  errno = r~errno; b~close
  return r~returnValue

::method connect
  expose errno
  use strict arg address
  native = address~native; b = native[1]; n = native[2]
  if address~isUnnamed then do; b~close; errno=_uxConst('EINVAL'); return -1; end
  r = .UnixForeignRuntime~call('posix_connect', self~fd, b, n)
  errno = r~errno; b~close
  return r~returnValue

::method listen
  expose errno
  use strict arg backlog
  if backlog~datatype('W') \= 1 | backlog < 0 then raise syntax 93.905 array('backlog', backlog)
  r = .UnixForeignRuntime~call('posix_listen', self~fd, backlog)
  errno = r~errno
  return r~returnValue

::method accept unguarded
  expose type errno
  r = .UnixForeignRuntime~call('posix_accept4', self~fd, .nil, .nil, _uxConst('SOCK_CLOEXEC'))
  errno = r~errno
  if \r~returnValue~isA(.ForeignHandle) then return .nil
  return .UnixSocket~fromHandle(r~returnValue, type)

::method send
  expose errno
  use strict arg data
  r = .UnixForeignRuntime~call('posix_send', self~fd, data, data~length, _uxConst('MSG_NOSIGNAL'))
  errno = r~errno
  return r~returnValue

::method sendAll
  expose errno
  use strict arg data
  nonblock = self~isNonBlocking
  if nonblock == .nil then return -1
  if nonblock then do; errno = _uxConst('EINVAL'); return -1; end
  sent = 0
  do while sent < data~length
    chunk = substr(data, sent + 1)
    r = .UnixForeignRuntime~call('posix_send', self~fd, chunk, chunk~length, _uxConst('MSG_NOSIGNAL'))
    errno = r~errno
    n = r~returnValue
    if n < 0 then do
      if errno = _uxConst('EINTR') then iterate
      return -1
    end
    if n = 0 then return sent
    sent += n
  end
  errno = 0
  return sent

::method sendTo
  expose errno
  use strict arg data, address
  native=address~native; b=native[1]; n=native[2]
  if address~isUnnamed then do; b~close; errno=_uxConst('EINVAL'); return -1; end
  r=.UnixForeignRuntime~call('posix_sendto',self~fd,data,data~length,_uxConst('MSG_NOSIGNAL'),b,n)
  errno=r~errno; b~close
  return r~returnValue

::method recv
  expose errno
  use strict arg length
  if length~datatype('W') \= 1 | length < 0 then raise syntax 93.905 array('length', length)
  b=.foreign~buffer(max(1,length))
  do forever
    r=.UnixForeignRuntime~call('posix_recv',self~fd,b,length,0)
    errno=r~errno
    if r~returnValue >= 0 | errno \= _uxConst('EINTR') then leave
  end
  if r~returnValue < 0 then do; b~close; return .nil; end
  data=b~getBytes(0,r~returnValue); b~close
  return data

::method recvFrom
  use strict arg length
  return self~recvMessage(length,0)

::method recvMessage unguarded
  expose errno type
  use strict arg length=4096, maxDescriptors=16
  if length~datatype('W') \= 1 | length < 0 then raise syntax 93.905 array('length', length)
  if maxDescriptors~datatype('W') \= 1 | maxDescriptors < 0 | maxDescriptors > 64 then ,
    raise syntax 93.905 array('maxDescriptors', maxDescriptors)
  lib=.UnixForeignRuntime~library
  sockaddrSize=_uxConst('SOCKADDR_UN_SIZE')
  nameBuf=.foreign~buffer(sockaddrSize)
  dataBuf=.foreign~buffer(max(1,length))
  cmsgDataOffset=_uxConst('CMSG_DATA_OFFSET'); cmsgAlign=_uxConst('CMSG_ALIGN_UNIT')
  controlBytes=_uxAlign(cmsgDataOffset + _uxConst('UCRED_SIZE'), cmsgAlign)
  if maxDescriptors > 0 then controlBytes += _uxAlign(cmsgDataOffset + _uxConst('FD_SIZE')*maxDescriptors, cmsgAlign)
  controlBuf=.foreign~buffer(controlBytes)
  iov=lib~struct('iovec'); iov~set('iov_base',dataBuf); iov~set('iov_len',length)
  msg=lib~struct('msghdr')
  msg~set('msg_name',nameBuf); msg~set('msg_namelen',sockaddrSize)
  msg~set('msg_iov',iov); msg~set('msg_iovlen',1)
  msg~set('msg_control',controlBuf); msg~set('msg_controllen',controlBytes); msg~set('msg_flags',0)
  do forever
    r=.UnixForeignRuntime~call('posix_recvmsg',self~fd,msg,_uxConst('MSG_CMSG_CLOEXEC'))
    errno=r~errno
    if r~returnValue >= 0 | errno \= _uxConst('EINTR') then leave
  end
  if r~returnValue < 0 then do
    msg~close; iov~close; controlBuf~close; dataBuf~close; nameBuf~close
    return .nil
  end
  n=r~returnValue; rawFlags=msg~get('msg_flags'); nameLen=msg~get('msg_namelen'); controlLen=msg~get('msg_controllen')
  data=dataBuf~getBytes(0,min(n,length))
  if nameLen > _uxConst('SUN_PATH_OFFSET') | type == 'SOCK_DGRAM' then address=.UnixAddress~fromNative(nameBuf,nameLen)
  else address=.nil
  descriptors=.array~new; credentials=.nil
  parsed=_uxParseControl(controlBuf,controlLen)
  rawFds=parsed[1]; credentials=parsed[2]
  if _uxHasBit(rawFlags,_uxConst('MSG_CTRUNC')) | rawFds~items > maxDescriptors then do
    do i=1 to rawFds~items; ignored=.UnixForeignRuntime~call('posix_close_raw',rawFds[i]); end
    errno=_uxConst('EMSGSIZE')
    ignored=.UnixForeignRuntime~setError(errno)
    msg~close; iov~close; controlBuf~close; dataBuf~close; nameBuf~close
    return .nil
  end
  do i=1 to rawFds~items
    h=.UnixForeignRuntime~adoptRawFd(rawFds[i])
    if h == .nil then do
      do j=i+1 to rawFds~items; ignored=.UnixForeignRuntime~call('posix_close_raw',rawFds[j]); end
      do j=1 to descriptors~items; descriptors[j]~close; end
      errno=.UnixForeignRuntime~lastErrno
      msg~close; iov~close; controlBuf~close; dataBuf~close; nameBuf~close
      return .nil
    end
    descriptors~append(.UnixDescriptor~fromHandle(h))
  end
  truncated=_uxHasBit(rawFlags,_uxConst('MSG_TRUNC'))
  msg~close; iov~close; controlBuf~close; dataBuf~close; nameBuf~close
  return .UnixMessage~new(data,address,descriptors,rawFlags,truncated,credentials)

::method sendDescriptors
  expose errno
  use strict arg data, descriptors
  if data~length \= 1 then raise syntax 93.953 array(1,'exactly one protocol byte when sending SCM_RIGHTS')
  if descriptors~items = 0 | descriptors~items > 64 then raise syntax 93.953 array(2,'between one and 64 descriptors')
  lib=.UnixForeignRuntime~library
  payload=.foreign~buffer(1); payload~putBytes(0,data)
  iov=lib~struct('iovec'); iov~set('iov_base',payload); iov~set('iov_len',1)
  fdSize=_uxConst('FD_SIZE'); dataOffset=_uxConst('CMSG_DATA_OFFSET'); alignUnit=_uxConst('CMSG_ALIGN_UNIT')
  dataLen=fdSize*descriptors~items; cmsgLen=dataOffset+dataLen; controlLen=_uxAlign(cmsgLen,alignUnit)
  control=.foreign~buffer(controlLen)
  control~putBytes(_uxConst('CMSG_LEN_OFFSET'),_uxPackNative(cmsgLen,_uxTypeSize('size_t')))
  control~putBytes(_uxConst('CMSG_LEVEL_OFFSET'),_uxPackNative(_uxConst('SOL_SOCKET'),_uxTypeSize('int')))
  control~putBytes(_uxConst('CMSG_TYPE_OFFSET'),_uxPackNative(_uxConst('SCM_RIGHTS'),_uxTypeSize('int')))
  do i=1 to descriptors~items
    fd=descriptors[i]~string
    if fd~datatype('W') \= 1 | fd < 0 then raise syntax 93.905 array('descriptor',fd)
    control~putBytes(dataOffset+fdSize*(i-1),_uxPackNative(fd,fdSize))
  end
  msg=lib~struct('msghdr'); msg~set('msg_name',.nil); msg~set('msg_namelen',0)
  msg~set('msg_iov',iov); msg~set('msg_iovlen',1); msg~set('msg_control',control); msg~set('msg_controllen',controlLen); msg~set('msg_flags',0)
  r=.UnixForeignRuntime~call('posix_sendmsg',self~fd,msg,_uxConst('MSG_NOSIGNAL'))
  errno=r~errno
  rc=r~returnValue
  msg~close; iov~close; control~close; payload~close
  return rc

::method recvDescriptors
  use strict arg length=4096,maxDescriptors=16
  if length <= 0 | maxDescriptors <= 0 then raise syntax 93.905 array('length/maxDescriptors',length || '/' || maxDescriptors)
  return self~recvMessage(length,maxDescriptors)

::method setPassCredentials
  expose errno
  use strict arg enabled=.true
  return self~_setIntOption(_uxConst('SO_PASSCRED'),enabled<>0)

::method passCredentials
  return self~_getBoolOption(_uxConst('SO_PASSCRED'))

::method setReceiveBuffer
  use strict arg bytes
  if bytes~datatype('W') \= 1 | bytes <= 0 then raise syntax 93.905 array('bytes',bytes)
  return self~_setIntOption(_uxConst('SO_RCVBUF'),bytes)

::method receiveBuffer
  return self~_getIntOption(_uxConst('SO_RCVBUF'))

::method setSendBuffer
  use strict arg bytes
  if bytes~datatype('W') \= 1 | bytes <= 0 then raise syntax 93.905 array('bytes',bytes)
  return self~_setIntOption(_uxConst('SO_SNDBUF'),bytes)

::method sendBuffer
  return self~_getIntOption(_uxConst('SO_SNDBUF'))

::method _setIntOption private
  expose errno
  use strict arg option,value
  intSize=_uxTypeSize('int')
  b=.foreign~buffer(intSize); b~putBytes(0,_uxPackNative(value,intSize))
  r=.UnixForeignRuntime~call('posix_setsockopt',self~fd,_uxConst('SOL_SOCKET'),option,b,intSize)
  errno=r~errno; b~close
  return r~returnValue

::method _getIntOption private
  expose errno
  use strict arg option
  intSize=_uxTypeSize('int'); socklenSize=_uxTypeSize('socklen_t')
  b=.foreign~buffer(intSize); n=.foreign~buffer(socklenSize); n~putBytes(0,_uxPackNative(intSize,socklenSize))
  r=.UnixForeignRuntime~call('posix_getsockopt',self~fd,_uxConst('SOL_SOCKET'),option,b,n)
  errno=r~errno
  if r~returnValue \= 0 then do; b~close;n~close;return .nil;end
  value=_uxUIntNative(b~getBytes(0,intSize)); b~close;n~close
  return value

::method _getBoolOption private
  use strict arg option
  v=self~_getIntOption(option)
  if v==.nil then return .nil
  return v<>0

::method shutdown
  expose errno
  use strict arg how=.nil
  if how==.nil then how=_uxConst('SHUT_RDWR')
  if how~datatype('W') \= 1 | how < _uxConst('SHUT_RD') | how > _uxConst('SHUT_RDWR') then raise syntax 93.907 array(1,how)
  r=.UnixForeignRuntime~call('posix_shutdown',self~fd,how);errno=r~errno;return r~returnValue

::method close
  expose handle closed errno
  use strict arg
  if closed then return 0
  handle~close; closed=.true; handle=.nil; errno=0
  return 0

::method isClosed
  expose closed
  return closed

::method getSockName
  return self~_nameCall('posix_getsockname')

::method getPeerName
  return self~_nameCall('posix_getpeername')

::method _nameCall private
  expose errno
  use strict arg fn
  sockaddrSize=_uxConst('SOCKADDR_UN_SIZE'); socklenSize=_uxTypeSize('socklen_t')
  b=.foreign~buffer(sockaddrSize); n=.foreign~buffer(socklenSize); n~putBytes(0,_uxPackNative(sockaddrSize,socklenSize))
  r=.UnixForeignRuntime~call(fn,self~fd,b,n); errno=r~errno
  if r~returnValue \= 0 then do;b~close;n~close;return .nil;end
  size=_uxUIntNative(n~getBytes(0,socklenSize)); a=.UnixAddress~fromNative(b,size);b~close;n~close;return a

::method peerCredentials
  expose errno
  lib=.UnixForeignRuntime~library; b=lib~struct('ucred'); socklenSize=_uxTypeSize('socklen_t')
  n=.foreign~buffer(socklenSize); n~putBytes(0,_uxPackNative(b~size,socklenSize))
  r=.UnixForeignRuntime~call('posix_getsockopt',self~fd,_uxConst('SOL_SOCKET'),_uxConst('SO_PEERCRED'),b,n);errno=r~errno
  if r~returnValue \= 0 then do;b~close;n~close;return .nil;end
  d=.directory~new;d['PID']=b~get('pid');d['UID']=b~get('uid');d['GID']=b~get('gid');b~close;n~close;return d

::method errorText
  expose errno
  return .UnixForeignRuntime~errorText(errno)

::method isCloseOnExec
  if self~fd < 0 then return .false
  r=.UnixForeignRuntime~call('posix_fcntl_get',self~fd,_uxConst('F_GETFD'))
  if r~returnValue < 0 then return .false
  return _uxHasBit(r~returnValue,_uxConst('FD_CLOEXEC'))

::method string
  return self~fd

::method pathInfo class
  use strict arg path
  st=.UnixForeignRuntime~library~struct('stat')
  r=.UnixForeignRuntime~call('posix_lstat',path,st)
  if r~returnValue \= 0 then do;st~close;return .nil;end
  mode=st~get('st_mode');d=.directory~new
  d['IS_SOCKET']=_uxBitAnd(mode,_uxConst('S_IFMT'))=_uxConst('S_IFSOCK')
  d['MODE']=_uxBitAnd(mode,_uxConst('MODE_MASK'));d['MODE_OCTAL']=_uxOctal4(d['MODE'])
  d['UID']=st~get('st_uid');d['GID']=st~get('st_gid')
  d['DEVICE']=st~get('st_dev');d['INODE']=st~get('st_ino');st~close
  return d

::method chmodSocketPath class
  use strict arg path,mode
  numericMode=_uxParseOctal(mode)
  if numericMode < 0 then do; ignored=.UnixForeignRuntime~setError(_uxConst('EINVAL')); return -1; end
  h=self~_pinSocketPath(path)
  if h==.nil then return -1
  proc='/proc/self/fd/'||h~value
  r=.UnixForeignRuntime~call('posix_chmod',proc,numericMode);h~close
  return r~returnValue

::method chownSocketPath class
  use strict arg path,uid=.nil,gid=.nil
  if uid==.nil then uid=-1;if gid==.nil then gid=-1
  if uid < -1 | gid < -1 then do; ignored=.UnixForeignRuntime~setError(_uxConst('EINVAL')); return -1; end
  h=self~_pinSocketPath(path);if h==.nil then return -1
  if uid=-1 then uid=_uxConst('UID_T_MAX');if gid=-1 then gid=_uxConst('GID_T_MAX')
  proc='/proc/self/fd/'||h~value
  r=.UnixForeignRuntime~call('posix_chown',proc,uid,gid);h~close
  return r~returnValue

::method _pinSocketPath class private
  use strict arg path
  flags=_uxBitOr(_uxConst('O_PATH'),_uxConst('O_NOFOLLOW'))
  r=.UnixForeignRuntime~call('posix_open',path,flags)
  if \r~returnValue~isA(.ForeignHandle) then return .nil
  h=r~returnValue;st=.UnixForeignRuntime~library~struct('stat');s=.UnixForeignRuntime~call('posix_fstat',h,st)
  if s~returnValue \= 0 then do;st~close;h~close;return .nil;end
  mode=st~get('st_mode');st~close
  if _uxBitAnd(mode,_uxConst('S_IFMT')) \= _uxConst('S_IFSOCK') then do; h~close; ignored=.UnixForeignRuntime~setError(_uxConst('ENOTSOCK')); return .nil; end
  return h

::method unlinkSocketPath class
  use strict arg path
  info=self~pathInfo(path)
  if info==.nil then return -1
  if \info['IS_SOCKET'] then do; ignored=.UnixForeignRuntime~setError(_uxConst('ENOTSOCK')); return -1; end
  r=.UnixForeignRuntime~call('posix_unlink',path)
  return r~returnValue

::method unlinkPath class
  use strict arg path
  r=.UnixForeignRuntime~call('posix_unlink',path)
  return r~returnValue

::method lastErrno class
  return .UnixForeignRuntime~lastErrno

::method lastErrorText class
  use strict arg error=.nil
  return .UnixForeignRuntime~errorText(error)

::method uninit
  expose handle closed
  if symbol('closed')='VAR' then if \closed then handle~close


::routine _uxSocketType
  use strict arg name
  select
    when name == 'SOCK_STREAM' | name == 'STREAM' then return _uxConst('SOCK_STREAM')
    when name == 'SOCK_DGRAM' | name == 'DGRAM' then return _uxConst('SOCK_DGRAM')
    when name == 'SOCK_SEQPACKET' | name == 'SEQPACKET' then return _uxConst('SOCK_SEQPACKET')
    otherwise raise syntax 93.914 array('type','SOCK_STREAM, SOCK_DGRAM, SOCK_SEQPACKET',name)
  end

::routine _uxConst
  use strict arg name
  return .UnixForeignRuntime~constant(name)

::routine _uxTypeSize
  use strict arg name
  return .foreign~datatype(name)~size

::routine _uxPackNative
  use strict arg n,width
  numeric digits 50
  bytes=d2c(n,width)
  if .foreign~runtimeInfo~endianness == 'little' then return reverse(bytes)
  return bytes

::routine _uxUIntNative
  use strict arg s
  numeric digits 50
  if .foreign~runtimeInfo~endianness == 'little' then return c2d(reverse(s))
  return c2d(s)

::routine _uxBitAnd
  use strict arg a,b
  numeric digits 50
  return c2d(bitand(d2c(a,8),d2c(b,8)))

::routine _uxBitOr
  use strict arg a,b
  numeric digits 50
  return c2d(bitor(d2c(a,8),d2c(b,8)))

::routine _uxHasBit
  use strict arg a,b
  return _uxBitAnd(a,b) \= 0

::routine _uxAlign
  use strict arg n,unit
  r=n//unit
  if r=0 then return n
  return n+(unit-r)

::routine _uxParseControl
  use strict arg b,n
  fds=.array~new;credentials=.nil;off=0
  dataOffset=_uxConst('CMSG_DATA_OFFSET'); lenSize=_uxTypeSize('size_t'); intSize=_uxTypeSize('int')
  fdSize=_uxConst('FD_SIZE'); alignUnit=_uxConst('CMSG_ALIGN_UNIT')
  do while off+dataOffset <= n
    len=_uxUIntNative(b~getBytes(off+_uxConst('CMSG_LEN_OFFSET'),lenSize))
    if len < dataOffset | off+len > n then leave
    level=_uxUIntNative(b~getBytes(off+_uxConst('CMSG_LEVEL_OFFSET'),intSize))
    kind=_uxUIntNative(b~getBytes(off+_uxConst('CMSG_TYPE_OFFSET'),intSize));dataLen=len-dataOffset
    if level=_uxConst('SOL_SOCKET') & kind=_uxConst('SCM_RIGHTS') then do
      count=dataLen%fdSize
      do i=0 to count-1
        fds~append(_uxUIntNative(b~getBytes(off+dataOffset+fdSize*i,fdSize)))
      end
    end
    else if level=_uxConst('SOL_SOCKET') & kind=_uxConst('SCM_CREDENTIALS') & dataLen>=_uxConst('UCRED_SIZE') & credentials==.nil then do
      credentials=.directory~new
      credentials['PID']=_uxUIntNative(b~getBytes(off+dataOffset+_uxConst('UCRED_PID_OFFSET'),_uxConst('PID_T_SIZE')))
      credentials['UID']=_uxUIntNative(b~getBytes(off+dataOffset+_uxConst('UCRED_UID_OFFSET'),_uxConst('UID_T_SIZE')))
      credentials['GID']=_uxUIntNative(b~getBytes(off+dataOffset+_uxConst('UCRED_GID_OFFSET'),_uxConst('GID_T_SIZE')))
    end
    off += _uxAlign(len,alignUnit)
  end
  return .array~of(fds,credentials)

::routine _uxParseOctal
  use strict arg value
  s=value~string
  if s~length=0 then return -1
  n=0
  do i=1 to s~length
    c=substr(s,i,1)
    if pos(c,'01234567')=0 then return -1
    n=n*8+c
  end
  if n>_uxConst('MODE_MASK') then return -1
  return n

::routine _uxOctal4
  use strict arg n
  digits='01234567';s=''
  do i=1 to 4
    r=n//8;s=substr(digits,r+1,1)||s;n=n%8
  end
  return s

::requires 'foreign.cls'
