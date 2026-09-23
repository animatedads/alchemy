/*----------------------------------------------------------------------------*/
/* ooRexx ADB Runtime v0.1-dev1                                               */
/* Session state, multiplexed streams, semantic events, provider-neutral I/O. */
/*----------------------------------------------------------------------------*/

::class AdbRuntimeBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "adb/0.1"

::class AdbEvents public
::constant CONNECTING "ADB.CONNECTING"
::constant AUTH_CHALLENGE "ADB.AUTH.CHALLENGE"
::constant AUTHORIZATION_REQUIRED "ADB.AUTHORIZATION.REQUIRED"
::constant AUTH_SIGNATURE_SENT "ADB.AUTH.SIGNATURE.SENT"
::constant CONNECTED "ADB.CONNECTED"
::constant DISCONNECTED "ADB.DISCONNECTED"
::constant TLS_REQUESTED "ADB.TLS.REQUESTED"
::constant STREAM_OPENED "ADB.STREAM.OPENED"
::constant STREAM_DATA "ADB.STREAM.DATA"
::constant STREAM_CLOSED "ADB.STREAM.CLOSED"
::constant PROTOCOL_ERROR "ADB.PROTOCOL.ERROR"

::class AdbBanner public
::attribute kind get
::attribute properties get
::attribute features get
::attribute raw get

::method init
  expose kind properties features raw
  use strict arg rawArg=''
  raw=rawArg
  kind=''; properties=.directory~new; features=.set~new
  text=rawArg
  nul=pos('00'x,text); if nul>0 then text=substr(text,1,nul-1)
  parse var text kindPart '::' rest
  kind=kindPart
  do while rest<>''
    parse var rest item ';' rest
    eq=pos('=',item)
    if eq>0 then do
      k=substr(item,1,eq-1); v=substr(item,eq+1)
      properties[k]=v
      if k=='features' then do
        f=v
        do while f<>''
          parse var f one ',' f
          if one<>'' then features~put(one)
        end
      end
    end
  end

::method property
  expose properties
  use strict arg name,default=.nil
  if properties~hasIndex(name) then return properties[name]
  return default

::method hasFeature
  expose features
  use strict arg name
  return features~hasIndex(name)

::class AdbStreamEventData public
::attribute stream get
::attribute data get
::method init
  expose stream data
  use strict arg streamArg,dataArg=''
  stream=streamArg; data=dataArg
::method copyDetached
  expose stream data
  return .AdbStreamEventData~new(stream,data)

::class AdbStream public subclass EventSource
::attribute session get
::attribute localId get
::attribute remoteId get
::attribute destination get
::attribute state get
::attribute buffer get
::attribute writeReady get

::method init
  expose session localId remoteId destination state buffer writeReady
  use strict arg sessionArg,localIdArg,destinationArg
  self~init:super('adb:stream:'||localIdArg)
  session=sessionArg; localId=localIdArg+0; remoteId=0
  destination=destinationArg~string; state='OPENING'; buffer=''; writeReady=.false

::method onOkay
  expose remoteId state writeReady
  use strict arg remote
  if state=='OPENING' then do
    remoteId=remote+0; state='OPEN'; writeReady=.true
    self~emit(.AdbEvents~STREAM_OPENED,self)
  end
  else writeReady=.true
  return self

::method onData
  expose buffer
  use strict arg bytes
  buffer=buffer||bytes
  self~emit(.AdbEvents~STREAM_DATA,.AdbStreamEventData~new(self,bytes))
  return self

::method onClose
  expose state writeReady
  state='CLOSED'; writeReady=.false
  self~emit(.AdbEvents~STREAM_CLOSED,self)
  return self

::method write
  expose state writeReady session localId remoteId
  use strict arg bytes
  if state<>'OPEN' then return .false
  if \writeReady then return .false
  session~sendPacket(.AdbPacket~new('WRTE',localId,remoteId,bytes))
  writeReady=.false
  return .true

::method close
  expose state session localId remoteId
  if state=='CLOSED' then return self
  if remoteId<>0 then session~sendPacket(.AdbPacket~new('CLSE',localId,remoteId,''))
  state='CLOSED'
  return self

::class AdbSession public subclass EventSource
::attribute transport get
::attribute authenticator get
::attribute state get
::attribute banner get
::attribute remoteVersion get
::attribute remoteMaxData get
::attribute effectiveMaxData get
::attribute streams get

::method init
  expose transport authenticator state banner remoteVersion remoteMaxData effectiveMaxData streams nextLocalId localVersion localMaxData
  use strict arg transportArg,authenticatorArg=.nil,sourceIdArg='adb:session'
  self~init:super(sourceIdArg)
  transport=transportArg; authenticator=authenticatorArg
  state='NEW'; banner=.nil; remoteVersion=0; remoteMaxData=0
  localVersion=.AdbProtocol~VERSION; localMaxData=.AdbProtocol~MAX_PAYLOAD
  effectiveMaxData=.AdbProtocol~MAX_PAYLOAD_V1
  streams=.directory~new; nextLocalId=1

::method connect
  expose transport state localVersion localMaxData
  if state<>'NEW' & state<>'DISCONNECTED' then return .false
  if \transport~open then return .false
  state='CONNECTING'; self~emit(.AdbEvents~CONNECTING,self)
  payload='host::features=shell_v2;'
  self~sendPacket(.AdbPacket~new('CNXN',localVersion,localMaxData,payload))
  return .true

::method sendPacket
  expose transport remoteVersion
  use strict arg packet
  useChecksum=.true
  if remoteVersion>=.AdbProtocol~VERSION_SKIP_CHECKSUM then useChecksum=.false
  return transport~write(packet~encode(useChecksum))

::method openService
  expose state streams nextLocalId
  use strict arg destination
  if state<>'ONLINE' then raise syntax 93.900 array('ADB session is not online',state)
  local=nextLocalId; nextLocalId+=1
  stream=.AdbStream~new(self,local,destination)
  streams[local]=stream
  self~sendPacket(.AdbPacket~new('OPEN',local,0,destination||'00'x))
  return stream

::method shell
  use strict arg command=''
  if command=='' then return self~openService('shell:')
  return self~openService('shell:'||command)

::method processPacket
  expose authenticator state banner remoteVersion remoteMaxData effectiveMaxData streams localMaxData
  use strict arg packet
  select
    when packet~command=='CNXN' then do
      remoteVersion=packet~arg0; remoteMaxData=packet~arg1
      effectiveMaxData=min(localMaxData,remoteMaxData)
      banner=.AdbBanner~new(packet~payload)
      state='ONLINE'
      self~emit(.AdbEvents~CONNECTED,self)
    end
    when packet~command=='AUTH' then do
      if packet~arg0<>.AdbProtocol~AUTH_TOKEN then return self
      state='AUTHORIZING'
      self~emit(.AdbEvents~AUTH_CHALLENGE,packet~payload)
      if authenticator==.nil then do
        self~emit(.AdbEvents~AUTHORIZATION_REQUIRED,packet~payload)
        return self
      end
      response=authenticator~responseForToken(packet~payload)
      if response==.nil then do
        self~emit(.AdbEvents~AUTHORIZATION_REQUIRED,packet~payload)
        return self
      end
      self~sendPacket(.AdbPacket~new('AUTH',response['type'],0,response['payload']))
      if response['type']==.AdbProtocol~AUTH_SIGNATURE then self~emit(.AdbEvents~AUTH_SIGNATURE_SENT,response['key'])
      else self~emit(.AdbEvents~AUTHORIZATION_REQUIRED,response['key'])
    end
    when packet~command=='STLS' then do
      state='TLS_REQUIRED'
      self~emit(.AdbEvents~TLS_REQUESTED,packet)
    end
    when packet~command=='OKAY' then do
      local=packet~arg1
      if streams~hasIndex(local) then streams[local]~onOkay(packet~arg0)
    end
    when packet~command=='WRTE' then do
      local=packet~arg1
      if streams~hasIndex(local) then do
        stream=streams[local]
        stream~onData(packet~payload)
        self~sendPacket(.AdbPacket~new('OKAY',local,packet~arg0,''))
      end
    end
    when packet~command=='CLSE' then do
      local=packet~arg1
      if streams~hasIndex(local) then do
        stream=streams[local]
        stream~onClose
        self~sendPacket(.AdbPacket~new('CLSE',local,packet~arg0,''))
        streams~remove(local)
      end
    end
    otherwise do
      d=.directory~new; d['packet']=packet
      self~emit(.AdbEvents~PROTOCOL_ERROR,d)
    end
  end
  return self

::method pump
  expose transport remoteVersion state
  use strict arg timeoutMs=0
  bytes=transport~readPacket(timeoutMs)
  if bytes==.nil then return .false
  verify=remoteVersion<.AdbProtocol~VERSION_SKIP_CHECKSUM
  packet=.AdbPacketCodec~decode(bytes,verify)
  self~processPacket(packet)
  return .true

::method disconnect
  expose transport state streams
  do id over streams
    streams[id]~onClose
  end
  streams~empty
  transport~close
  state='DISCONNECTED'
  self~emit(.AdbEvents~DISCONNECTED,self)
  return self

::class AdbMemoryTransport public
::attribute written get
::method init
  expose opened written incoming
  opened=.false; written=.array~new; incoming=.queue~new
::method open
  expose opened
  opened=.true; return .true
::method close
  expose opened
  opened=.false; return .true
::method write
  expose opened written
  use strict arg bytes
  if \opened then return .false
  written~append(bytes); return bytes~length
::method enqueuePacket
  expose incoming
  use strict arg packet,useChecksum=.true
  incoming~queue(packet~encode(useChecksum)); return self
::method readPacket
  expose incoming opened
  use strict arg timeoutMs=0
  if \opened | incoming~items=0 then return .nil
  return incoming~pull

::requires "AdbWire.cls"
::requires "AdbAuth.cls"
::requires "EventRuntime.cls"
