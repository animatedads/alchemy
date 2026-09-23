/* Native Linux RFCOMM transport through Foreign Runtime. */
::class BluetoothRfcommNative private
::method library class unguarded
  expose library bridge
  if symbol('library')<>'VAR' then do
    bridge=value('OOREXX_BLUETOOTH_RFCOMM_BRIDGE',,'ENVIRONMENT')
    if bridge=='' then do
      parse source . . sourceFile
      bridge=filespec('location',sourceFile)||'../bridge/libc-bluetooth-rfcomm.bridge.json'
    end
    library=.foreign~load(bridge)
    info=.foreign~runtimeInfo
    if \library~abiQualified | library~abiProfile<>info~abiProfile then return .nil
  end
  return library

::method constant class unguarded
  use strict arg name
  lib=self~library
  if lib==.nil then return .nil
  return lib~constant(name)~value

::class BluetoothAddressCodec public
::method bdaddr class
  use strict arg addressArg
  s=changestr(':',addressArg~string~upper,'')
  s=changestr('-',s,'')
  if s~length<>12 | \s~datatype('X') then return .nil
  bytes=x2c(s)
  out=''
  do i=6 to 1 by -1; out=out||substr(bytes,i,1); end
  return out

::class LinuxRfcommSocket public
::attribute errno get
::attribute address get
::attribute channel get

::method init
  expose handle errno address channel connected
  handle=.nil; errno=0; address=''; channel=0; connected=.false

::method open
  expose handle errno
  if handle<>.nil then return .true
  lib=.BluetoothRfcommNative~library
  if lib==.nil then return .false
  r=lib~invoke('posix_socket',lib~constant('AF_BLUETOOTH')~value,lib~constant('SOCK_STREAM')~value,lib~constant('BTPROTO_RFCOMM')~value)
  errno=r~errno
  if r~returnValue<0 then return .false
  handle=r~returnValue
  return .true

::method fd
  expose handle
  if handle==.nil then return -1
  if handle~hasMethod('VALUE') then return handle~value
  return handle

::method connect
  expose errno address channel connected
  use strict arg addressArg,channelArg=1
  if \self~open then return .false
  bd=.BluetoothAddressCodec~bdaddr(addressArg)
  if bd==.nil then return .false
  if channelArg<1 | channelArg>30 then return .false
  lib=.BluetoothRfcommNative~library
  n=lib~constant('SOCKADDR_RC_SIZE')~value
  b=.foreign~buffer(n); b~putBytes(0,copies('00'x,n))
  family=lib~constant('AF_BLUETOOTH')~value
  b~putBytes(lib~constant('RC_FAMILY_OFFSET')~value,d2c(family,2)~reverse)
  b~putBytes(lib~constant('RC_BDADDR_OFFSET')~value,bd)
  b~putBytes(lib~constant('RC_CHANNEL_OFFSET')~value,d2c(channelArg,1))
  r=lib~invoke('posix_connect',self~fd,b,n); errno=r~errno; b~close
  if r~returnValue<>0 then return .false
  address=addressArg~string~upper; channel=channelArg; connected=.true
  return .true

::method send
  expose errno
  use strict arg bytes
  lib=.BluetoothRfcommNative~library
  r=lib~invoke('posix_send',self~fd,bytes,bytes~length,lib~constant('MSG_NOSIGNAL')~value)
  errno=r~errno
  return r~returnValue

::method receive
  expose errno
  use strict arg maxBytes=4096
  lib=.BluetoothRfcommNative~library; b=.foreign~buffer(maxBytes)
  r=lib~invoke('posix_recv',self~fd,b,maxBytes,0); errno=r~errno
  if r~returnValue<=0 then do; b~close; return ''; end
  out=b~getBytes(0,r~returnValue); b~close; return out

::method waitReadable
  expose errno
  use strict arg timeoutMs=1000
  lib=.BluetoothRfcommNative~library
  fds=lib~structArray('pollfd',1); fds~set(1,'fd',self~fd); fds~set(1,'events',lib~constant('POLLIN')~value); fds~set(1,'revents',0)
  r=lib~invoke('posix_poll',fds,1,timeoutMs); errno=r~errno; rc=r~returnValue; fds~close
  return rc>0

::method close
  expose handle connected
  if handle<>.nil then if handle~hasMethod('CLOSE') then handle~close
  handle=.nil; connected=.false
  return self

::method uninit
  self~close

::requires 'foreign.cls'
