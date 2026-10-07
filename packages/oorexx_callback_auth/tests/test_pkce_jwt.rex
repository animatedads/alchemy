verifier="dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
call eq .Pkce~challenge(verifier),"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM","RFC7636 S256"
secrets=.MemoryAuthSecretAuthority~new
secrets~put("client-secret","0123456789abcdef0123456789abcdef")
jwt=.Hs256JwtAuthority~new(secrets)
claims=.directory~new; claims["iss"]="https://id.example"; claims["sub"]="alice"; claims["aud"]="app"; claims["iat"]=100; claims["exp"]=200
wire=jwt~sign(claims,"client-secret")
r=jwt~verify(wire,"client-secret")
call ok r~ok,"jwt verify"
call eq r~claims["sub"],"alice","jwt claims"
say "PASS PKCE JWT"
exit 0
eq: procedure
 use arg a,e,l
 if a\==e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
ok: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
 return
::requires "JwtOidc.cls"
