text='{"issuer":"https://id.example","authorization_endpoint":"https://id.example/authorize","token_endpoint":"https://id.example/token","jwks_uri":"https://id.example/jwks"}'
d=.OidcDiscovery~parse(text)
if d["issuer"]<>"https://id.example" then do; say "FAIL discovery"; exit 1; end
say "PASS discovery"
::requires "JwtOidc.cls"
