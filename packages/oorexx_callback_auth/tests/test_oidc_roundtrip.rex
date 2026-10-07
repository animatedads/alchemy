secrets=.MemoryAuthSecretAuthority~new
secrets~put("sso-client","correct horse battery staple")
random=.DeterministicAuthRandomSource~new("oidc-test")
jwt=.Hs256JwtAuthority~new(secrets)
provider=.OidcProvider~new("https://id.example",random,jwt,secrets)
provider~registerClient(.OidcClientRegistration~new("app-1",.array~of("https://app.example/callback"),"sso-client"))
config=.OidcClientConfiguration~new("https://id.example","https://id.example/authorize","https://id.example/token","app-1","sso-client","https://app.example/callback")
client=.OidcClient~new(config,random,jwt)
start=client~beginLogin(1000)
call ok start~authorizationUri~pos("code_challenge_method=S256")>0,"S256 in authorization URI"
params=.AuthUriCodec~parseQuery(start~authorizationUri~substr(start~authorizationUri~pos("?")+1))
authz=provider~authorize(params,"alice",1001)
call ok authz~ok,"provider authorize"
callback=authz~parameters
transport=.InProcessOidcTokenTransport~new(provider,secrets)
completed=client~completeCallback(callback,start~transaction,transport,1002)
call ok completed~ok,"client callback"
call eq completed~identity~subject,"alice","subject"
/* authorization code is one-time */
again=client~completeCallback(callback,start~transaction,transport,1003)
call ok \again~ok & again~code="TOKEN_INVALID_GRANT","code replay rejected"
say "PASS OIDC roundtrip"
exit 0
ok: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
 return
eq: procedure
 use arg a,e,l
 if a\==e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "CallbackAuth.cls"
