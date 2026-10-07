/* JWT and OIDC shared semantic objects. dev1 deliberately provides HS256 as
 * an executable interoperability lane while leaving asymmetric JWT authority
 * behind the JwtAuthority interface for RS256/ES256 providers.
 */
::options digits 50

::class AuthSecretAuthority public
::method resolve abstract

::class MemoryAuthSecretAuthority subclass AuthSecretAuthority public
::method init
  expose values
  values=.directory~new
::method put
  expose values
  use strict arg reference, secret
  values[reference]=secret~string; return .true
::method resolve
  expose values
  use strict arg reference
  if \values~hasIndex(reference) then raise syntax 88.900 array("secret reference unavailable: " || reference)
  return values[reference]

::class SecretBrokerAuthSecretAuthority subclass AuthSecretAuthority public
::method init
  expose broker
  use strict arg brokerArg
  broker=brokerArg
::method resolve
  expose broker
  use strict arg reference
  lease=broker~acquire(reference)
  if lease==.nil | \lease~ok then raise syntax 88.900 array("secret broker could not acquire: " || reference)
  result=lease~secretForTrustedConsumer
  if \result~ok then do; ignore=lease~retire; raise syntax 88.900 array("secret lease unavailable: " || reference); end
  value=result~value
  ignore=lease~retire
  return value

::class AuthRandomSource public
::method bytes abstract

::class DeterministicAuthRandomSource subclass AuthRandomSource public
::method init
  expose seed sequence
  use strict arg seedArg="test-seed"
  seed=seedArg~string; sequence=0
::method bytes
  expose seed sequence
  use strict arg count
  out=""
  do while out~length<count
    sequence+=1
    out ||= x2c(.SHA256~new(seed || ":" || sequence)~digest)
  end
  return out~left(count)

::class JwtVerificationResult public
::attribute ok get
::attribute code get
::attribute claims get
::attribute header get
::method init
  expose ok code claims header
  use strict arg okArg, codeArg, claimsArg=.nil, headerArg=.nil
  ok=okArg==.true; code=codeArg~string; claims=claimsArg; header=headerArg

::class JwtAuthority public
::method sign abstract
::method verify abstract

::class Hs256JwtAuthority subclass JwtAuthority public
::method init
  expose secrets
  use strict arg secretAuthority
  secrets=secretAuthority
::method algorithm
  return "HS256"
::method jwks
  d=.directory~new; d["keys"]=.array~new; return d
::method sign
  expose secrets
  use strict arg claims, secretReference
  header=.directory~new; header["alg"]="HS256"; header["typ"]="JWT"
  h=.AuthBase64Url~encode(.JSON~toJSON(header))
  p=.AuthBase64Url~encode(.JSON~toJSON(claims))
  input=h || "." || p
  key=secrets~resolve(secretReference)
  sig=.AuthBase64Url~encode(x2c(.AuthHMAC~sha256(key,input)))
  return input || "." || sig
::method verify
  expose secrets
  use strict arg token, secretReference
  first=token~pos("."); if first=0 then return .JwtVerificationResult~new(.false,"MALFORMED")
  second=token~pos(".",first+1); if second=0 | token~pos(".",second+1)>0 then return .JwtVerificationResult~new(.false,"MALFORMED")
  h64=token~left(first-1); p64=token~substr(first+1,second-first-1); s64=token~substr(second+1)
  signal on syntax name badJwt
  header=.JSON~fromJSON(.AuthBase64Url~decode(h64))
  claims=.JSON~fromJSON(.AuthBase64Url~decode(p64))
  signal off syntax
  if \header~isa(.Directory) | \claims~isa(.Directory) then return .JwtVerificationResult~new(.false,"MALFORMED_JSON")
  if \header~hasIndex("alg") | header["alg"]<>"HS256" then return .JwtVerificationResult~new(.false,"ALGORITHM_REJECTED")
  key=secrets~resolve(secretReference)
  expected=.AuthBase64Url~encode(x2c(.AuthHMAC~sha256(key,h64 || "." || p64)))
  if \.CryptoUtils~secureEquals(expected,s64) then return .JwtVerificationResult~new(.false,"BAD_SIGNATURE")
  return .JwtVerificationResult~new(.true,"OK",claims,header)
badJwt:
  signal off syntax
  return .JwtVerificationResult~new(.false,"MALFORMED_JSON")

::class Pkce public
::method challenge class
  use strict arg verifier
  return .AuthBase64Url~encode(x2c(.SHA256~new(verifier)~digest))
::method verify class
  use strict arg verifier, expectedChallenge
  return .CryptoUtils~secureEquals(self~challenge(verifier),expectedChallenge)

::class OidcDiscovery public
::method parse class
  use strict arg jsonText
  doc=.JSON~fromJSON(jsonText)
  if \doc~isa(.Directory) then raise syntax 88.900 array("OIDC discovery document must be JSON object")
  do key over .array~of("issuer","authorization_endpoint","token_endpoint","jwks_uri")
    if \doc~hasIndex(key) then raise syntax 88.900 array("OIDC discovery document missing " || key)
  end
  return doc


::class Rs256KeyMaterial public
::attribute kid get
::attribute n get
::attribute e get
::attribute d get
::method init
  expose kid n e d
  numeric digits 3000
  use strict arg kidArg, nArg, eArg, dArg
  kid=kidArg~string; n=nArg+0; e=eArg+0; d=dArg+0
  if kid="" | n<=0 | e<=0 | d<=0 then raise syntax 88.900 array("RS256 key material is incomplete")
::method modulusBytes
  expose n
  numeric digits 3000
  hx=n~d2x; if hx~length//2=1 then hx="0"||hx
  return x2c(hx)
::method publicJwk
  expose kid n e
  numeric digits 3000
  nHex=n~d2x; if nHex~length//2=1 then nHex="0"||nHex
  eHex=e~d2x; if eHex~length//2=1 then eHex="0"||eHex
  j=.directory~new; j["kty"]="RSA"; j["kid"]=kid; j["alg"]="RS256"; j["use"]="sig"
  j["n"]=.AuthBase64Url~encode(x2c(nHex)); j["e"]=.AuthBase64Url~encode(x2c(eHex))
  return j

::class Rs256PrivateKeyJwtAuthority subclass JwtAuthority public
::method init
  expose key verifier
  use strict arg keyMaterial
  key=keyMaterial
  set=.directory~new; set["keys"]=.array~of(key~publicJwk)
  verifier=.Rs256JwtAuthority~new(.StaticJwksSource~new(set))
::method algorithm
  return "RS256"
::method jwks
  expose key
  d=.directory~new; d["keys"]=.array~of(key~publicJwk); return d
::method sign
  expose key
  numeric digits 3000
  use strict arg claims, ignoredReference=""
  header=.directory~new; header["alg"]="RS256"; header["typ"]="JWT"; header["kid"]=key~kid
  h64=.AuthBase64Url~encode(.JSON~toJSON(header)); p64=.AuthBase64Url~encode(.JSON~toJSON(claims)); input=h64||"."||p64
  modulusBytes=key~modulusBytes; k=modulusBytes~length
  digest=x2c(.SHA256~new(input)~digest); prefix=x2c("3031300d060960864801650304020105000420")
  padLen=k-3-prefix~length-digest~length
  if padLen<8 then raise syntax 88.900 array("RS256 modulus too small")
  em="00"x||"01"x||"ff"x~copies(padLen)||"00"x||prefix||digest
  sig=.RSA~sign(x2d(c2x(em)),key~d,key~n)
  return input||"."||.AuthBase64Url~encode(x2c(sig~d2x(k*2)))
::method verify
  expose verifier
  use strict arg token, ignoredReference=""
  return verifier~verify(token,ignoredReference)

::requires "AuthCodec.cls"
::requires "CryptoAuth.cls"
::requires "json.cls"

/* Public-key JWT verification for the dominant external OIDC RS256 profile.
 * RSA modular exponentiation is delegated to ooRexx Crypto; this layer only
 * validates the PKCS#1 v1.5 / SHA-256 encoding and JWK identity.
 */
::class JwksSource public
::method keyFor abstract

::class StaticJwksSource subclass JwksSource public
::method init
  expose keys
  use strict arg jwks
  keys=.directory~new
  if \jwks~isa(.Directory) | \jwks~hasIndex("keys") then raise syntax 88.900 array("JWKS must contain keys")
  do key over jwks["keys"]
    if \key~isa(.Directory) then iterate
    if \key~hasIndex("kid") then iterate
    if \key~hasIndex("kty") | key["kty"]<>"RSA" then iterate
    if \key~hasIndex("n") | \key~hasIndex("e") then iterate
    keys[key["kid"]]=key
  end
::method fromJson class
  use strict arg text
  return self~new(.JSON~fromJSON(text))
::method keyFor
  expose keys
  use strict arg kid
  if \keys~hasIndex(kid) then return .nil
  return keys[kid]

::class Rs256JwtAuthority subclass JwtAuthority public
::method init
  expose jwks
  use strict arg jwksSource
  jwks=jwksSource
::method sign
  use strict arg claims, secretReference
  raise syntax 88.900 array("Rs256JwtAuthority is verify-only; provider signing requires private-key authority")
::method verify
  expose jwks
  numeric digits 3000
  use strict arg token, ignoredReference=""
  first=token~pos("."); if first=0 then return .JwtVerificationResult~new(.false,"MALFORMED")
  second=token~pos(".",first+1); if second=0 | token~pos(".",second+1)>0 then return .JwtVerificationResult~new(.false,"MALFORMED")
  h64=token~left(first-1); p64=token~substr(first+1,second-first-1); s64=token~substr(second+1)
  signal on syntax name badRsJwt
  header=.JSON~fromJSON(.AuthBase64Url~decode(h64)); claims=.JSON~fromJSON(.AuthBase64Url~decode(p64))
  signal off syntax
  if \header~isa(.Directory) | \claims~isa(.Directory) then return .JwtVerificationResult~new(.false,"MALFORMED_JSON")
  if \header~hasIndex("alg") | header["alg"]<>"RS256" then return .JwtVerificationResult~new(.false,"ALGORITHM_REJECTED")
  if \header~hasIndex("kid") then return .JwtVerificationResult~new(.false,"KID_MISSING")
  key=jwks~keyFor(header["kid"])
  if key==.nil then return .JwtVerificationResult~new(.false,"KEY_NOT_FOUND")
  if key["kty"]<>"RSA" then return .JwtVerificationResult~new(.false,"KEY_TYPE_REJECTED")
  modulusBytes=.AuthBase64Url~decode(key["n"]); exponentBytes=.AuthBase64Url~decode(key["e"]); signatureBytes=.AuthBase64Url~decode(s64)
  n=x2d(c2x(modulusBytes)); e=x2d(c2x(exponentBytes)); sig=x2d(c2x(signatureBytes))
  k=modulusBytes~length
  if signatureBytes~length<>k then return .JwtVerificationResult~new(.false,"BAD_SIGNATURE_LENGTH")
  recovered=.RSA~verify(sig,e,n)
  em=x2c(recovered~d2x(k*2))
  digest=x2c(.SHA256~new(h64 || "." || p64)~digest)
  prefix=x2c("3031300d060960864801650304020105000420")
  tail="00"x || prefix || digest
  padLen=k-3-prefix~length-digest~length
  if padLen<8 then return .JwtVerificationResult~new(.false,"KEY_TOO_SMALL")
  expected="00"x || "01"x || "ff"x~copies(padLen) || tail
  if \.CryptoUtils~secureEquals(em,expected) then return .JwtVerificationResult~new(.false,"BAD_SIGNATURE")
  return .JwtVerificationResult~new(.true,"OK",claims,header)
badRsJwt:
  signal off syntax
  return .JwtVerificationResult~new(.false,"MALFORMED_JSON")
