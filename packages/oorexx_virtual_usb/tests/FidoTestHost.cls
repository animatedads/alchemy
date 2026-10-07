::class FidoTestHost public
::attribute provider get
::method init
  expose provider assembler
  use strict arg providerArg
  provider=providerArg; assembler=.CtapHidAssembler~new

::method send
  expose provider assembler
  use strict arg cid,command,payload=''
  before=provider~writes~items
  packets=.CtapHidFramer~encode(cid,command,payload)
  do packet over packets; provider~hostOut(x2d('01'),packet); end
  response=.nil
  do i=before+1 to provider~writes~items
    feed=assembler~feed(provider~writes[i]['bytes'])
    if feed~message<>.nil then response=feed~message
  end
  return response

::method allocate
  nonce='0102030405060708'x
  response=self~send(.CtapHid~BROADCAST_CID,.CtapHid~INIT,nonce)
  if response==.nil then raise syntax 93.900 array('no CTAPHID_INIT response')
  if response~payload~left(8)<>nonce then raise syntax 93.900 array('CTAPHID_INIT nonce mismatch')
  return .FidoBinary~fromU32be(response~payload~substr(9,4))

::method cbor
  use strict arg cid, command, request=.nil
  if request==.nil then payload=d2c(command)
  else payload=d2c(command)||.CborCodec~encode(request)
  response=self~send(cid,.CtapHid~CBOR,payload)
  if response==.nil then raise syntax 93.900 array('no CTAPHID_CBOR response')
  return response~payload

::requires 'Fido2Authenticator.cls'
