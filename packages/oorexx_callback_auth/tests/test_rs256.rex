numeric digits 2000
n="1459914233714405148873742313619381705343076828846704521235666647638677592757429056937868089445252939" || "0426559640669962340019424772106087134681977388082192695190753757455345352554416564199852013527028716" || "0294125076034753782378929770183481323118911626970793065658550835316896762347335550221286185350165177" || "435063137" + 0
e=65537
d="3781159376088059111186490384267724349068981810709059392931352621728018288823809575119912866051806366" || "9850683330138996408058000226090410458838806198835335576412258610483531080618602602526083520310322730" || "9376220042361648809531396222924003351238493346557499126280754325899727057621972442264331679461157170" || "77348353" + 0
k=128
header=.directory~new; header["alg"]="RS256"; header["typ"]="JWT"; header["kid"]="k1"
claims=.directory~new; claims["iss"]="https://external.example"; claims["sub"]="alice"; claims["aud"]="app"; claims["iat"]=100; claims["exp"]=200
h64=.AuthBase64Url~encode(.JSON~toJSON(header)); p64=.AuthBase64Url~encode(.JSON~toJSON(claims)); input=h64||"."||p64
digest=x2c(.SHA256~new(input)~digest); prefix=x2c("3031300d060960864801650304020105000420")
padLen=k-3-prefix~length-digest~length
em="00"x||"01"x||"ff"x~copies(padLen)||"00"x||prefix||digest
m=x2d(c2x(em)); sig=.RSA~sign(m,d,n); sigBytes=x2c(sig~d2x(k*2))
token=input||"."||.AuthBase64Url~encode(sigBytes)
key=.directory~new; key["kty"]="RSA"; key["kid"]="k1"; key["alg"]="RS256"
key["n"] = .AuthBase64Url~encode(x2c(n~d2x(k*2)))
eh=e~d2x; if eh~length//2=1 then eh="0"||eh
key["e"] = .AuthBase64Url~encode(x2c(eh))
jwks=.directory~new; jwks["keys"]=.array~of(key)
v=.Rs256JwtAuthority~new(.StaticJwksSource~new(jwks))~verify(token)
if \v~ok then do; say "FAIL RS256" v~code; exit 1; end
if v~claims["sub"]<>"alice" then do; say "FAIL claims"; exit 1; end
say "PASS RS256 JWT verification"
::requires "JwtOidc.cls"
