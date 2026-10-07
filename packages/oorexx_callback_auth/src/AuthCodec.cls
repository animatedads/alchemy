/* Encoding helpers for callback authentication protocols.
 * These are protocol codecs, not cryptographic authority.
 */
::options digits 50

::class CallbackAuthBuild public
::constant PRODUCT "ooRexx Callback Authentication"
::constant RELEASE "0.1-dev1"
::constant API_VERSION "callback.auth/0.1"
::constant OIDC_CLIENT_API "callback.auth.oidc.client/0.1"
::constant OIDC_PROVIDER_API "callback.auth.oidc.provider/0.1"
::constant TOTP_API "callback.auth.totp/0.1"

::class AuthBase64Url public
::method encode class
  use strict arg bytes
  alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  out=""; posn=1
  do while posn<=bytes~length
    remain=bytes~length-posn+1
    b1=c2d(bytes~substr(posn,1)); b2=0; b3=0
    if remain>=2 then b2=c2d(bytes~substr(posn+1,1))
    if remain>=3 then b3=c2d(bytes~substr(posn+2,1))
    n=b1*65536+b2*256+b3
    out ||= alphabet~substr((n % 262144)+1,1)
    out ||= alphabet~substr(((n % 4096)//64)+1,1)
    if remain>=2 then out ||= alphabet~substr(((n % 64)//64)+1,1)
    if remain>=3 then out ||= alphabet~substr((n//64)+1,1)
    posn += 3
  end
  return out

::method decode class
  use strict arg text
  alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  text=text~string~strip
  if text~pos("=")>0 then raise syntax 88.900 array("base64url input must be unpadded")
  if text~length//4=1 then raise syntax 88.900 array("invalid base64url length")
  out=""; posn=1
  do while posn<=text~length
    remain=text~length-posn+1
    c1=alphabet~pos(text~substr(posn,1))-1
    c2=alphabet~pos(text~substr(posn+1,1))-1
    if c1<0 | c2<0 then raise syntax 88.900 array("invalid base64url character")
    c3=0; c4=0
    if remain>=3 then do; c3=alphabet~pos(text~substr(posn+2,1))-1; if c3<0 then raise syntax 88.900 array("invalid base64url character"); end
    if remain>=4 then do; c4=alphabet~pos(text~substr(posn+3,1))-1; if c4<0 then raise syntax 88.900 array("invalid base64url character"); end
    n=c1*262144+c2*4096+c3*64+c4
    out ||= d2c((n % 65536)//256)
    if remain>=3 then out ||= d2c((n % 256)//256)
    if remain>=4 then out ||= d2c(n//256)
    posn += 4
  end
  return out

::class AuthBase32 public
::method encode class
  use strict arg bytes
  alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  bits=""
  do i=1 to bytes~length
    bits ||= c2x(bytes~substr(i,1))~x2b~changestr(" ","")
  end
  out=""
  do while bits~length>0
    if bits~length>=5 then do; chunk=bits~substr(1,5); bits=bits~substr(6); end
    else do; chunk=bits; bits=""; chunk ||= "0"~copies(5-chunk~length); end
    out ||= alphabet~substr(self~bitsToInt(chunk)+1,1)
  end
  return out

::method decode class
  use strict arg text
  alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  text=text~upper~changestr(" ","")~changestr("-","")
  do while text~right(1)="="; text=text~left(text~length-1); end
  bits=""
  do i=1 to text~length
    n=alphabet~pos(text~substr(i,1))-1
    if n<0 then raise syntax 88.900 array("invalid base32 character")
    bits ||= n~d2x(2)~x2b~changestr(" ","")~right(5)
  end
  out=""
  do while bits~length>=8
    out ||= d2c(self~bitsToInt(bits~substr(1,8)))
    bits=bits~substr(9)
  end
  return out

::method bitsToInt class private
  use strict arg bits
  n=0
  do i=1 to bits~length
    n=n*2 + bits~substr(i,1)
  end
  return n

::class AuthUriCodec public
::method encodeComponent class
  use strict arg text
  safe="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  out=""
  do i=1 to text~length
    ch=text~substr(i,1)
    if safe~pos(ch)>0 then out ||= ch
    else out ||= "%" || c2x(ch)
  end
  return out

::method decodeComponent class
  use strict arg text
  text=text~string
  out=""; i=1
  do while i<=text~length
    ch=text~substr(i,1)
    if ch="%" then do
      if i+2>text~length then raise syntax 88.900 array("truncated percent escape")
      hx=text~substr(i+1,2)
      if verify(hx,"0123456789abcdefABCDEF")\=0 then raise syntax 88.900 array("invalid percent escape")
      out ||= x2c(hx); i += 3
    end
    else do
      if ch="+" then out ||= " "; else out ||= ch
      i += 1
    end
  end
  return out

::method buildQuery class
  use strict arg params
  keys=params~allIndexes~makearray
  keys~sort
  out=""
  do key over keys
    value=params[key]
    if value==.nil then iterate
    if out<>"" then out ||="&"
    out ||= self~encodeComponent(key~string) || "=" || self~encodeComponent(value~string)
  end
  return out

::method parseQuery class
  use strict arg text
  d=.directory~new
  text=text~string
  if text="" then return d
  do part over text~makearray("&")
    p=part~pos("=")
    if p=0 then do; key=self~decodeComponent(part); value=""; end
    else do; key=self~decodeComponent(part~left(p-1)); value=self~decodeComponent(part~substr(p+1)); end
    d[key]=value
  end
  return d

::class AuthClock public
::method unixNow class
  /* DateTime baseDate is 0001-01-01; Unix epoch offset in seconds. */
  epoch=.DateTime~fromStandardDate("19700101")
  now=.DateTime~new
  return (now~microseconds-epoch~microseconds)%1000000
