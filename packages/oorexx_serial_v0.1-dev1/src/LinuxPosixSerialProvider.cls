/*----------------------------------------------------------------------------*/
/* Linux POSIX serial provider through ooRexx Foreign Runtime v0.22.6.         */
/* ABI layout/constants are bridge metadata, never guessed in application code.*/
/*----------------------------------------------------------------------------*/

::class LinuxSerialNative private
::method lib class unguarded
  expose bridge lib
  if symbol('lib')<>'VAR' then do
    bridge=value('OOREXX_SERIAL_POSIX_BRIDGE',,'ENVIRONMENT')
    if bridge='' then do
      parse source . . sourceFile
      bridge=filespec('location',sourceFile)||'../bridge/linux-posix-serial.bridge.json'
    end
    lib=.foreign~load(bridge)
    info=.foreign~runtimeInfo
    if \lib~abiQualified | lib~abiProfile<>info~abiProfile then raise syntax 40.900 array('serial bridge is not ABI-qualified for '||info~abiProfile)
  end
  return lib

::class LinuxPosixSerialProvider public inherit SerialProvider
::method providerId
  return 'linux-posix-serial'
::method openConnection
  use strict arg identity,configuration
  conn=.LinuxPosixSerialConnection~new(identity)
  if \conn~open(configuration) then return .nil
  return conn
::method bridgeInfo
  lib=.LinuxSerialNative~lib
  d=.directory~new; d['abiQualified']=lib~abiQualified; d['abiProfile']=lib~abiProfile
  probe=lib~struct('termios'); d['termiosSize']=probe~size; probe~close
  return d

::class LinuxPosixSerialConnection public inherit SerialConnection
::method init
  expose identity handle configuration closed
  use strict arg identityArg
  identity=identityArg; handle=.nil; configuration=.nil; closed=.true

::method providerId
  return 'linux-posix-serial'
::method identity
  expose identity
  return identity
::method configuration
  expose configuration
  if configuration==.nil then return .nil
  return configuration~copyDetached

::method open
  expose identity handle configuration closed
  use strict arg cfg
  lib=.LinuxSerialNative~lib
  flags=lib~constant('O_RDWR')~value+lib~constant('O_NOCTTY')~value+lib~constant('O_NONBLOCK')~value+lib~constant('O_CLOEXEC')~value
  r=lib~posix_open(identity~path,flags)
  if r~isA(.ForeignResult) then handle=r~returnValue; else handle=r
  if handle==.nil then return .false
  if \handle~isA(.ForeignHandle) then return .false
  closed=.false
  if \self~applyConfiguration(cfg) then do; self~close; return .false; end
  return .true

::method _u32and private
  numeric digits 20
  use strict arg a,b
  return x2d(c2x(bitand(d2c(a,4),d2c(b,4))))
::method _u32or private
  numeric digits 20
  use strict arg a,b
  return x2d(c2x(bitor(d2c(a,4),d2c(b,4))))
::method _setFlag private
  numeric digits 20
  use strict arg value,mask,state
  if state then return self~_u32or(value,mask)
  inv=bitxor(d2c(mask,4),'FFFFFFFF'x)
  return x2d(c2x(bitand(d2c(value,4),inv)))

::method _baudConstant private
  use strict arg baud
  lib=.LinuxSerialNative~lib
  name='B'||baud
  signal on syntax name unsupported
  value=lib~constant(name)~value
  signal off syntax
  return value
unsupported:
  signal off syntax
  return .nil

::method applyConfiguration
  expose handle configuration closed
  use strict arg cfg
  if closed | handle==.nil then return .false
  lib=.LinuxSerialNative~lib
  speed=self~_baudConstant(cfg~baud)
  if speed==.nil then return .false
  t=lib~struct('termios')
  r=lib~tcgetattr(handle,t)
  if r~returnValue<0 then do; t~close; return .false; end
  lib~cfmakeraw(t)
  cflag=t~get('c_cflag')
  cflag=self~_setFlag(cflag,lib~constant('CSIZE')~value,.false)
  select
    when cfg~dataBits=5 then db=lib~constant('CS5')~value
    when cfg~dataBits=6 then db=lib~constant('CS6')~value
    when cfg~dataBits=7 then db=lib~constant('CS7')~value
    otherwise db=lib~constant('CS8')~value
  end
  cflag=self~_u32or(cflag,db)
  cflag=self~_u32or(cflag,lib~constant('CLOCAL')~value)
  cflag=self~_u32or(cflag,lib~constant('CREAD')~value)
  cflag=self~_setFlag(cflag,lib~constant('PARENB')~value,cfg~parity<>'NONE')
  cflag=self~_setFlag(cflag,lib~constant('PARODD')~value,cfg~parity='ODD')
  cflag=self~_setFlag(cflag,lib~constant('CSTOPB')~value,cfg~stopBits=2)
  cflag=self~_setFlag(cflag,lib~constant('CRTSCTS')~value,cfg~flowControl='HARDWARE')
  t~set('c_cflag',cflag)
  iflag=t~get('c_iflag')
  iflag=self~_setFlag(iflag,lib~constant('IXON')~value,cfg~flowControl='SOFTWARE')
  iflag=self~_setFlag(iflag,lib~constant('IXOFF')~value,cfg~flowControl='SOFTWARE')
  iflag=self~_setFlag(iflag,lib~constant('IXANY')~value,.false)
  t~set('c_iflag',iflag)
  t~set('vmin',0); t~set('vtime',0)
  ir=lib~cfsetispeed(t,speed); orr=lib~cfsetospeed(t,speed)
  if ir~returnValue<0 | orr~returnValue<0 then do; t~close; return .false; end
  r=lib~tcsetattr(handle,lib~constant('TCSANOW')~value,t)
  t~close
  if r~returnValue<0 then return .false
  configuration=cfg~copyDetached
  return .true

::method pollRead
  expose handle closed
  use strict arg timeoutMs=0,maxBytes=4096
  if closed then return .nil
  lib=.LinuxSerialNative~lib
  fds=lib~structArray('pollfd',1)
  fds~set(1,'fd',handle)
  fds~set(1,'events',lib~constant('POLLIN')~value)
  fds~set(1,'revents',0)
  r=lib~poll(fds,1,timeoutMs)
  ready=r~returnValue; revents=fds~get(1,'revents'); fds~close
  if ready<0 then return .nil
  if ready=0 then return ''
  if self~_u32and(revents,lib~constant('POLLHUP')~value)<>0 then return .nil
  if self~_u32and(revents,lib~constant('POLLERR')~value)<>0 then return .nil
  if self~_u32and(revents,lib~constant('POLLIN')~value)=0 then return ''
  buf=.foreign~buffer(maxBytes)
  rr=lib~read(handle,buf,maxBytes)
  n=rr~returnValue
  if n>0 then bytes=buf~getBytes(0,n); else bytes=''
  buf~close
  if n<0 then do
    if rr~errno=11 then return ''
    return .nil
  end
  return bytes

::method write
  expose handle closed
  use strict arg bytes
  if closed then return 0
  lib=.LinuxSerialNative~lib
  total=0
  do while total<bytes~length
    chunk=bytes~substr(total+1)
    r=lib~write(handle,chunk,chunk~length)
    n=r~returnValue
    if n>0 then total+=n
    else if n<0 & r~errno=11 then do
      fds=lib~structArray('pollfd',1)
      fds~set(1,'fd',handle); fds~set(1,'events',lib~constant('POLLOUT')~value); fds~set(1,'revents',0)
      ignored=lib~poll(fds,1,1000); fds~close
    end
    else leave
  end
  return total

::method flush
  expose handle closed
  use strict arg direction='BOTH'
  if closed then return .false
  lib=.LinuxSerialNative~lib
  d=direction~string~upper
  select
    when d='INPUT' then selector=lib~constant('TCIFLUSH')~value
    when d='OUTPUT' then selector=lib~constant('TCOFLUSH')~value
    when d='BOTH' then selector=lib~constant('TCIOFLUSH')~value
    otherwise raise syntax 93.900 array('flush direction must be INPUT, OUTPUT or BOTH')
  end
  return lib~tcflush(handle,selector)~returnValue=0

::method sendBreak
  expose handle closed
  use strict arg duration=0
  if closed then return .false
  lib=.LinuxSerialNative~lib
  return lib~tcsendbreak(handle,duration)~returnValue=0

::method _ioctlInt private
  expose handle
  use strict arg request,value=.nil
  lib=.LinuxSerialNative~lib
  buf=.foreign~buffer(4)
  if value<>.nil then buf~putBytes(0,d2c(value,4)~reverse)
  r=lib~ioctl_ptr(handle,request,buf)
  if r~returnValue<0 then do; errno=r~errno; buf~close; return .array~of(.false,0,errno); end
  out=x2d(c2x(buf~getBytes(0,4)~reverse)); buf~close
  return .array~of(.true,out,0)

::method setLine
  expose handle closed
  use strict arg lineArg,state
  if closed then return .false
  lib=.LinuxSerialNative~lib
  line=lineArg~string~upper
  if line='DTR' then mask=lib~constant('TIOCM_DTR')~value
  else if line='RTS' then mask=lib~constant('TIOCM_RTS')~value
  else return .false
  if state then req=lib~constant('TIOCMBIS')~value
  else req=lib~constant('TIOCMBIC')~value
  r=self~_ioctlInt(req,mask)
  return r[1]

::method lineState
  expose handle closed
  if closed then return .nil
  lib=.LinuxSerialNative~lib
  r=self~_ioctlInt(lib~constant('TIOCMGET')~value)
  if \r[1] then return .nil
  bits=r[2]
  return .SerialLineState~new(-
    self~_u32and(bits,lib~constant('TIOCM_CTS')~value)<>0,-
    self~_u32and(bits,lib~constant('TIOCM_DSR')~value)<>0,-
    self~_u32and(bits,lib~constant('TIOCM_CAR')~value)<>0,-
    self~_u32and(bits,lib~constant('TIOCM_RNG')~value)<>0,-
    self~_u32and(bits,lib~constant('TIOCM_DTR')~value)<>0,-
    self~_u32and(bits,lib~constant('TIOCM_RTS')~value)<>0)

::method bytesAvailable
  expose handle closed
  if closed then return 0
  lib=.LinuxSerialNative~lib
  r=self~_ioctlInt(lib~constant('FIONREAD')~value)
  if \r[1] then return 0
  return r[2]

::method close
  expose handle closed
  if closed then return .true
  closed=.true
  if handle<>.nil then if handle~isA(.ForeignHandle) then if \handle~closed then handle~close
  handle=.nil
  return .true

::method uninit
  self~close

::requires 'SerialRuntime.cls'
::requires 'foreign.cls'
