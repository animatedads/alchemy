/* Complete provider/client state machine without HTTP sockets. */
secrets=.MemoryAuthSecretAuthority~new; secrets~put("client-secret","demo-secret")
random=.DeterministicAuthRandomSource~new("demo")
jwt=.Hs256JwtAuthority~new(secrets)
provider=.OidcProvider~new("https://id.example",random,jwt,secrets)
provider~registerClient(.OidcClientRegistration~new("demo-app",.array~of("https://app.example/callback"),"client-secret"))
config=.OidcClientConfiguration~new("https://id.example","https://id.example/authorize","https://id.example/token","demo-app","client-secret","https://app.example/callback")
client=.OidcClient~new(config,random,jwt)
start=client~beginLogin(1000)
say "Open:" start~authorizationUri
params=.AuthUriCodec~parseQuery(start~authorizationUri~substr(start~authorizationUri~pos("?")+1))
a=provider~authorize(params,"alice",1001)
result=client~completeCallback(a~parameters,start~transaction,.InProcessOidcTokenTransport~new(provider,secrets),1002)
say "Authenticated subject:" result~identity~subject
::requires "CallbackAuth.cls"
