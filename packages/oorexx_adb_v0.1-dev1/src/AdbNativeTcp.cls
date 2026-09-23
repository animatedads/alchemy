/*----------------------------------------------------------------------------*/
/* ooRexx ADB native Linux TCP transport v0.1-dev1                            */
/* Foreign Runtime v0.22.6 + libc.                                            */
/*----------------------------------------------------------------------------*/

::class AdbTcpForeign private
::method library class unguarded
  expose library bridge
  if symbol('library')<>'VAR' then do
    bridge=value('OOREXX_ADB_TCP_BRIDGE',,'ENVIRONMENT')
    if bridge=='' then do
      parse source . . sourceFile
      bridge=filespec('location',sourceFile)||'../bridge/libc-adb-tcp.bridge.json'
    end
    info=.foreign~runtimeInfo
    library=.foreign~load(bridge)
    if \library~abiQualified | library~abiProfile<>info~abiProfile then raise syntax 40.900 array('ADB TCP bridge ABI mismatch',info~abiProfile)
  end
  return library
::method constant class unguarded
  expose constants
  use strict arg name
  if symbol('constants')<>'VAR' then constants=.directory~new
  if \constants~hasIndex(name) then constants[name]=self~library~constant(name)~value
  return constants[name]
::method call class unguarded
  use strict arg name,...
  args=.array~new; do i=2 to arg(); args~append(arg(i)); end
  return self~library~invokeArray(name,args)

::class LinuxAdbTcpTransport public
::attribute host get
::attribute port get
::attribute errno get

::method init
  expose host port handle opened errno
  use strict arg hostArg,portArg=5555
  host=hostArg~string; port=portArg+0; handle=.nil; opened=.false; errno=0

::method open
  expose host port handle opened errno
  if opened then return .true
  sockType=.AdbTcpForeign~constant('SOCK_STREAM')+.AdbTcpForeign~constant('SOCK_CLOEXEC')
  r=.AdbTcpForeign~call('posix_socket',.AdbTcpForeign~constant('AF_INET'),sockType,0)
  errno=r~errno
  if \r~returnValue~isA(.ForeignHandle) then return .false
  handle=r~returnValue
  addr=self~sockaddr(host,port); b=addr[1]; n=addr[2]
  r=.AdbTcpForeign~call('posix_connect',handle~value,b,n); errno=r~errno; b~close
  if r~returnValue<>0 then do; handle~close; handle=.nil; return .false; end
  opened=.true; return .true

::method sockaddr private
  use strict arg host,port
  size=.AdbTcpForeign~constant('SOCKADDR_IN_SIZE')
  b=.foreign~buffer(size); b~putBytes(0,copies('00'x,size))
  b~putBytes(.AdbTcpForeign~constant('SIN_FAMILY_OFFSET'),d2c(.AdbTcpForeign~constant('AF_INET'),2)~reverse)
  b~putBytes(.AdbTcpForeign~constant('SIN_PORT_OFFSET'),d2c(port,2))
  addr=.foreign~buffer(.AdbTcpForeign~constant('IN_ADDR_SIZE'))
  r=.AdbTcpForeign~call('posix_inet_pton',.AdbTcpForeign~constant('AF_INET'),host,addr)
  if r~returnValue<>1 then do; addr~close; b~close; raise syntax 93.900 array('ADB TCP requires an IPv4 literal',host); end
  b~putBytes(.AdbTcpForeign~constant('SIN_ADDR_OFFSET'),addr~getBytes(0,4)); addr~close
  return .array~of(b,size)

::method write
  expose handle opened errno
  use strict arg bytes
  if \opened then return .false
  offset=1
  do while offset<=bytes~length
    chunk=substr(bytes,offset)
    r=.AdbTcpForeign~call('posix_send',handle~value,chunk,chunk~length,.AdbTcpForeign~constant('MSG_NOSIGNAL'))
    errno=r~errno
    if r~returnValue<=0 then return .false
    offset+=r~returnValue
  end
  return bytes~length

::method readExact private
  expose handle opened errno
  use strict arg count,timeoutMs
  if \opened then return .nil
  out=''
  do while out~length<count
    wait=self~waitReadable(timeoutMs)
    if \wait then return .nil
    need=count-out~length; b=.foreign~buffer(need)
    do forever
      r=.AdbTcpForeign~call('posix_recv',handle~value,b,need,0); errno=r~errno
      if r~returnValue>=0 | errno<>.AdbTcpForeign~constant('EINTR') then leave
    end
    if r~returnValue<=0 then do; b~close; return .nil; end
    out=out||b~getBytes(0,r~returnValue); b~close
  end
  return out

::method readPacket
  use strict arg timeoutMs=0
  header=self~readExact(24,timeoutMs)
  if header==.nil then return .nil
  h=.AdbPacketCodec~decodeHeader(header)
  n=h['dataLength']
  payload=''
  if n>0 then do
    payload=self~readExact(n,timeoutMs)
    if payload==.nil then return .nil
  end
  return header||payload

::method waitReadable
  expose handle errno opened
  use strict arg timeoutMs=0
  if \opened then return .false
  fds=.AdbTcpForeign~library~structArray('pollfd',1)
  fds~set(1,'fd',handle~value); fds~set(1,'events',.AdbTcpForeign~constant('POLLIN')); fds~set(1,'revents',0)
  do forever
    r=.AdbTcpForeign~call('posix_poll',fds,1,timeoutMs); errno=r~errno
    if r~returnValue>=0 | errno<>.AdbTcpForeign~constant('EINTR') then leave
  end
  rc=r~returnValue; fds~close
  return rc>0

::method close
  expose handle opened
  if opened then handle~close
  handle=.nil; opened=.false; return .true

::method uninit
  expose handle opened
  if symbol('opened')='VAR' then if opened then handle~close

::requires "foreign.cls"
::requires "AdbWire.cls"
