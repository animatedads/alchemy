/* ooRexx Crypto Authentication Primitives v0.1-dev1
 * Narrow companion to oorexx_crypto_v0.8.3.
 * Adds SHA-1 and HMAC-SHA-1/HMAC-SHA-256 required by standards such as
 * RFC 6238 TOTP and HS256 JWT without duplicating SHA-256/SHA-512.
 */
::options digits 50

::class CryptoAuthBuild public
::constant PRODUCT "ooRexx Crypto Authentication Primitives"
::constant RELEASE "0.1-dev1"
::constant API_VERSION "crypto.auth/0.1"
::constant CRYPTO_VERSION "0.8.3"

::class SHA1 public
::method init
  expose data
  use strict arg chunk=""
  data = chunk

::method update
  expose data
  use strict arg chunk
  data ||= chunk

::method digest
  expose data
  return self~digestBytes(data)

::method digestBytes private
  use strict arg input
  numeric digits 50
  h0=.int32~new(x2c("67452301"),"C")
  h1=.int32~new(x2c("efcdab89"),"C")
  h2=.int32~new(x2c("98badcfe"),"C")
  h3=.int32~new(x2c("10325476"),"C")
  h4=.int32~new(x2c("c3d2e1f0"),"C")

  originalBytes=input~length
  msg=input || "80"x
  do while (msg~length // 64) \= 56
    msg ||= "00"x
  end
  bitLength=originalBytes*8
  msg ||= x2c(bitLength~d2x(16))

  do blockStart=1 to msg~length by 64
    block=msg~substr(blockStart,64)
    do i=0 to 15
      W.i=.int32~new(block~substr(i*4+1,4),"C")
    end
    do i=16 to 79
      im3=i-3; im8=i-8; im14=i-14; im16=i-16
      W.i=W.im3~xor(W.im8)~xor(W.im14)~xor(W.im16)~bitrotate(1,"left")
    end
    a=h0; b=h1; c=h2; d=h3; e=h4
    do i=0 to 79
      select
        when i<20 then do
          nb=b~xor(.int32~new("ffffffff"x,"C"))
          f=b~and(c)~or(nb~and(d))
          k=.int32~new(x2c("5a827999"),"C")
        end
        when i<40 then do
          f=b~xor(c)~xor(d)
          k=.int32~new(x2c("6ed9eba1"),"C")
        end
        when i<60 then do
          f=b~and(c)~or(b~and(d))~or(c~and(d))
          k=.int32~new(x2c("8f1bbcdc"),"C")
        end
        otherwise do
          f=b~xor(c)~xor(d)
          k=.int32~new(x2c("ca62c1d6"),"C")
        end
      end
      temp=a~bitrotate(5,"left") + f + e + k + W.i
      e=d; d=c; c=b~bitrotate(30,"left"); b=a; a=temp
    end
    h0=h0+a; h1=h1+b; h2=h2+c; h3=h3+d; h4=h4+e
  end
  return h0~char~c2x~lower || h1~char~c2x~lower || h2~char~c2x~lower || h3~char~c2x~lower || h4~char~c2x~lower

::class AuthHMAC public
::method sha1 class
  use strict arg keyBytes, message
  return self~digestWith(keyBytes,message,"SHA1")

::method sha256 class
  use strict arg keyBytes, message
  return self~digestWith(keyBytes,message,"SHA256")

::method sha512 class
  use strict arg keyBytes, message
  return self~digestWith(keyBytes,message,"SHA512")

::method digestWith class private
  use strict arg keyBytes, message, algorithm
  keyBytes=keyBytes~string
  message=message~string
  algorithm=algorithm~upper
  select
    when algorithm="SHA1" then do; blockSize=64; digestBytes=20; end
    when algorithm="SHA256" then do; blockSize=64; digestBytes=32; end
    when algorithm="SHA512" then do; blockSize=128; digestBytes=64; end
    otherwise raise syntax 88.900 array("Unsupported HMAC digest: " || algorithm)
  end
  if keyBytes~length>blockSize then keyBytes=x2c(self~hashHex(keyBytes,algorithm))
  if keyBytes~length<blockSize then keyBytes ||= "00"x~copies(blockSize-keyBytes~length)
  ipad=bitxor(keyBytes,"36"x~copies(blockSize))
  opad=bitxor(keyBytes,"5c"x~copies(blockSize))
  inner=x2c(self~hashHex(ipad || message,algorithm))
  result=self~hashHex(opad || inner,algorithm)
  if result~length \= digestBytes*2 then raise syntax 88.900 array("Unexpected HMAC digest length")
  return result

::method hashHex class private
  use strict arg bytes, algorithm
  select
    when algorithm="SHA1" then return .SHA1~new(bytes)~digest
    when algorithm="SHA256" then return .SHA256~new(bytes)~digest
    when algorithm="SHA512" then return .SHA512~new(bytes)~digest
    otherwise raise syntax 88.900 array("Unsupported digest")
  end

::requires "crypto.cls"
