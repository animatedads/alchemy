/*----------------------------------------------------------------------------*/
/* ooRexx Virtual USB v0.1-dev3 - FIDO2 / CTAP2 development authenticator.   */
/*                                                                            */
/* Development-only: deterministic credential derivation; not production      */
/* security.  The wire protocol and signatures are real; entropy is not.      */
/*----------------------------------------------------------------------------*/

::class Fido2Build public
::constant RELEASE '0.1-dev1'
::constant API_VERSION 'virtual.usb.fido2/0.1'

::class Fido2Events public
::constant HID_COMMAND 'FIDO2.HID.COMMAND'
::constant CHANNEL_ALLOCATED 'FIDO2.HID.CHANNEL.ALLOCATED'
::constant GET_INFO 'FIDO2.AUTHENTICATOR.GET_INFO'
::constant MAKE_CREDENTIAL 'FIDO2.AUTHENTICATOR.MAKE_CREDENTIAL'
::constant CREDENTIAL_CREATED 'FIDO2.AUTHENTICATOR.CREDENTIAL.CREATED'
::constant GET_ASSERTION 'FIDO2.AUTHENTICATOR.GET_ASSERTION'
::constant ASSERTION_CREATED 'FIDO2.AUTHENTICATOR.ASSERTION.CREATED'
::constant USER_PRESENCE 'FIDO2.AUTHENTICATOR.USER_PRESENCE'

::class CtapHid public
::constant BROADCAST_CID 4294967295
::constant PING 1
::constant MSG 3
::constant LOCK 4
::constant INIT 6
::constant WINK 8
::constant CBOR 16
::constant CANCEL 17
::constant KEEPALIVE 59
::constant ERROR 63
::constant ERR_INVALID_CMD 1
::constant ERR_INVALID_PAR 2
::constant ERR_INVALID_LEN 3
::constant ERR_INVALID_SEQ 4
::constant ERR_MSG_TIMEOUT 5
::constant ERR_CHANNEL_BUSY 6
::constant ERR_LOCK_REQUIRED 10
::constant ERR_INVALID_CHANNEL 11
::constant ERR_OTHER 127
::constant CAPABILITY_WINK 1
::constant CAPABILITY_CBOR 4
::constant CAPABILITY_NMSG 8

::class Ctap2 public
::constant MAKE_CREDENTIAL 1
::constant GET_ASSERTION 2
::constant GET_INFO 4
::constant GET_NEXT_ASSERTION 8
::constant OK 0
::constant ERR_INVALID_CBOR 18
::constant ERR_MISSING_PARAMETER 20
::constant ERR_CREDENTIAL_EXCLUDED 25
::constant ERR_UNSUPPORTED_ALGORITHM 38
::constant ERR_OPERATION_DENIED 39
::constant ERR_UNSUPPORTED_OPTION 43
::constant ERR_INVALID_OPTION 44
::constant ERR_NO_CREDENTIALS 46

::class CtapHidMessage public
::attribute cid get
::attribute command get
::attribute payload get
::method init
  expose cid command payload
  numeric digits 20
  use strict arg cidArg, commandArg, payloadArg=''
  cid=cidArg+0; command=commandArg+0; payload=payloadArg

::class CtapHidFeedResult public
::attribute message get
::attribute errorCode get
::attribute cid get
::method init
  expose message errorCode cid
  numeric digits 20
  use strict arg messageArg=.nil, errorArg=.nil, cidArg=0
  message=messageArg; errorCode=errorArg; cid=cidArg+0

::class CtapHidFramer public
::method encode class
  numeric digits 20
  use strict arg cid, command, payload=''
  packets=.array~new
  total=payload~length
  firstData=payload~left(min(57,total))
  packet=.FidoBinary~u32be(cid)||d2c(128+command)||.FidoBinary~u16be(total)||firstData
  packet=packet||copies('00'x,64-packet~length)
  packets~append(packet)
  offset=58
  seq=0
  do while offset<=total
    chunk=payload~substr(offset,59)
    packet=.FidoBinary~u32be(cid)||d2c(seq)||chunk
    packet=packet||copies('00'x,64-packet~length)
    packets~append(packet)
    seq+=1; offset+=59
  end
  return packets

::class CtapHidAssembler public
::method init
  expose states
  states=.directory~new

::method reset
  expose states
  use strict arg cid
  key=cid~string
  if states~hasIndex(key) then states~remove(key)
  return self

::method feed
  expose states
  numeric digits 20
  use strict arg packet
  if packet~length<>64 then return .CtapHidFeedResult~new(.nil,.CtapHid~ERR_INVALID_LEN,0)
  cid=.FidoBinary~fromU32be(packet~substr(1,4))
  marker=c2d(packet~substr(5,1))
  key=cid~string
  if marker>=128 then do
    command=marker-128
    length=.FidoBinary~fromU16be(packet~substr(6,2))
    data=packet~substr(8,min(57,length))
    if length<=57 then return .CtapHidFeedResult~new(.CtapHidMessage~new(cid,command,data),.nil,cid)
    state=.directory~new
    state['command']=command; state['length']=length; state['data']=data; state['seq']=0
    states[key]=state
    return .CtapHidFeedResult~new(.nil,.nil,cid)
  end
  if \states~hasIndex(key) then return .CtapHidFeedResult~new(.nil,.CtapHid~ERR_INVALID_CHANNEL,cid)
  state=states[key]
  if marker<>state['seq'] then do
    states~remove(key)
    return .CtapHidFeedResult~new(.nil,.CtapHid~ERR_INVALID_SEQ,cid)
  end
  state['data']=state['data']||packet~substr(6,59)
  state['seq']=state['seq']+1
  if state['data']~length>=state['length'] then do
    data=state['data']~left(state['length'])
    msg=.CtapHidMessage~new(cid,state['command'],data)
    states~remove(key)
    return .CtapHidFeedResult~new(msg,.nil,cid)
  end
  return .CtapHidFeedResult~new(.nil,.nil,cid)

::class FidoBinary public
::method u16be class
  use strict arg value
  return d2c(value,2)
::method u32be class
  numeric digits 20
  use strict arg value
  value=value+0
  if value<0 | value>4294967295 then raise syntax 93.900 array('u32be out of range')
  b1=value%16777216; rem=value//16777216
  b2=rem%65536; rem=rem//65536
  b3=rem%256; b4=rem//256
  return d2c(b1)||d2c(b2)||d2c(b3)||d2c(b4)
::method fromU16be class
  use strict arg bytes
  return c2d(bytes)
::method fromU32be class
  numeric digits 20
  use strict arg bytes
  if bytes~length<>4 then raise syntax 93.900 array('u32be requires 4 bytes')
  return c2d(bytes~substr(1,1))*16777216+c2d(bytes~substr(2,1))*65536+c2d(bytes~substr(3,1))*256+c2d(bytes~substr(4,1))

::class FidoCredential public
::attribute rpId get
::attribute userId get
::attribute credentialId get
::attribute privateSeedHex get
::attribute publicKeyHex get
::attribute discoverable get
::attribute signCount

::method init
  expose rpId userId credentialId privateSeedHex publicKeyHex discoverable signCount
  use strict arg rpIdArg,userIdArg,credentialIdArg,seedArg,publicArg,discoverableArg=.false
  rpId=rpIdArg~string; userId=userIdArg; credentialId=credentialIdArg
  privateSeedHex=seedArg~string; publicKeyHex=publicArg~string
  discoverable=(discoverableArg==.true); signCount=0

::class FidoCredentialStore public
::attribute credentials get
::method init
  expose credentials
  credentials=.array~new
::method add
  expose credentials
  use strict arg credential
  credentials~append(credential)
  return credential
::method byId
  expose credentials
  use strict arg credentialId
  do c over credentials
    if c~credentialId==credentialId then return c
  end
  return .nil
::method forRp
  expose credentials
  use strict arg rpId, discoverableOnly=.false
  out=.array~new
  do c over credentials
    if c~rpId==rpId then do
      if \discoverableOnly | c~discoverable then out~append(c)
    end
  end
  return out

::class FidoAlwaysPresent public
::method approve
  use strict arg operation, context=.nil
  return .true

::class FidoDeterministicCredentialFactory public
::attribute masterSeed get
::method init
  expose masterSeed counter
  use strict arg masterSeedArg='ooRexx-FIDO2-development-only'
  masterSeed=masterSeedArg~string; counter=1
::method create
  expose masterSeed counter
  use strict arg rpId,userId,discoverable=.false
  material=masterSeed||':'||counter||':'||rpId||':'||c2x(userId)
  seedHex=.SHA256~new('seed:'||material)~digest
  credId=x2c(.SHA256~new('credential:'||material)~digest)
  kp=.Ed25519~keypair(seedHex)
  counter+=1
  return .FidoCredential~new(rpId,userId,credId,seedHex,kp['public'],discoverable)

::class Fido2Authenticator public subclass EventSource
::attribute device get
::attribute store get
::attribute userPresence get
::attribute aaguid get
::attribute hidIn get
::attribute hidOut get

::method init
  expose device store userPresence aaguid hidIn hidOut assembler nextCid credentialFactory
  use strict arg deviceArg, storeArg=.nil, presenceArg=.nil, aaguidArg='00112233445566778899AABBCCDDEEFF'x, factoryArg=.nil
  device=deviceArg
  self~init:super(device~sourceId||':fido2')
  if storeArg==.nil then store=.FidoCredentialStore~new; else store=storeArg
  if presenceArg==.nil then userPresence=.FidoAlwaysPresent~new; else userPresence=presenceArg
  aaguid=aaguidArg
  if aaguid~length<>16 then raise syntax 93.900 array('FIDO2 AAGUID must be 16 bytes')
  if factoryArg==.nil then credentialFactory=.FidoDeterministicCredentialFactory~new; else credentialFactory=factoryArg
  assembler=.CtapHidAssembler~new; nextCid=x2d('01000000')
  fn=device~function('authenticator')
  if fn==.nil then raise syntax 93.900 array('virtual USB FIDO2 profile requires authenticator function')
  hidIn=fn~endpoint('hidIn'); hidOut=fn~endpoint('hidOut')
  if hidIn==.nil | hidOut==.nil then raise syntax 93.900 array('FIDO2 authenticator requires hidIn and hidOut endpoints')
  hidOut~on('data',self,'onHidReport','SYNC')
  ctl=fn~control('SET_IDLE')
  if ctl<>.nil then ctl~on('request',self,'onSetIdle','SYNC')

::method onSetIdle
  use strict arg event
  event~data~respond('')

::method onHidReport
  expose assembler
  use strict arg event
  feed=assembler~feed(event~data)
  if feed~errorCode<>.nil then do
    if feed~cid<>0 then self~sendHid(feed~cid,.CtapHid~ERROR,d2c(feed~errorCode))
    return
  end
  if feed~message<>.nil then self~processHid(feed~message)

::method processHid private
  use strict arg message
  self~emit(.Fido2Events~HID_COMMAND,message)
  select
    when message~command=.CtapHid~PING then self~sendHid(message~cid,.CtapHid~PING,message~payload)
    when message~command=.CtapHid~INIT then self~handleInit(message)
    when message~command=.CtapHid~CBOR then self~handleCbor(message)
    when message~command=.CtapHid~CANCEL then nop
    otherwise self~sendHid(message~cid,.CtapHid~ERROR,d2c(.CtapHid~ERR_INVALID_CMD))
  end

::method handleInit private
  expose nextCid assembler
  numeric digits 20
  use strict arg message
  if message~payload~length<>8 then do
    self~sendHid(message~cid,.CtapHid~ERROR,d2c(.CtapHid~ERR_INVALID_LEN)); return
  end
  if message~cid=.CtapHid~BROADCAST_CID then do
    cid=nextCid; nextCid+=1
  end
  else do
    cid=message~cid
    assembler~reset(cid)
  end
  capabilities=.CtapHid~CAPABILITY_CBOR+.CtapHid~CAPABILITY_NMSG
  response=message~payload||.FidoBinary~u32be(cid)||d2c(2)||d2c(1)||d2c(0)||d2c(0)||d2c(capabilities)
  self~sendHid(message~cid,.CtapHid~INIT,response)
  self~emit(.Fido2Events~CHANNEL_ALLOCATED,cid)

::method handleCbor private
  use strict arg message
  if message~payload~length<1 then do
    self~sendHid(message~cid,.CtapHid~CBOR,d2c(.Ctap2~ERR_INVALID_CBOR)); return
  end
  command=c2d(message~payload~substr(1,1))
  body=message~payload~substr(2)
  request=.nil
  if body<>'' then do
    signal on syntax name cborError
    request=.CborCodec~decode(body)
    signal off syntax
  end
  select
    when command=.Ctap2~GET_INFO then response=self~ctapGetInfo
    when command=.Ctap2~MAKE_CREDENTIAL then response=self~ctapMakeCredential(request)
    when command=.Ctap2~GET_ASSERTION then response=self~ctapGetAssertion(request)
    otherwise response=d2c(.CtapHid~ERR_INVALID_CMD)
  end
  self~sendHid(message~cid,.CtapHid~CBOR,response)
  return
cborError:
  self~sendHid(message~cid,.CtapHid~CBOR,d2c(.Ctap2~ERR_INVALID_CBOR))
  return

::method ctapGetInfo
  expose aaguid
  self~emit(.Fido2Events~GET_INFO,self)
  info=.CborMap~new
  versions=.array~of(.CborText~new('FIDO_2_0'))
  info~putInt(1,versions)
  info~putInt(3,.CborBytes~new(aaguid))
  options=.CborMap~new
  options~putText('rk',.CborBool~new(.true))
  options~putText('up',.CborBool~new(.true))
  options~putText('uv',.CborBool~new(.false))
  options~putText('plat',.CborBool~new(.false))
  info~putInt(4,options)
  info~putInt(5,1200)
  info~putInt(7,8)
  info~putInt(8,64)
  info~putInt(9,.array~of(.CborText~new('usb')))
  alg=.CborMap~new; alg~putText('type',.CborText~new('public-key')); alg~putText('alg',-8)
  info~putInt(10,.array~of(alg))
  return d2c(.Ctap2~OK)||.CborCodec~encode(info)

::method ctapMakeCredential private
  expose store userPresence aaguid credentialFactory
  use strict arg request
  if request==.nil | \request~isA(.CborMap) then return d2c(.Ctap2~ERR_INVALID_CBOR)
  clientHash=request~getInt(1); rp=request~getInt(2); user=request~getInt(3); params=request~getInt(4)
  if clientHash==.nil | rp==.nil | user==.nil | params==.nil then return d2c(.Ctap2~ERR_MISSING_PARAMETER)
  if \clientHash~isA(.CborBytes) | clientHash~bytes~length<>32 then return d2c(.Ctap2~ERR_INVALID_CBOR)
  rpIdObj=rp~getText('id'); userIdObj=user~getText('id')
  if rpIdObj==.nil | userIdObj==.nil | \userIdObj~isA(.CborBytes) then return d2c(.Ctap2~ERR_MISSING_PARAMETER)
  rpId=rpIdObj~text; userId=userIdObj~bytes
  supported=.false
  do p over params
    if p~isA(.CborMap) then do
      type=p~getText('type'); alg=p~getText('alg')
      if type<>.nil & alg<>.nil then if type~text='public-key' & alg=-8 then supported=.true
    end
  end
  if \supported then return d2c(.Ctap2~ERR_UNSUPPORTED_ALGORITHM)
  exclude=request~getInt(5)
  if exclude<>.nil then do d over exclude
    id=d~getText('id')
    if id<>.nil then if id~isA(.CborBytes) then if store~byId(id~bytes)<>.nil then return d2c(.Ctap2~ERR_CREDENTIAL_EXCLUDED)
  end
  options=request~getInt(7)
  discoverable=.false
  if options<>.nil then do
    rk=options~getText('rk')
    if rk<>.nil then if rk~isA(.CborBool) then discoverable=rk~value
  end
  self~emit(.Fido2Events~MAKE_CREDENTIAL,request)
  if \userPresence~approve('MAKE_CREDENTIAL',request) then return d2c(.Ctap2~ERR_OPERATION_DENIED)
  self~emit(.Fido2Events~USER_PRESENCE,'MAKE_CREDENTIAL')
  cred=credentialFactory~create(rpId,userId,discoverable)
  store~add(cred)
  rpHash=x2c(.SHA256~new(rpId)~digest)
  flags=d2c(x2d('41'))
  authData=rpHash||flags||.FidoBinary~u32be(0)||aaguid||.FidoBinary~u16be(cred~credentialId~length)||cred~credentialId||self~coseKey(cred)
  response=.CborMap~new
  response~putInt(1,.CborText~new('none'))
  response~putInt(2,.CborBytes~new(authData))
  response~putInt(3,.CborMap~new)
  self~emit(.Fido2Events~CREDENTIAL_CREATED,cred)
  return d2c(.Ctap2~OK)||.CborCodec~encode(response)

::method ctapGetAssertion private
  expose store userPresence
  use strict arg request
  if request==.nil | \request~isA(.CborMap) then return d2c(.Ctap2~ERR_INVALID_CBOR)
  rpObj=request~getInt(1); clientHash=request~getInt(2)
  if rpObj==.nil | clientHash==.nil then return d2c(.Ctap2~ERR_MISSING_PARAMETER)
  if rpObj~isA(.CborText) then rpId=rpObj~text; else return d2c(.Ctap2~ERR_INVALID_CBOR)
  if \clientHash~isA(.CborBytes) | clientHash~bytes~length<>32 then return d2c(.Ctap2~ERR_INVALID_CBOR)
  cred=.nil
  allow=request~getInt(3)
  if allow<>.nil then do d over allow
    id=d~getText('id')
    if id<>.nil then if id~isA(.CborBytes) then do
      candidate=store~byId(id~bytes)
      if candidate<>.nil then if candidate~rpId=rpId then do; cred=candidate; leave; end
    end
  end
  else do
    candidates=store~forRp(rpId,.true)
    if candidates~items>0 then cred=candidates[1]
  end
  if cred==.nil then return d2c(.Ctap2~ERR_NO_CREDENTIALS)
  self~emit(.Fido2Events~GET_ASSERTION,request)
  if \userPresence~approve('GET_ASSERTION',request) then return d2c(.Ctap2~ERR_OPERATION_DENIED)
  self~emit(.Fido2Events~USER_PRESENCE,'GET_ASSERTION')
  cred~signCount=cred~signCount+1
  rpHash=x2c(.SHA256~new(rpId)~digest)
  authData=rpHash||d2c(1)||.FidoBinary~u32be(cred~signCount)
  sig=x2c(.Ed25519~sign(authData||clientHash~bytes,cred~privateSeedHex))
  descriptor=.CborMap~new
  descriptor~putText('id',.CborBytes~new(cred~credentialId))
  descriptor~putText('type',.CborText~new('public-key'))
  response=.CborMap~new
  response~putInt(1,descriptor)
  response~putInt(2,.CborBytes~new(authData))
  response~putInt(3,.CborBytes~new(sig))
  user=.CborMap~new; user~putText('id',.CborBytes~new(cred~userId)); response~putInt(4,user)
  self~emit(.Fido2Events~ASSERTION_CREATED,cred)
  return d2c(.Ctap2~OK)||.CborCodec~encode(response)

::method coseKey private
  use strict arg credential
  key=.CborMap~new
  key~putInt(1,1)       /* kty OKP */
  key~putInt(3,-8)      /* EdDSA */
  key~putInt(-1,6)      /* crv Ed25519 */
  key~putInt(-2,.CborBytes~new(x2c(credential~publicKeyHex)))
  return .CborCodec~encode(key)

::method sendHid private
  expose hidIn
  numeric digits 20
  use strict arg cid,command,payload=''
  packets=.CtapHidFramer~encode(cid,command,payload)
  do packet over packets; hidIn~write(packet); end

::requires 'FidoCbor.cls'
::requires 'VirtualUsbRuntime.cls'
::requires 'crypto.cls'
