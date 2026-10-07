/* HTTP-neutral adapter objects. A real server owns sockets/TLS/request parsing;
 * these methods only project semantic OIDC results into HTTP status/headers/body.
 */
::class CallbackAuthHttpResponse public
::attribute status get
::attribute headers get
::attribute body get
::method init
  expose status headers body
  use strict arg statusArg, headersArg=.nil, bodyArg=""
  status=statusArg+0
  if headersArg==.nil then headers=.directory~new; else headers=headersArg
  body=bodyArg~string

::class OidcProviderHttpAdapter public
::method init
  expose provider
  use strict arg providerArg
  provider=providerArg

::method discovery
  expose provider
  h=.directory~new; h["content-type"]="application/json"
  return .CallbackAuthHttpResponse~new(200,h,.JSON~toJSON(provider~discoveryDocument))

::method jwks
  expose provider
  h=.directory~new; h["content-type"]="application/json"
  return .CallbackAuthHttpResponse~new(200,h,.JSON~toJSON(provider~jwks))

::method authorize
  expose provider
  use strict arg queryParameters, authenticatedSubject, nowSeconds
  result=provider~authorize(queryParameters,authenticatedSubject,nowSeconds)
  if result~redirectUri<>"" then do
    h=.directory~new; h["location"]=result~callbackUri; h["cache-control"]="no-store"
    return .CallbackAuthHttpResponse~new(302,h,"")
  end
  d=.directory~new; d["error"]=result~errorCode
  h=.directory~new; h["content-type"]="application/json"; h["cache-control"]="no-store"
  return .CallbackAuthHttpResponse~new(400,h,.JSON~toJSON(d))

::method token
  expose provider
  use strict arg formParameters, clientAuthentication, nowSeconds
  result=provider~token(formParameters,clientAuthentication,nowSeconds)
  h=.directory~new; h["content-type"]="application/json"; h["cache-control"]="no-store"; h["pragma"]="no-cache"
  if result~ok then return .CallbackAuthHttpResponse~new(200,h,.JSON~toJSON(result~body))
  d=.directory~new; d["error"]=result~code
  return .CallbackAuthHttpResponse~new(400,h,.JSON~toJSON(d))

::requires "OidcProvider.cls"
::requires "json.cls"
