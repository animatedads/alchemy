numeric digits 2000
n=("1459914233714405148873742313619381705343076828846704521235666647638677592757429056937868089445252939" ||,
   "0426559640669962340019424772106087134681977388082192695190753757455345352554416564199852013527028716" ||,
   "0294125076034753782378929770183481323118911626970793065658550835316896762347335550221286185350165177" ||,
   "435063137")+0
e=65537
d=("3781159376088059111186490384267724349068981810709059392931352621728018288823809575119912866051806366" ||,
   "9850683330138996408058000226090410458838806198835335576412258610483531080618602602526083520310322730" ||,
   "9376220042361648809531396222924003351238493346557499126280754325899727057621972442264331679461157170" ||,
   "77348353")+0
key=.Rs256KeyMaterial~new("provider-k1",n,e,d)
signer=.Rs256PrivateKeyJwtAuthority~new(key)
secrets=.MemoryAuthSecretAuthority~new; secrets~put("client-secret","client-password")
random=.DeterministicAuthRandomSource~new("rs-provider")
provider=.OidcProvider~new("https://id.example",random,signer,secrets)
provider~registerClient(.OidcClientRegistration~new("app",.array~of("https://app.example/cb"),"client-secret"))
config=.OidcClientConfiguration~new("https://id.example","https://id.example/authorize","https://id.example/token","app","client-secret","https://app.example/cb")
verifier=.Rs256JwtAuthority~new(.StaticJwksSource~new(provider~jwks))
client=.OidcClient~new(config,random,verifier)
start=client~beginLogin(100)
params=.AuthUriCodec~parseQuery(start~authorizationUri~substr(start~authorizationUri~pos("?")+1))
a=provider~authorize(params,"alice",101)
if \a~ok then do; say "FAIL authorize"; exit 1; end
result=client~completeCallback(a~parameters,start~transaction,.InProcessOidcTokenTransport~new(provider,secrets),102)
if \result~ok then do; say "FAIL callback" result~code; exit 1; end
if result~identity~subject<>"alice" then do; say "FAIL subject"; exit 1; end
disc=provider~discoveryDocument
if disc["id_token_signing_alg_values_supported"][1]<>"RS256" then do; say "FAIL discovery alg"; exit 1; end
if provider~jwks["keys"]~items<>1 then do; say "FAIL jwks"; exit 1; end
say "PASS OIDC RS256 provider/client"
::requires "CallbackAuth.cls"
