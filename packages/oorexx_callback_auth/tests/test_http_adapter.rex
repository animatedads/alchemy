secrets=.MemoryAuthSecretAuthority~new; secrets~put("s","secret")
random=.DeterministicAuthRandomSource~new("http")
jwt=.Hs256JwtAuthority~new(secrets)
provider=.OidcProvider~new("https://id.example",random,jwt,secrets)
provider~registerClient(.OidcClientRegistration~new("app",.array~of("https://app.example/cb"),"s"))
adapter=.OidcProviderHttpAdapter~new(provider)
call ok adapter~discovery~status=200,"discovery status"
config=.OidcClientConfiguration~new("https://id.example","https://id.example/authorize","https://id.example/token","app","s","https://app.example/cb")
client=.OidcClient~new(config,random,jwt)
start=client~beginLogin(100)
q=.AuthUriCodec~parseQuery(start~authorizationUri~substr(start~authorizationUri~pos("?")+1))
r=adapter~authorize(q,"alice",101)
call ok r~status=302,"authorize redirect"
call ok r~headers["location"]~pos("code=")>0,"authorize code in callback"
say "PASS HTTP adapter"
exit 0
ok: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
 return
::requires "CallbackAuth.cls"
