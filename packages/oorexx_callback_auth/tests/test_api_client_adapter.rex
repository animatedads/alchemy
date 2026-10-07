api=.ApiClient~new(.FakeOidcTransport~new)
d=.ApiClientOidcDiscovery~new(api)~fetch("https://id.example")
if d["token_endpoint"]<>"https://id.example/token" then do; say "FAIL discovery adapter"; exit 1; end
source=.ApiClientJwksSource~new(api,"https://id.example/jwks")
if source~keyFor("missing")\==.nil then do; say "FAIL jwks adapter"; exit 1; end
say "PASS API Client OIDC adapter"
exit 0

::class FakeOidcTransport subclass ApiTransport public
::method execute
  use strict arg request, session=.nil
  h=.directory~new; h["content-type"]="application/json"
  if request~url="https://id.example/.well-known/openid-configuration" then do
    b='{"issuer":"https://id.example","authorization_endpoint":"https://id.example/authorize","token_endpoint":"https://id.example/token","jwks_uri":"https://id.example/jwks"}'
    return .ApiResponse~new(request~id,200,h,b,1)
  end
  if request~url="https://id.example/jwks" then do
    b='{"keys":[]}'
    return .ApiResponse~new(request~id,200,h,b,1)
  end
  return .ApiResponse~new(request~id,404,h,'{"error":"not_found"}',1)

::requires "OidcApiClientTransport.cls"
