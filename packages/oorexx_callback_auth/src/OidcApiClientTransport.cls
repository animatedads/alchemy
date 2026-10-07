/* Optional API Client integration. Network/TLS authority remains with
 * oorexx_api_client; this adapter only maps OIDC HTTP payloads.
 */
::class ApiClientOidcDiscovery public
::method init
  expose api
  use strict arg apiClient
  api=apiClient
::method fetch
  expose api
  use strict arg issuer
  base=issuer~string~strip
  if base~right(1)="/" then base=base~left(base~length-1)
  url=base || "/.well-known/openid-configuration"
  h=.directory~new; h["accept"]="application/json"
  r=api~execute(.ApiRequest~new("oidc-discovery","GET",url,h))
  if \r~ok then raise syntax 88.900 array("OIDC discovery HTTP failure: " || r~status || "/" || r~errorCode)
  doc=.OidcDiscovery~parse(r~body)
  if doc["issuer"]<>base then raise syntax 88.900 array("OIDC discovery issuer mismatch")
  return doc

::class ApiClientJwksSource subclass JwksSource public
::method init
  expose api uri cache
  use strict arg apiClient, jwksUri
  api=apiClient; uri=jwksUri~string; cache=.nil
::method refresh
  expose api uri cache
  h=.directory~new; h["accept"]="application/json"
  r=api~execute(.ApiRequest~new("oidc-jwks","GET",uri,h))
  if \r~ok then do; cache=.nil; return .false; end
  signal on syntax name badJwks
  cache=.StaticJwksSource~fromJson(r~body)
  signal off syntax
  return .true
badJwks:
  signal off syntax
  cache=.nil; return .false
::method keyFor
  expose cache
  use strict arg kid
  if cache==.nil then ignore=self~refresh
  if cache==.nil then return .nil
  key=cache~keyFor(kid)
  if key\==.nil then return key
  ignore=self~refresh
  if cache==.nil then return .nil
  return cache~keyFor(kid)

::class ApiClientOidcTokenTransport subclass OidcTokenTransport public
::method init
  expose api secrets
  use strict arg apiClient, secretAuthority
  api=apiClient; secrets=secretAuthority
::method exchange
  expose api secrets
  use strict arg config, code, transaction, nowSeconds
  form=.directory~new; form["grant_type"]="authorization_code"; form["code"]=code; form["redirect_uri"]=config~redirectUri
  form["client_id"]=config~clientId; form["client_secret"]=secrets~resolve(config~secretReference); form["code_verifier"]=transaction~codeVerifier
  headers=.directory~new; headers["content-type"]="application/x-www-form-urlencoded"; headers["accept"]="application/json"
  body=.AuthUriCodec~buildQuery(form)
  requestId="oidc-token-" || nowSeconds || "-" || code~left(8)
  r=api~execute(.ApiRequest~new(requestId,"POST",config~tokenEndpoint,headers,body))
  if r~status=0 then return .OidcTokenResult~new(.false,"transport_error")
  signal on syntax name malformedResponse
  parsed=.JSON~fromJSON(r~body)
  signal off syntax
  if \parsed~isa(.Directory) then return .OidcTokenResult~new(.false,"malformed_response")
  if \r~ok then do
    if parsed~hasIndex("error") then return .OidcTokenResult~new(.false,parsed["error"])
    return .OidcTokenResult~new(.true,"OK",parsed)
  end
  if parsed~hasIndex("error") then return .OidcTokenResult~new(.false,parsed["error"])
  return .OidcTokenResult~new(.false,"http_" || r~status)
malformedResponse:
  signal off syntax
  return .OidcTokenResult~new(.false,"malformed_response")

::requires "OidcClient.cls"
::requires "ApiClient.cls"
::requires "json.cls"
