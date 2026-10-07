/* RFC 6238 authenticator objects. QR decoding is deliberately a provider seam:
 * the protocol authority consumes the resulting otpauth URI, not image pixels.
 */
::options digits 50

::class TotpCredential public
::attribute id get
::attribute issuer get
::attribute accountName get
::attribute secretBase32 get
::attribute algorithm get
::attribute digits get
::attribute period get

::method init
  expose id issuer accountName secretBase32 algorithm digits period
  use strict arg idArg, secretArg, issuerArg="", accountArg="", algorithmArg="SHA1", digitsArg=6, periodArg=30
  id=idArg~string~strip; secretBase32=secretArg~string~strip~upper~changestr(" ","")
  issuer=issuerArg~string; accountName=accountArg~string; algorithm=algorithmArg~string~upper
  digits=digitsArg+0; period=periodArg+0
  if id="" then raise syntax 88.900 array("TOTP credential id is required")
  if secretBase32="" then raise syntax 88.900 array("TOTP secret is required")
  if wordpos(algorithm,"SHA1 SHA256 SHA512")=0 then raise syntax 88.900 array("TOTP algorithm must be SHA1, SHA256 or SHA512")
  if digits<6 | digits>8 then raise syntax 88.900 array("TOTP digits must be 6..8")
  if period<1 then raise syntax 88.900 array("TOTP period must be positive")
  ignore=.AuthBase32~decode(secretBase32)

::method secretBytes
  expose secretBase32
  return .AuthBase32~decode(secretBase32)

::class TotpCode public
::attribute value get
::attribute counter get
::attribute validFrom get
::attribute validUntil get
::attribute remainingSeconds get
::attribute algorithm get
::attribute digits get

::method init
  expose value counter validFrom validUntil remainingSeconds algorithm digits
  use strict arg valueArg, counterArg, fromArg, untilArg, remainingArg, algorithmArg, digitsArg
  value=valueArg~string; counter=counterArg; validFrom=fromArg; validUntil=untilArg
  remainingSeconds=remainingArg; algorithm=algorithmArg; digits=digitsArg

::class TotpGenerator public
::method code class
  use strict arg credential, epochSeconds
  counter=(epochSeconds % credential~period)
  return self~codeForCounter(credential,counter,epochSeconds)

::method codeForCounter class
  use strict arg credential, counter, observedSeconds=.nil
  numeric digits 50
  counterBytes=x2c(counter~d2x(16))
  select
    when credential~algorithm="SHA1" then digest=.AuthHMAC~sha1(credential~secretBytes,counterBytes)
    when credential~algorithm="SHA256" then digest=.AuthHMAC~sha256(credential~secretBytes,counterBytes)
    when credential~algorithm="SHA512" then digest=.AuthHMAC~sha512(credential~secretBytes,counterBytes)
    otherwise raise syntax 88.900 array("unsupported TOTP algorithm")
  end
  offset=x2d(digest~right(1))
  binary=x2d(digest~substr(offset*2+1,8)) // 2147483648
  modulo=10**credential~digits
  value=(binary//modulo)~right(credential~digits,"0")
  validFrom=counter*credential~period
  validUntil=(counter+1)*credential~period
  if observedSeconds==.nil then remaining=credential~period
  else remaining=validUntil-observedSeconds
  if remaining<0 then remaining=0
  return .TotpCode~new(value,counter,validFrom,validUntil,remaining,credential~algorithm,credential~digits)

::method codeWhenUsable class
  use strict arg credential, epochSeconds, minimumSeconds=12
  current=self~code(credential,epochSeconds)
  if current~remainingSeconds>=minimumSeconds then return current
  return self~codeForCounter(credential,current~counter+1,epochSeconds)

::class TotpReplayGuard public
::method init
  expose accepted
  accepted=.directory~new
::method mayAccept
  expose accepted
  use strict arg credentialId, counter
  if \accepted~hasIndex(credentialId) then return .true
  return counter>accepted[credentialId]
::method record
  expose accepted
  use strict arg credentialId, counter
  if accepted~hasIndex(credentialId) then if counter<=accepted[credentialId] then return .false
  accepted[credentialId]=counter
  return .true

::class TotpVerificationResult public
::attribute ok get
::attribute code get
::attribute counter get
::method init
  expose ok code counter
  use strict arg okArg, codeArg, counterArg=(-1)
  ok=okArg==.true; code=codeArg~string; counter=counterArg

::class TotpVerifier public
::method verify class
  use strict arg credential, submittedCode, epochSeconds, window=1, replayGuard=.nil
  submittedCode=submittedCode~string~strip
  current=epochSeconds % credential~period
  do delta=-window to window
    candidateCounter=current+delta
    if candidateCounter<0 then iterate
    candidate=.TotpGenerator~codeForCounter(credential,candidateCounter,epochSeconds)
    if .CryptoUtils~secureEquals(candidate~value,submittedCode) then do
      if replayGuard\==.nil then do
        if \replayGuard~mayAccept(credential~id,candidateCounter) then return .TotpVerificationResult~new(.false,"REPLAY",candidateCounter)
        ignore=replayGuard~record(credential~id,candidateCounter)
      end
      return .TotpVerificationResult~new(.true,"OK",candidateCounter)
    end
  end
  return .TotpVerificationResult~new(.false,"INVALID_CODE",-1)

::class OtpAuthUri public
::method fromCredential class
  use strict arg credential
  label=credential~accountName
  if credential~issuer<>"" then label=credential~issuer || ":" || credential~accountName
  params=.directory~new
  params["secret"]=credential~secretBase32
  if credential~issuer<>"" then params["issuer"]=credential~issuer
  params["algorithm"]=credential~algorithm
  params["digits"]=credential~digits
  params["period"]=credential~period
  return "otpauth://totp/" || .AuthUriCodec~encodeComponent(label) || "?" || .AuthUriCodec~buildQuery(params)

::method parse class
  use strict arg uri, idArg=""
  prefix="otpauth://totp/"
  if uri~left(prefix~length)\=prefix then raise syntax 88.900 array("only otpauth://totp URIs are supported")
  rest=uri~substr(prefix~length+1); q=rest~pos("?")
  if q=0 then raise syntax 88.900 array("otpauth URI lacks parameters")
  label=.AuthUriCodec~decodeComponent(rest~left(q-1)); params=.AuthUriCodec~parseQuery(rest~substr(q+1))
  if \params~hasIndex("secret") then raise syntax 88.900 array("otpauth URI lacks secret")
  issuer=""; account=label
  if params~hasIndex("issuer") then issuer=params["issuer"]
  colon=label~pos(":")
  if colon>0 then do
    labelIssuer=label~left(colon-1); account=label~substr(colon+1)
    if issuer="" then issuer=labelIssuer
    else if issuer\=labelIssuer then raise syntax 88.900 array("otpauth issuer mismatch between label and parameter")
  end
  algorithm="SHA1"; if params~hasIndex("algorithm") then algorithm=params["algorithm"]
  digits=6; if params~hasIndex("digits") then digits=params["digits"]+0
  period=30; if params~hasIndex("period") then period=params["period"]+0
  if idArg="" then idArg=issuer || ":" || account
  return .TotpCredential~new(idArg,params["secret"],issuer,account,algorithm,digits,period)

::class AuthenticatorEnrollment public
::attribute credential get
::method init
  expose credential
  use strict arg credentialArg
  credential=credentialArg
::method fromUri class
  use strict arg uri, idArg=""
  return self~new(.OtpAuthUri~parse(uri,idArg))
::method fromQrPayload class
  use strict arg payload, idArg=""
  return self~fromUri(payload,idArg)
::method fromQr class
  use strict arg qrInput, decoder, idArg=""
  if decoder==.nil | \decoder~hasMethod("DECODE") then raise syntax 88.900 array("QR decoder provider with decode(input) is required")
  return self~fromUri(decoder~decode(qrInput),idArg)
::method provisioningUri
  expose credential
  return .OtpAuthUri~fromCredential(credential)

::class InMemoryAuthenticatorVault public
::method init
  expose credentials
  credentials=.directory~new
::method add
  expose credentials
  use strict arg credential
  credentials[credential~id]=credential
  return credential~id
::method get
  expose credentials
  use strict arg id
  if \credentials~hasIndex(id) then return .nil
  return credentials[id]
::method remove
  expose credentials
  use strict arg id
  if \credentials~hasIndex(id) then return .false
  credentials~remove(id); return .true

::class Authenticator public
::method init
  expose vault
  use strict arg vaultArg
  vault=vaultArg
::method enroll
  expose vault
  use strict arg enrollment
  return vault~add(enrollment~credential)
::method code
  expose vault
  use strict arg id, epochSeconds
  credential=vault~get(id)
  if credential==.nil then raise syntax 88.900 array("unknown authenticator credential: " || id)
  return .TotpGenerator~code(credential,epochSeconds)
::method codeWhenUsable
  expose vault
  use strict arg id, epochSeconds, minimumSeconds=12
  credential=vault~get(id)
  if credential==.nil then raise syntax 88.900 array("unknown authenticator credential: " || id)
  return .TotpGenerator~codeWhenUsable(credential,epochSeconds,minimumSeconds)

::requires "AuthCodec.cls"
::requires "CryptoAuth.cls"
