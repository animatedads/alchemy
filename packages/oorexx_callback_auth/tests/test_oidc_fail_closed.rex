secrets=.MemoryAuthSecretAuthority~new; secrets~put("s","secret-value")
random=.DeterministicAuthRandomSource~new("fail")
jwt=.Hs256JwtAuthority~new(secrets)
provider=.OidcProvider~new("https://id.example",random,jwt,secrets)
provider~registerClient(.OidcClientRegistration~new("app",.array~of("https://app.example/cb"),"s"))
config=.OidcClientConfiguration~new("https://id.example","https://id.example/authorize","https://id.example/token","app","s","https://app.example/cb")
client=.OidcClient~new(config,random,jwt)
start=client~beginLogin(10)
params=.AuthUriCodec~parseQuery(start~authorizationUri~substr(start~authorizationUri~pos("?")+1))
params["redirect_uri"]="https://evil.example/cb"
a=provider~authorize(params,"alice",11)
call ok \a~ok,"redirect mismatch rejected"
cb=.directory~new; cb["code"]="anything"; cb["state"]="wrong"
r=client~completeCallback(cb,start~transaction,.InProcessOidcTokenTransport~new(provider,secrets),12)
call ok \r~ok & r~code="STATE_MISMATCH","state mismatch rejected before token exchange"
say "PASS OIDC fail closed"
exit 0
ok: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
 return
::requires "CallbackAuth.cls"
