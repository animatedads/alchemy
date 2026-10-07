/*----------------------------------------------------------------------------*/
/* ooRexx Serial v0.1-dev1                                                    */
/* Provider-neutral serial ports, native line control, framing and events.    */
/*----------------------------------------------------------------------------*/

::class SerialBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "serial/0.1"

::class SerialEvents public
::constant OPENED "SERIAL.PORT.OPENED"
::constant CLOSED "SERIAL.PORT.CLOSED"
::constant DATA "SERIAL.DATA"
::constant FRAME "SERIAL.FRAME"
::constant BREAK "SERIAL.BREAK"
::constant ERROR "SERIAL.ERROR"
::constant DISCONNECTED "SERIAL.PORT.DISCONNECTED"
::constant LINE_CTS "SERIAL.LINE.CTS.CHANGED"
::constant LINE_DSR "SERIAL.LINE.DSR.CHANGED"
::constant LINE_DCD "SERIAL.LINE.DCD.CHANGED"
::constant LINE_RI  "SERIAL.LINE.RI.CHANGED"
::constant LINE_DTR "SERIAL.LINE.DTR.CHANGED"
::constant LINE_RTS "SERIAL.LINE.RTS.CHANGED"

::method resolve class
  use strict arg nameArg
  name=nameArg~string~upper
  select
    when name='OPEN' | name='OPENED' then return self~OPENED
    when name='CLOSE' | name='CLOSED' then return self~CLOSED
    when name='DATA' | name='BYTES' then return self~DATA
    when name='FRAME' then return self~FRAME
    when name='BREAK' then return self~BREAK
    when name='ERROR' then return self~ERROR
    when name='DISCONNECTED' | name='LOST' then return self~DISCONNECTED
    when name='CTS' | name='CTS.CHANGED' then return self~LINE_CTS
    when name='DSR' | name='DSR.CHANGED' then return self~LINE_DSR
    when name='DCD' | name='CARRIER' | name='CARRIER.CHANGED' | name='CARRIERLOST' then return self~LINE_DCD
    when name='RI' | name='RING' | name='RI.CHANGED' then return self~LINE_RI
    when name='DTR' | name='DTR.CHANGED' then return self~LINE_DTR
    when name='RTS' | name='RTS.CHANGED' then return self~LINE_RTS
    otherwise do
      if name~left(7)='SERIAL.' then return name
      return 'SERIAL.'||name
    end
  end

::class SerialPortIdentity public
::attribute key get
::attribute provider get
::attribute path get
::attribute name get
::attribute properties get

::method init
  expose key provider path name properties
  use strict arg keyArg,providerArg,pathArg,nameArg="",propertiesArg=.nil
  key=keyArg~string
  provider=providerArg~string
  path=pathArg~string
  name=nameArg~string
  if propertiesArg==.nil then properties=.directory~new
  else properties=propertiesArg~copy

::method property
  expose properties
  use strict arg nameArg,default=.nil
  name=nameArg~string
  if properties~hasIndex(name) then return properties[name]
  return default

::method fromDeviceIdentity class
  use strict arg device
  if device==.nil then return .nil
  path=''; name=''; provider='device-runtime'; key=''
  if device~hasMethod('DEVNODE') then path=device~devnode
  if device~hasMethod('SYSNAME') then name=device~sysname
  if device~hasMethod('PROVIDER') then provider=device~provider
  if device~hasMethod('KEY') then key=device~key
  if path='' then return .nil
  props=.directory~new
  if device~hasMethod('PROPERTIES') then props=device~properties
  if key='' then key=provider||':'||path
  return self~new(key,provider,path,name,props)

::method copyDetached
  expose key provider path name properties
  return .SerialPortIdentity~new(key,provider,path,name,properties)

::method string
  expose name path
  if name<>'' then return name||' ('||path||')'
  return path

::class SerialConfiguration public
::attribute baud get
::attribute dataBits get
::attribute parity get
::attribute stopBits get
::attribute flowControl get

::method init
  expose baud dataBits parity stopBits flowControl
  use strict arg baudArg=9600,dataBitsArg=8,parityArg='NONE',stopBitsArg=1,flowArg='NONE'
  self~_validate(baudArg,dataBitsArg,parityArg,stopBitsArg,flowArg)
  baud=baudArg+0
  dataBits=dataBitsArg+0
  parity=parityArg~string~upper
  stopBits=stopBitsArg+0
  flowControl=flowArg~string~upper

::method _validate private
  use strict arg baudArg,dataBitsArg,parityArg,stopBitsArg,flowArg
  if baudArg~datatype('W')<>1 | baudArg<=0 then raise syntax 93.905 array('baud',baudArg)
  if dataBitsArg<5 | dataBitsArg>8 | dataBitsArg~datatype('W')<>1 then raise syntax 93.905 array('dataBits',dataBitsArg)
  parity=parityArg~string~upper
  if parity<>'NONE' & parity<>'EVEN' & parity<>'ODD' then raise syntax 93.900 array('parity must be NONE, EVEN or ODD')
  if stopBitsArg<>1 & stopBitsArg<>2 then raise syntax 93.900 array('stopBits must be 1 or 2')
  flow=flowArg~string~upper
  if flow<>'NONE' & flow<>'SOFTWARE' & flow<>'HARDWARE' then raise syntax 93.900 array('flowControl must be NONE, SOFTWARE or HARDWARE')

::method withBaud
  expose dataBits parity stopBits flowControl
  use strict arg value
  return .SerialConfiguration~new(value,dataBits,parity,stopBits,flowControl)

::method withDataBits
  expose baud parity stopBits flowControl
  use strict arg value
  return .SerialConfiguration~new(baud,value,parity,stopBits,flowControl)

::method withParity
  expose baud dataBits stopBits flowControl
  use strict arg value
  return .SerialConfiguration~new(baud,dataBits,value,stopBits,flowControl)

::method withStopBits
  expose baud dataBits parity flowControl
  use strict arg value
  return .SerialConfiguration~new(baud,dataBits,parity,value,flowControl)

::method withFlowControl
  expose baud dataBits parity stopBits
  use strict arg value
  return .SerialConfiguration~new(baud,dataBits,parity,stopBits,value)

::method copyDetached
  expose baud dataBits parity stopBits flowControl
  return .SerialConfiguration~new(baud,dataBits,parity,stopBits,flowControl)

::method string
  expose baud dataBits parity stopBits flowControl
  p=parity~left(1)
  return baud||' '||dataBits||p||stopBits||' flow='||flowControl

::class SerialLineState public
::attribute cts get
::attribute dsr get
::attribute dcd get
::attribute ri get
::attribute dtr get
::attribute rts get

::method init
  expose cts dsr dcd ri dtr rts
  use strict arg ctsArg=.nil,dsrArg=.nil,dcdArg=.nil,riArg=.nil,dtrArg=.nil,rtsArg=.nil
  cts=ctsArg; dsr=dsrArg; dcd=dcdArg; ri=riArg; dtr=dtrArg; rts=rtsArg

::method value
  expose cts dsr dcd ri dtr rts
  use strict arg nameArg
  name=nameArg~string~upper
  select
    when name='CTS' then return cts
    when name='DSR' then return dsr
    when name='DCD' | name='CARRIER' then return dcd
    when name='RI' | name='RING' then return ri
    when name='DTR' then return dtr
    when name='RTS' then return rts
    otherwise return .nil
  end

::method copyDetached
  expose cts dsr dcd ri dtr rts
  return .SerialLineState~new(cts,dsr,dcd,ri,dtr,rts)

::class SerialData public
::attribute port get
::attribute bytes get
::attribute byteCount get

::method init
  expose port bytes byteCount
  use strict arg portArg,bytesArg
  port=portArg
  bytes=bytesArg
  byteCount=bytes~length

::method copyDetached
  expose port bytes
  return .SerialData~new(port,bytes)

::class SerialLineChange public
::attribute port get
::attribute line get
::attribute previousValue get
::attribute value get

::method init
  expose port line previousValue value
  use strict arg portArg,lineArg,previousArg,valueArg
  port=portArg; line=lineArg~string~upper; previousValue=previousArg; value=valueArg

::method copyDetached
  expose port line previousValue value
  return .SerialLineChange~new(port,line,previousValue,value)

::class SerialErrorData public
::attribute port get
::attribute operation get
::attribute code get
::attribute message get
::method init
  expose port operation code message
  use strict arg portArg,operationArg,codeArg=0,messageArg=''
  port=portArg; operation=operationArg~string; code=codeArg; message=messageArg~string
::method copyDetached
  expose port operation code message
  return .SerialErrorData~new(port,operation,code,message)

::class SerialProvider public mixinclass Object
::method providerId abstract
::method openConnection abstract

::class SerialConnection public mixinclass Object
::method providerId abstract
::method identity abstract
::method configuration abstract
::method applyConfiguration abstract
::method pollRead abstract
::method write abstract
::method flush abstract
::method sendBreak abstract
::method setLine abstract
::method lineState abstract
::method bytesAvailable abstract
::method close abstract

::class SerialRuntime public
::attribute provider get

::method init
  expose provider
  use strict arg providerArg
  provider=providerArg

::method open
  expose provider
  use strict arg target,configuration=.nil
  if configuration==.nil then configuration=.SerialConfiguration~new
  if target~isA(.SerialPortIdentity) then identity=target
  else identity=.SerialPortIdentity~new(provider~providerId||':'||target~string,provider~providerId,target~string)
  conn=provider~openConnection(identity,configuration)
  if conn==.nil then return .nil
  port=.SerialPort~new(identity,conn,configuration)
  port~_opened
  return port

::method openDevice
  expose provider
  use strict arg deviceIdentity,configuration=.nil
  identity=.SerialPortIdentity~fromDeviceIdentity(deviceIdentity)
  if identity==.nil then return .nil
  if configuration==.nil then configuration=.SerialConfiguration~new
  conn=provider~openConnection(identity,configuration)
  if conn==.nil then return .nil
  port=.SerialPort~new(identity,conn,configuration)
  port~_opened
  return port

::class SerialPort public
::attribute identity get
::attribute source get
::attribute configuration get
::attribute isOpen get
::attribute monitoring get
::attribute lastLineState get

::method init
  expose identity connection configuration source isOpen monitoring lastLineState frameStreams
  use strict arg identityArg,connectionArg,configurationArg
  identity=identityArg
  connection=connectionArg
  configuration=configurationArg~copyDetached
  source=.EventSource~new('serial:'||identity~key)
  isOpen=.true
  monitoring=.false
  lastLineState=.nil
  frameStreams=.array~new

::method _opened
  expose source identity configuration
  meta=.directory~new; meta['configuration']=configuration~string
  source~emit(.SerialEvents~OPENED,identity~copyDetached,meta)
  self~refreshLines
  return self

::method on
  expose source
  use strict arg eventName,target,messageName,delivery='SYNC'
  return source~on(.SerialEvents~resolve(eventName),target,messageName,delivery)

::method when
  expose source
  use strict arg filter
  return source~when(filter)

::method framed
  expose frameStreams
  use strict arg framer,name=''
  stream=framer~streamFor(self,name)
  frameStreams~append(stream)
  return stream

::method poll
  expose connection isOpen source
  use strict arg timeoutMs=0,maxBytes=4096
  if \isOpen then return ''
  bytes=connection~pollRead(timeoutMs,maxBytes)
  if bytes==.nil then do
    self~refreshLines
    return ''
  end
  if bytes~length>0 then source~emit(.SerialEvents~DATA,.SerialData~new(self,bytes))
  self~refreshLines
  return bytes

::method start
  expose monitoring isOpen
  use strict arg pollIntervalMs=250,maxBytes=4096
  if \isOpen then return .false
  if monitoring then return .true
  monitoring=.true
  self~_monitorLoop(pollIntervalMs,maxBytes)
  return .true

::method _monitorLoop private unguarded
  expose monitoring isOpen
  use strict arg pollIntervalMs,maxBytes
  reply
  do while monitoring & isOpen
    ignored=self~poll(pollIntervalMs,maxBytes)
  end
  return

::method stop
  expose monitoring
  monitoring=.false
  return .true

::method write
  expose connection isOpen
  use strict arg bytes
  if \isOpen then return 0
  return connection~write(bytes)

::method flush
  expose connection isOpen
  use strict arg direction='BOTH'
  if \isOpen then return .false
  return connection~flush(direction)

::method sendBreak
  expose connection isOpen source
  use strict arg duration=0
  if \isOpen then return .false
  ok=connection~sendBreak(duration)
  if ok then source~emit(.SerialEvents~BREAK,self)
  return ok

::method refreshLines
  expose connection lastLineState source isOpen
  if \isOpen then return .nil
  current=connection~lineState
  if current==.nil then return .nil
  if lastLineState<>.nil then do
    do line over .array~of('CTS','DSR','DCD','RI','DTR','RTS')
      before=lastLineState~value(line); now=current~value(line)
      if before<>.nil & now<>.nil & before<>now then do
        select
          when line='CTS' then type=.SerialEvents~LINE_CTS
          when line='DSR' then type=.SerialEvents~LINE_DSR
          when line='DCD' then type=.SerialEvents~LINE_DCD
          when line='RI' then type=.SerialEvents~LINE_RI
          when line='DTR' then type=.SerialEvents~LINE_DTR
          otherwise type=.SerialEvents~LINE_RTS
        end
        source~emit(type,.SerialLineChange~new(self,line,before,now))
      end
    end
  end
  lastLineState=current~copyDetached
  return current

::method setDtr
  expose connection isOpen
  use strict arg state
  if \isOpen then return .false
  ok=connection~setLine('DTR',state)
  if ok then self~refreshLines
  return ok

::method setRts
  expose connection isOpen
  use strict arg state
  if \isOpen then return .false
  ok=connection~setLine('RTS',state)
  if ok then self~refreshLines
  return ok

::method 'dtr='
  use strict arg state
  return self~setDtr(state)

::method 'rts='
  use strict arg state
  return self~setRts(state)

::method bytesAvailable
  expose connection isOpen
  if \isOpen then return 0
  return connection~bytesAvailable

::method _applyConfig private
  expose connection configuration
  use strict arg candidate
  if \connection~applyConfiguration(candidate) then return .false
  configuration=candidate~copyDetached
  return .true

::method baud
  expose configuration
  return configuration~baud
::method 'baud='
  expose configuration
  use strict arg value
  return self~_applyConfig(configuration~withBaud(value))

::method dataBits
  expose configuration
  return configuration~dataBits
::method 'dataBits='
  expose configuration
  use strict arg value
  return self~_applyConfig(configuration~withDataBits(value))

::method parity
  expose configuration
  return configuration~parity
::method 'parity='
  expose configuration
  use strict arg value
  return self~_applyConfig(configuration~withParity(value))

::method stopBits
  expose configuration
  return configuration~stopBits
::method 'stopBits='
  expose configuration
  use strict arg value
  return self~_applyConfig(configuration~withStopBits(value))

::method flowControl
  expose configuration
  return configuration~flowControl
::method 'flowControl='
  expose configuration
  use strict arg value
  return self~_applyConfig(configuration~withFlowControl(value))

::method close
  expose connection isOpen monitoring source identity
  if \isOpen then return .true
  monitoring=.false
  ok=connection~close
  isOpen=.false
  source~emit(.SerialEvents~CLOSED,identity~copyDetached)
  return ok

::method uninit
  if self~isOpen then self~close

/*----------------------------------------------------------------------------*/
/* Deterministic provider for applications/tests and future virtual UARTs.     */
/*----------------------------------------------------------------------------*/
::class SerialMemoryProvider public inherit SerialProvider
::method init
  expose connections
  connections=.directory~new
::method providerId
  return 'memory-serial'
::method openConnection
  expose connections
  use strict arg identity,configuration
  conn=.SerialMemoryConnection~new(identity,configuration)
  connections[identity~path]=conn
  return conn
::method connection
  expose connections
  use strict arg path
  if connections~hasIndex(path~string) then return connections[path~string]
  return .nil
::method inject
  use strict arg path,bytes
  conn=self~connection(path)
  if conn==.nil then return .false
  conn~inject(bytes)
  return .true
::method takeWritten
  use strict arg path
  conn=self~connection(path)
  if conn==.nil then return ''
  return conn~takeWritten
::method setObservedLine
  use strict arg path,line,value
  conn=self~connection(path)
  if conn==.nil then return .false
  return conn~setObservedLine(line,value)

::class SerialMemoryConnection public inherit SerialConnection
::method init
  expose identity configuration input output closed lines
  use strict arg identityArg,configurationArg
  identity=identityArg; configuration=configurationArg~copyDetached
  input=''; output=''; closed=.false
  lines=.directory~new
  do n over .array~of('CTS','DSR','DCD','RI','DTR','RTS'); lines[n]=.false; end
::method providerId
  return 'memory-serial'
::method identity
  expose identity
  return identity
::method configuration
  expose configuration
  return configuration~copyDetached
::method applyConfiguration
  expose configuration closed
  use strict arg cfg
  if closed then return .false
  configuration=cfg~copyDetached
  return .true
::method inject guarded
  expose input closed
  use strict arg bytes
  if closed then return .false
  input=input||bytes
  return .true
::method pollRead guarded
  expose input closed
  use strict arg timeoutMs=0,maxBytes=4096
  if closed then return .nil
  if input='' then return ''
  n=maxBytes
  if n>input~length then n=input~length
  out=input~left(n); input=input~substr(n+1)
  return out
::method write guarded
  expose output closed
  use strict arg bytes
  if closed then return 0
  output=output||bytes
  return bytes~length
::method takeWritten guarded
  expose output
  out=output; output=''; return out
::method flush guarded
  expose input output closed
  use strict arg direction='BOTH'
  if closed then return .false
  d=direction~string~upper
  if d='INPUT' | d='BOTH' then input=''
  if d='OUTPUT' | d='BOTH' then output=''
  return .true
::method sendBreak
  expose closed
  use strict arg duration=0
  return \closed
::method setLine guarded
  expose lines closed
  use strict arg lineArg,state
  if closed then return .false
  line=lineArg~string~upper
  if line<>'DTR' & line<>'RTS' then return .false
  lines[line]=state
  return .true
::method setObservedLine guarded
  expose lines closed
  use strict arg lineArg,state
  if closed then return .false
  line=lineArg~string~upper
  if \lines~hasIndex(line) then return .false
  lines[line]=state
  return .true
::method lineState guarded
  expose lines closed
  if closed then return .nil
  return .SerialLineState~new(lines['CTS'],lines['DSR'],lines['DCD'],lines['RI'],lines['DTR'],lines['RTS'])
::method bytesAvailable guarded
  expose input closed
  if closed then return 0
  return input~length
::method close guarded
  expose closed
  closed=.true
  return .true

::requires 'EventRuntime.cls'
