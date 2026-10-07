/* Client-side OIDC authorization-code + PKCE state machine.
 * Browser launching and callback HTTP routing are owned by applications.
 */
::options digits 50

::class OidcClientConfiguration public
::attribute issuer get
::attribute authorizationEndpoint get
::attribute tokenEndpoint get
::attribute clientId get
::attribute secretReference get
::attribute redirectUri get
::attribute scope get
::method init
  expose issuer authorizationEndpoint tokenEndpoint clientId secretReference redirectUri scope
  use strict arg issuerArg, authorizationArg, tokenArg, clientIdArg, secretRefArg, redirectArg, scopeArg="openid profile email"
  issuer=issuerArg~string; authorizationEndpoint=authorizationArg~string; tokenEndpoint=tokenArg~string; clientId=clientIdArg~string
  secretReference=secretRefArg~string; redirectUri=redirectArg~string; scope=scopeArg~string

::class OidcLoginTransaction public
::attribute state get
::attribute nonce get
::attribute codeVerifier get
::attribute codeChallenge get
::attribute redirectUri get
::attribute createdAt get
::method init
  expose state nonce codeVerifier codeChallenge redirectUri createdAt
  use strict arg stateArg, nonceArg, verifierArg, challengeArg, redirectArg, createdAtArg
  state=stateArg; nonce=nonceArg; codeVerifier=verifierArg; codeChallenge=challengeArg; redirectUri=redirectArg; createdAt=createdAtArg

::class OidcLoginStart public
::attribute authorizationUri get
::attribute transaction get
::method init
  expose authorizationUri transaction
  use strict arg uriArg, txArg
  authorizationUri=uriArg; transaction=txArg

::class OidcIdentity public
::attribute subject get
::attribute claims get
::attribute accessToken get
::attribute idToken get
::method init
  expose subject claims accessToken idToken
  use strict arg subjectArg, claimsArg, accessArg, idArg
  subject=subjectArg; claims=claimsArg; accessToken=accessArg; idToken=idArg
::method claim
  expose claims
  use strict arg name
  if \claims~hasIndex(name) then return .nil
  return claims[name]

::class OidcCompletionResult public
::attribute ok get
::attribute code get
::attribute identity get
::method init
  expose ok code identity
  use strict arg okArg, codeArg, identityArg=.nil
  ok=okArg==.true; code=codeArg; identity=identityArg

::class OidcTokenTransport public
::method exchange abstract

::class InProcessOidcTokenTransport subclass OidcTokenTransport public
::method init
  expose provider secrets
  use strict arg providerArg, secretAuthority
  provider=providerArg; secrets=secretAuthority
::method exchange
  expose provider secrets
  use strict arg config, code, transaction, nowSeconds
  params=.directory~new; params["grant_type"]="authorization_code"; params["code"]=code
  params["redirect_uri"]=config~redirectUri; params["code_verifier"]=transaction~codeVerifier
  auth=.directory~new; auth["client_id"]=config~clientId; auth["client_secret"]=secrets~resolve(config~secretReference)
  return provider~token(params,auth,nowSeconds)

::class OidcClient public
::method init
  expose config random jwt maxTransactionAge clockSkew
  use strict arg configuration, randomSource, jwtAuthority, maxAge=600, skew=60
  config=configuration; random=randomSource; jwt=jwtAuthority; maxTransactionAge=maxAge; clockSkew=skew
::method beginLogin
  expose config random
  use strict arg nowSeconds
  state=.AuthBase64Url~encode(random~bytes(24)); nonce=.AuthBase64Url~encode(random~bytes(24)); verifier=.AuthBase64Url~encode(random~bytes(32))
  challenge=.Pkce~challenge(verifier)
  tx=.OidcLoginTransaction~new(state,nonce,verifier,challenge,config~redirectUri,nowSeconds)
  params=.directory~new; params["response_type"]="code"; params["client_id"]=config~clientId; params["redirect_uri"]=config~redirectUri
  params["scope"]=config~scope; params["state"]=state; params["nonce"]=nonce; params["code_challenge"]=challenge; params["code_challenge_method"]="S256"
  return .OidcLoginStart~new(config~authorizationEndpoint || "?" || .AuthUriCodec~buildQuery(params),tx)
::method completeCallback
  expose config jwt maxTransactionAge clockSkew
  use strict arg callbackParams, transaction, tokenTransport, nowSeconds
  if transaction==.nil then return .OidcCompletionResult~new(.false,"TRANSACTION_MISSING")
  if nowSeconds-transaction~createdAt>maxTransactionAge then return .OidcCompletionResult~new(.false,"TRANSACTION_EXPIRED")
  if callbackParams~hasIndex("error") then return .OidcCompletionResult~new(.false,"PROVIDER_" || callbackParams["error"]~upper)
  if \callbackParams~hasIndex("state") | \.CryptoUtils~secureEquals(callbackParams["state"],transaction~state) then return .OidcCompletionResult~new(.false,"STATE_MISMATCH")
  if \callbackParams~hasIndex("code") then return .OidcCompletionResult~new(.false,"CODE_MISSING")
  tokenResult=tokenTransport~exchange(config,callbackParams["code"],transaction,nowSeconds)
  if \tokenResult~ok then return .OidcCompletionResult~new(.false,"TOKEN_" || tokenResult~code~upper)
  body=tokenResult~body
  if \body~hasIndex("id_token") then return .OidcCompletionResult~new(.false,"ID_TOKEN_MISSING")
  verified=jwt~verify(body["id_token"],config~secretReference)
  if \verified~ok then return .OidcCompletionResult~new(.false,"JWT_" || verified~code)
  c=verified~claims
  do key over .array~of("iss","sub","aud","exp","iat","nonce")
    if \c~hasIndex(key) then return .OidcCompletionResult~new(.false,"CLAIM_MISSING_" || key~upper)
  end
  if c["iss"]<>config~issuer then return .OidcCompletionResult~new(.false,"ISSUER_MISMATCH")
  if c["aud"]<>config~clientId then return .OidcCompletionResult~new(.false,"AUDIENCE_MISMATCH")
  if c["nonce"]<>transaction~nonce then return .OidcCompletionResult~new(.false,"NONCE_MISMATCH")
  if c["exp"]+0 < nowSeconds-clockSkew then return .OidcCompletionResult~new(.false,"ID_TOKEN_EXPIRED")
  if c["iat"]+0 > nowSeconds+clockSkew then return .OidcCompletionResult~new(.false,"ID_TOKEN_FROM_FUTURE")
  access=""; if body~hasIndex("access_token") then access=body["access_token"]
  ident=.OidcIdentity~new(c["sub"],c,access,body["id_token"])
  return .OidcCompletionResult~new(.true,"OK",ident)

::requires "OidcProvider.cls"
