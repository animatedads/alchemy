/* Provider-side OIDC authorization-code + PKCE core.
 * Authentication UI, HTTP sockets and identity directory remain external.
 */
::options digits 50

::class OidcClientRegistration public
::attribute clientId get
::attribute redirectUris get
::attribute secretReference get
::method init
  expose clientId redirectUris secretReference
  use strict arg clientIdArg, redirectUrisArg, secretReferenceArg
  clientId=clientIdArg~string; redirectUris=redirectUrisArg; secretReference=secretReferenceArg~string
::method allowsRedirect
  expose redirectUris
  use strict arg uri
  do v over redirectUris
    if v~string==uri~string then return .true
  end
  return .false

::class OidcAuthorizationResult public
::attribute ok get
::attribute code get
::attribute redirectUri get
::attribute state get
::attribute errorCode get
::method init
  expose ok code redirectUri state errorCode
  use strict arg okArg, codeArg="", redirectArg="", stateArg="", errorArg=""
  ok=okArg==.true; code=codeArg; redirectUri=redirectArg; state=stateArg; errorCode=errorArg
::method parameters
  expose ok code state errorCode
  d=.directory~new
  if ok then d["code"]=code; else d["error"]=errorCode
  if state<>"" then d["state"]=state
  return d
::method callbackUri
  expose redirectUri
  sep="?"; if redirectUri~pos("?")>0 then sep="&"
  return redirectUri || sep || .AuthUriCodec~buildQuery(self~parameters)

::class OidcAuthorizationCodeRecord public
::attribute code get
::attribute clientId get
::attribute redirectUri get
::attribute subject get
::attribute nonce get
::attribute scope get
::attribute codeChallenge get
::attribute authTime get
::attribute expiresAt get
::attribute used
::method init
  expose code clientId redirectUri subject nonce scope codeChallenge authTime expiresAt used
  use strict arg codeArg, clientIdArg, redirectArg, subjectArg, nonceArg, scopeArg, challengeArg, authTimeArg, expiresArg
  code=codeArg; clientId=clientIdArg; redirectUri=redirectArg; subject=subjectArg; nonce=nonceArg; scope=scopeArg
  codeChallenge=challengeArg; authTime=authTimeArg; expiresAt=expiresArg; used=.false

::class OidcTokenResult public
::attribute ok get
::attribute code get
::attribute body get
::method init
  expose ok code body
  use strict arg okArg, codeArg, bodyArg=.nil
  ok=okArg==.true; code=codeArg~string; if bodyArg==.nil then body=.directory~new; else body=bodyArg

::class OidcProvider public
::method init
  expose issuer authorizationEndpoint tokenEndpoint jwksUri userInfoEndpoint registrations codes random jwt secrets codeLifetime tokenLifetime
  use strict arg issuerArg, randomSource, jwtAuthority, secretAuthority, codeLifetimeArg=120, tokenLifetimeArg=3600
  issuer=issuerArg~string~strip
  if issuer~right(1)="/" then issuer=issuer~left(issuer~length-1)
  authorizationEndpoint=issuer || "/authorize"; tokenEndpoint=issuer || "/token"; jwksUri=issuer || "/jwks"; userInfoEndpoint=issuer || "/userinfo"
  registrations=.directory~new; codes=.directory~new; random=randomSource; jwt=jwtAuthority; secrets=secretAuthority
  codeLifetime=codeLifetimeArg; tokenLifetime=tokenLifetimeArg
::method registerClient
  expose registrations
  use strict arg registration
  registrations[registration~clientId]=registration; return .true
::method discoveryDocument
  expose issuer authorizationEndpoint tokenEndpoint jwksUri userInfoEndpoint jwt
  d=.directory~new; d["issuer"]=issuer; d["authorization_endpoint"]=authorizationEndpoint; d["token_endpoint"]=tokenEndpoint
  d["jwks_uri"]=jwksUri; d["userinfo_endpoint"]=userInfoEndpoint
  d["response_types_supported"]=.array~of("code")
  d["subject_types_supported"]=.array~of("public")
  if jwt~hasMethod("ALGORITHM") then d["id_token_signing_alg_values_supported"]=.array~of(jwt~algorithm)
  else d["id_token_signing_alg_values_supported"]=.array~new
  d["code_challenge_methods_supported"]=.array~of("S256")
  return d
::method jwks
  expose jwt
  if jwt~hasMethod("JWKS") then return jwt~jwks
  d=.directory~new; d["keys"]=.array~new
  return d
::method authorize
  expose registrations codes random codeLifetime
  use strict arg params, subject, nowSeconds
  clientId=self~required(params,"client_id"); redirectUri=self~required(params,"redirect_uri")
  state=""; if params~hasIndex("state") then state=params["state"]
  if \registrations~hasIndex(clientId) then return .OidcAuthorizationResult~new(.false,"",redirectUri,state,"unauthorized_client")
  reg=registrations[clientId]
  if \reg~allowsRedirect(redirectUri) then return .OidcAuthorizationResult~new(.false,"","",state,"invalid_request")
  if self~required(params,"response_type")<>"code" then return .OidcAuthorizationResult~new(.false,"",redirectUri,state,"unsupported_response_type")
  scope=self~required(params,"scope")
  if wordpos("openid",scope)=0 then return .OidcAuthorizationResult~new(.false,"",redirectUri,state,"invalid_scope")
  if self~required(params,"code_challenge_method")<>"S256" then return .OidcAuthorizationResult~new(.false,"",redirectUri,state,"invalid_request")
  challenge=self~required(params,"code_challenge")
  nonce=self~required(params,"nonce")
  code=.AuthBase64Url~encode(random~bytes(32))
  record=.OidcAuthorizationCodeRecord~new(code,clientId,redirectUri,subject,nonce,scope,challenge,nowSeconds,nowSeconds+codeLifetime)
  codes[code]=record
  return .OidcAuthorizationResult~new(.true,code,redirectUri,state,"")
::method token
  expose registrations codes random jwt tokenLifetime
  use strict arg params, clientAuthentication, nowSeconds
  if self~required(params,"grant_type")<>"authorization_code" then return .OidcTokenResult~new(.false,"unsupported_grant_type")
  code=self~required(params,"code")
  if \codes~hasIndex(code) then return .OidcTokenResult~new(.false,"invalid_grant")
  record=codes[code]
  if record~used | record~expiresAt<nowSeconds then return .OidcTokenResult~new(.false,"invalid_grant")
  clientId=self~required(clientAuthentication,"client_id")
  if clientId<>record~clientId | \registrations~hasIndex(clientId) then return .OidcTokenResult~new(.false,"invalid_client")
  reg=registrations[clientId]
  suppliedSecret=self~required(clientAuthentication,"client_secret")
  expectedSecret=self~secretFor(reg~secretReference)
  if \.CryptoUtils~secureEquals(suppliedSecret,expectedSecret) then return .OidcTokenResult~new(.false,"invalid_client")
  if self~required(params,"redirect_uri")<>record~redirectUri then return .OidcTokenResult~new(.false,"invalid_grant")
  verifier=self~required(params,"code_verifier")
  if \.Pkce~verify(verifier,record~codeChallenge) then return .OidcTokenResult~new(.false,"invalid_grant")
  record~used=.true
  claims=.directory~new
  claims["iss"]=self~issuer; claims["sub"]=record~subject; claims["aud"]=clientId
  claims["iat"]=nowSeconds; claims["exp"]=nowSeconds+tokenLifetime; claims["auth_time"]=record~authTime; claims["nonce"]=record~nonce
  idToken=jwt~sign(claims,reg~secretReference)
  body=.directory~new; body["access_token"]=.AuthBase64Url~encode(random~bytes(32)); body["token_type"]="Bearer"
  body["expires_in"]=tokenLifetime; body["id_token"]=idToken; body["scope"]=record~scope
  return .OidcTokenResult~new(.true,"OK",body)
::method issuer
  expose issuer
  return issuer
::method secretFor private
  expose secrets
  use strict arg ref
  return secrets~resolve(ref)
::method required private
  use strict arg d, key
  if d==.nil | \d~hasIndex(key) | d[key]~string="" then raise syntax 88.900 array("missing required OIDC field: " || key)
  return d[key]~string

::requires "JwtOidc.cls"
