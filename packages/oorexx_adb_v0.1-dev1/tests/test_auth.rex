
/* Deterministic RSA-2048 fixture generated once for protocol qualification. */
fixture=linesource('fixture_rsa.txt')
parse var fixture n '|' e '|' d '|' tokenHex '|' signatureHex '|' publicBase64
key=.AdbRsaKey~new(n,e,d,'oorexx@test')
token=x2c(tokenHex)
sig=key~signToken(token)
call assert c2x(sig)=signatureHex,'ADB RSA signature vector'
pub=key~androidPublicKeyBinary
call assert pub~length=524,'Android public key binary length'
call assert c2x(substr(pub,1,4))='40000000','64-word modulus prefix'
text=key~publicKeyText
call assert text=publicBase64||' oorexx@test','complete Android public key encoding'
call assert text~right(11)='oorexx@test','public key comment'
a=.AdbAuthenticator~new(key)
r=a~responseForToken(token)
call assert r['type']=2,'first response signature'
r=a~responseForToken(token)
call assert r['type']=3,'fallback public key'
call assert r['payload']~right(1)='00'x,'public key payload nul'
say 'ADB AUTH: OK'
exit 0

linesource: procedure
  use strict arg name
  f=.stream~new(name); f~open('read'); line=f~linein; f~close; return line

assert: procedure
  use strict arg ok,label
  if \ok then do; say 'FAIL' label; exit 1; end
return

::requires "AdbAuth.cls"
