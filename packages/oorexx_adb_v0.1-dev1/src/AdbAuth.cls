/*----------------------------------------------------------------------------*/
/* ooRexx ADB Authentication v0.1-dev1                                        */
/*                                                                            */
/* ADB's AUTH_SIGNATURE is RSA PKCS#1 v1.5 over a 20-byte value using the     */
/* SHA-1 DigestInfo identifier.  ADB already supplies the 20-byte challenge;  */
/* this layer does not hash it a second time.                                 */
/*                                                                            */
/* The RSA primitive is delegated to ooRexx Crypto.                           */
/*----------------------------------------------------------------------------*/

::class AdbAuthBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "adb.auth/0.1"

::class AdbRsaKey public
::attribute n get
::attribute e get
::attribute d get
::attribute comment get

::method init
  expose n e d comment
  use strict arg nArg,eArg=65537,dArg=.nil,commentArg='oorexx@host'
  numeric digits 2000
  n=nArg+0; e=eArg+0; d=dArg
  if d<>.nil then d=d+0
  comment=commentArg~string
  if self~modulusBytes<>256 then raise syntax 93.900 array('ADB legacy RSA authentication requires a 2048-bit key')

::method hasPrivate
  expose d
  return d<>.nil

::method modulusBytes
  expose n
  numeric digits 2000
  h=d2x(n)
  if h~length//2=1 then h='0'||h
  return h~length%2

::method signToken
  expose n d
  use strict arg token
  numeric digits 2200
  if d==.nil then raise syntax 93.900 array('ADB RSA key has no private exponent')
  if token~length<>20 then raise syntax 93.900 array('ADB AUTH token must be 20 bytes',token~length)
  /* SHA-1 AlgorithmIdentifier + OCTET STRING length 20.  token is the digest. */
  digestInfo='3021300906052B0E03021A05000414'x||token
  k=256
  psLen=k-3-digestInfo~length
  if psLen<8 then raise syntax 93.900 array('ADB RSA modulus too small for PKCS#1 v1.5')
  em='0001'x||copies('FF'x,psLen)||'00'x||digestInfo
  m=x2d(c2x(em))
  sig=.RSA~sign(m,d,n)
  hex=d2x(sig)
  if hex~length>k*2 then raise syntax 93.900 array('RSA signature exceeds modulus size')
  hex=copies('0',k*2-hex~length)||hex
  return x2c(hex)

::method androidPublicKeyBinary
  expose n e
  numeric digits 2200
  if self~modulusBytes<>256 then raise syntax 93.900 array('Android ADB public key format requires RSA-2048')
  wordCount=64
  r32=4294967296
  n0=n//r32
  inv=_adbModInverse(n0,r32)
  n0inv=(r32-inv)//r32
  rr=_adbModPow(2,4096,n)
  modulus=_adbIntLe(n,256)
  rrBytes=_adbIntLe(rr,256)
  return _adbLe32Auth(wordCount)||_adbLe32Auth(n0inv)||modulus||rrBytes||_adbLe32Auth(e)

::method publicKeyText
  expose comment
  return _adbBase64(self~androidPublicKeyBinary)||' '||comment

::method publicKeyPayload
  return self~publicKeyText||'00'x

::class AdbAuthenticator public
::attribute keys get
::attribute keyIndex get

::method init
  expose keys keyIndex
  use strict arg keysArg=.nil
  keys=.array~new
  if keysArg<>.nil then do
    if keysArg~isA(.array) then do k over keysArg; keys~append(k); end
    else keys~append(keysArg)
  end
  keyIndex=1

::method reset
  expose keyIndex
  keyIndex=1
  return self

::method responseForToken
  expose keys keyIndex
  use strict arg token
  if keyIndex<=keys~items then do
    key=keys[keyIndex]; keyIndex+=1
    if \key~hasPrivate then return .nil
    d=.directory~new
    d['type']=2
    d['payload']=key~signToken(token)
    d['key']=key
    return d
  end
  if keys~items=0 then return .nil
  d=.directory~new
  d['type']=3
  d['payload']=keys[1]~publicKeyPayload
  d['key']=keys[1]
  return d

::routine _adbLe32Auth
  use strict arg n
  numeric digits 30
  return d2c(n,4)~reverse

::routine _adbIntLe
  use strict arg value,size
  numeric digits 2200
  h=d2x(value)
  if h~length>size*2 then raise syntax 93.900 array('Integer does not fit requested byte size',size)
  h=copies('0',size*2-h~length)||h
  return x2c(h)~reverse

::routine _adbModInverse
  use strict arg a,m
  numeric digits 2200
  t=0; newt=1; r=m; newr=a//m
  do while newr<>0
    q=r%newr
    tmp=t; t=newt; newt=tmp-q*newt
    tmp=r; r=newr; newr=tmp-q*newr
  end
  if r<>1 then raise syntax 93.900 array('Integer has no modular inverse')
  if t<0 then t+=m
  return t

::routine _adbModPow
  use strict arg base,exponent,modulus
  numeric digits 2200
  result=1; b=base//modulus; e=exponent
  do while e>0
    if e//2=1 then result=(result*b)//modulus
    e=e%2
    if e>0 then b=(b*b)//modulus
  end
  return result

::routine _adbBase64
  use strict arg data
  alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  out=''; i=1
  do while i<=data~length
    remain=data~length-i+1
    b1=c2d(substr(data,i,1)); b2=0; b3=0
    if remain>1 then b2=c2d(substr(data,i+1,1))
    if remain>2 then b3=c2d(substr(data,i+2,1))
    n=b1*65536+b2*256+b3
    c1=n%262144
    rem=n//262144
    c2=rem%4096
    rem=rem//4096
    c3=rem%64
    c4=rem//64
    out=out||substr(alphabet,c1+1,1)||substr(alphabet,c2+1,1)
    if remain>1 then out=out||substr(alphabet,c3+1,1); else out=out||'='
    if remain>2 then out=out||substr(alphabet,c4+1,1); else out=out||'='
    i+=3
  end
  return out

::requires "crypto.cls"
