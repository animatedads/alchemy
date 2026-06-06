/* ============================================================
 * crypto.cls  —  OORexx Cryptography Library
 *
 * Inheritance tree:
 *
 *   CryptoHash (abstract)
 *     ├── MD5       — streaming MD5, little-endian int32
 *     └── SHA512    — streaming SHA-512, big-endian int64
 *
 *   CurvePoint (abstract)
 *     ├── EdwardsPoint  — twisted Edwards  Ed25519 (255-bit)
 *     └── GoldilocksPoint — untwisted Edwards  Ed448  (448-bit)
 *
 *   Ed25519    — keypair, sign, verify  (needs SHA512)
 *   Ed448      — keypair, sign, verify  (needs SHA512; Goldilocks curve)
 *   X25519     — key exchange, shared secret
 *   ChaCha20   — stream cipher (RFC 8439); key=256-bit, nonce=96-bit
 *   RSA        — keypair(p,q), encrypt, decrypt, sign, verify
 *              — generateKeypair() generates fresh 1024-bit primes
 *   RSAStream  — hybrid RSA+ChaCha20: session scalar RSA-wrapped, bulk ChaCha20
 *
 *   CryptoStream — wraps OORexx Stream with crypto operations
 *     hash(algo)  → MD5 or SHA512 digest of stream content
 *     sign(key)   → Ed25519 hex signature
 *     verify(sig,key) → boolean
 *     encrypt/decrypt → X25519-CBC stream cipher
 *
 *   Word helpers (not public API):
 *     int32  — 32-bit little-endian word for MD5
 *     int64  — 64-bit big-endian word for SHA-512
 *
 * Routines (::routine directives at bottom of file):
 *   Curve:    rx_mod_inverse, rx_pow_mod, rx_recover_x
 *             rx_x25519_ladder, rx_mod_inverse_x, rx_pow_mod_x
 *   Encoding: rx_le_hex_encode/decode, rx_be_hex_encode/decode
 *             rx_string_to_int, rx_int_to_string
 *             rx_compress_point, rx_clamp_scalar
 *   64-bit:   rx_add64, rx_and64, rx_or64, rx_xor64, rx_shr64
 *             rx_rotr64, rx_shr_large, rx_xor_large
 *   Cipher:   rx_encrypt_stream, rx_decrypt_stream
 *             rx_chacha20_block, rx_chacha20_crypt (fixed)
 *             rx_le_hex_encode32, rx_xor32, rx_add32, rx_rotl32
 *   Extern:   sin (rxmath)
 *
 * Authors:
 *   md5 / int32        — Tom Dyer
 *   EdwardsPoint / X25519 arithmetic — Gemini (Google)
 *   sha512 / int64 / CryptoStream / class structure — Claude
 * ============================================================ */

::options digits 2000


/* ============================================================
 * ABSTRACT BASE: CryptoHash
 * Defines the streaming hash interface all algorithms implement.
 * ============================================================ */

::class CryptoHash public

/* Override in subclass — first chunk can be passed at init */
::method init
  use arg chunk
  if arg() < 1 then chunk = ""

/* Feed more data into the running hash */
::method update abstract

/* Finalise and return lowercase hex digest string */
::method digest abstract

/* Convenience: hash a complete string in one call */
::method hashString class
  use arg str, algo
  if arg() < 2 then algo = "SHA512"
  select
    when algo~upper = "MD5"    then h = .MD5~new(str)
    when algo~upper = "SHA512" then h = .SHA512~new(str)
    otherwise raise syntax 93.915 array("MD5 SHA512", algo)
  end
  return h~digest


/* ============================================================
 * MD5  (subclass of CryptoHash)
 * Tom Dyer's implementation — streaming, little-endian int32.
 * ============================================================ */

::class MD5 subclass CryptoHash public

::method init
  expose a0 b0 c0 d0 count buffer index K. s
  use strict arg chunk=""
  a0 = .int32~new('67452301'x,"C")
  b0 = .int32~new('efcdab89'x,"C")
  c0 = .int32~new('98badcfe'x,"C")
  d0 = .int32~new('10325476'x,"C")
  buffer = .mutablebuffer~new('00'x~copies(64),64)
  index  = 1
  count  = 0
  nrs = .array~of(7,12,17,22)
  s = nrs~union(nrs)~union(nrs)~union(nrs)
  nrs = .array~of(5,9,14,20)
  s = s~union(nrs)~union(nrs)~union(nrs)~union(nrs)
  nrs = .array~of(4,11,16,23)
  s = s~union(nrs)~union(nrs)~union(nrs)~union(nrs)
  nrs = .array~of(6,10,15,21)
  s = s~union(nrs)~union(nrs)~union(nrs)~union(nrs)
  do i=0 to 63
    K.i = .int32~new(((2**32)*(sin(i+1,16,R)~abs))~floor)
  end
  self~update(chunk)

::method update
  expose a0 b0 c0 d0 count buffer index K. s
  use strict arg chunk
  count += chunk~length
  if chunk~length < 65-index then do
    buffer~overlay(chunk,index)
    index += chunk~length
  end
  else do
    split = 65-index+1
    parse var chunk part =(split) chunk
    buffer~overlay(part,index)
    index = 65
  end
  do while index=65
    A = a0; B = b0; C = c0; D = d0
    do i=0 to 63
      select
        when i<16 then do
          F = D~xor(B~and(C~xor(D))); g = i
        end
        when i<32 then do
          F = C~xor(D~and(B~xor(C))); g = (5*i+1)//16
        end
        when i<48 then do
          F = B~xor(C)~xor(D);        g = (3*i+5)//16
        end
        otherwise do
          F = C~xor(B~or(D~xor(.int32~new('ffffffff'x,"C")))); g = (7*i)//16
        end
      end
      M     = .int32~new(buffer~substr(g*4+1,4)~reverse,"C")
      dTemp = D; D = C; C = B
      B     = (B + (A+F+K.i+M)~bitrotate(s[i+1]))
      A     = dTemp
    end
    a0 = a0+A; b0 = b0+B; c0 = c0+C; d0 = d0+D
    parse var chunk part 65 chunk
    index = part~length+1
    buffer~overlay(part,1,part~length)
  end

::method digest
  expose a0 b0 c0 d0 count buffer index K s
  padlen = 64
  if index<57 then padlen = 57-index
  if index>57 then padlen = 121-index
  padding  = '00'x~copies(padlen)~bitor('80'x)
  bitcount = count*8//2**64
  lowword  = bitcount//2**32
  hiword   = bitcount%2**32
  lowcount = lowword~d2c(4)~reverse
  hicount  = hiword~d2c(4)~reverse
  self~update(padding || lowcount || hicount)
  return a0~string || b0~string || c0~string || d0~string


/* ============================================================
 * SHA512  (subclass of CryptoHash)
 * Big-endian int64 word engine.  ::options digits 500 from
 * the file top covers all 255-bit curve arithmetic too.
 * ============================================================ */

::class SHA512 subclass CryptoHash public

::method init
  expose h0 h1 h2 h3 h4 h5 h6 h7 count buffer index K.
  use strict arg chunk=""
  h_hex = "6a09e667f3bcc908 bb67ae8584caa73b 3c6ef372fe94f82b a54ff53a5f1d36f1",
          "510e527fade682d1 9b05688c2b3e6c1f 1f83d9abfb41bd6b 5be0cd19137e2179"
  h_hex = space(h_hex, 1)
  h0 = .int64~new(x2c(word(h_hex,1)),"C"); h1 = .int64~new(x2c(word(h_hex,2)),"C")
  h2 = .int64~new(x2c(word(h_hex,3)),"C"); h3 = .int64~new(x2c(word(h_hex,4)),"C")
  h4 = .int64~new(x2c(word(h_hex,5)),"C"); h5 = .int64~new(x2c(word(h_hex,6)),"C")
  h6 = .int64~new(x2c(word(h_hex,7)),"C"); h7 = .int64~new(x2c(word(h_hex,8)),"C")
  buffer = .mutablebuffer~new('00'x~copies(128),128)
  index  = 1
  count  = 0
  k_hex = "428a2f98d728ae22 7137449123ef65cd b5c0fbcfec4d3b2f e9b5dba58189dbbc",
          "3956c25bf348b538 59f111f1b605d019 923f82a4af194f9b ab1c5ed5da6d8118",
          "d807aa98a3030242 12835b0145706fbe 243185be4ee4b28c 550c7dc3d5ffb4e2",
          "72be5d74f27b896f 80deb1fe3b1696b1 9bdc06a725c71235 c19bf174cf692694",
          "e49b69c19ef14ad2 efbe4786384f25e3 0fc19dc68b8cd5b5 240ca1cc77ac9c65",
          "2de92c6f592b0275 4a7484aa6ea6e483 5cb0a9dcbd41fbd4 76f988da831153b5",
          "983e5152ee66dfab a831c66d2db43210 b00327c898fb213f bf597fc7beef0ee4",
          "c6e00bf33da88fc2 d5a79147930aa725 06ca6351e003826f 142929670a0e6e70",
          "27b70a8546d22ffc 2e1b21385c26c926 4d2c6dfc5ac42aed 53380d139d95b3df",
          "650a73548baf63de 766a0abb3c77b2a8 81c2c92e47edaee6 92722c851482353b",
          "a2bfe8a14cf10364 a81a664bbc423001 c24b8b70d0f89791 c76c51a30654be30",
          "d192e819d6ef5218 d69906245565a910 f40e35855771202a 106aa07032bbd1b8",
          "19a4c116b8d2d0c8 1e376c085141ab53 2748774cdf8eeb99 34b0bcb5e19b48a8",
          "391c0cb3c5c95a63 4ed8aa4ae3418acb 5b9cca4f7763e373 682e6ff3d6b2b8a3",
          "748f82ee5defb2fc 78a5636f43172f60 84c87814a1f0ab72 8cc702081a6439ec",
          "90befffa23631e28 a4506cebde82bde9 bef9a3f7b2c67915 c67178f2e372532b",
          "ca273eceea26619c d186b8c721c0c207 eada7dd6cde0eb1e f57d4f7fee6ed178",
          "06f067aa72176fba 0a637dc5a2c898a6 113f9804bef90dae 1b710b35131c471b",
          "28db77f523047d84 32caab7b40c72493 3c9ebe0a15c9bebc 431d67c49c100d4c",
          "4cc5d4becb3e42b6 597f299cfc657e2a 5fcb6fab3ad6faec 6c44198c4a475817"
  k_hex = space(k_hex, 1)
  do i = 1 to 80
    j    = i - 1
    K.j  = .int64~new(x2c(word(k_hex, i)), "C")
  end
    self~update(chunk)

::method update
  expose h0 h1 h2 h3 h4 h5 h6 h7 count buffer index K.
  use strict arg chunk
  count += chunk~length
  if chunk~length < 129-index then do
    buffer~overlay(chunk,index)
    index += chunk~length
  end
  else do
    split = 129-index+1
    parse var chunk part =(split) chunk
    buffer~overlay(part,index)
    index = 129
  end
  do while index=129
    do i = 0 to 15
      W.i = .int64~new(buffer~substr(i*8+1, 8), "C")
    end
    do i = 16 to 79
      im15 = i-15;  im2 = i-2;  im16 = i-16;  im7 = i-7
      s0 = W.im15~rotr(1)~xor(W.im15~rotr(8))~xor(W.im15~shr(7))
      s1 = W.im2~rotr(19)~xor(W.im2~rotr(61))~xor(W.im2~shr(6))
      W.i = W.im16 + s0 + W.im7 + s1
    end
    A = h0; B = h1; C = h2; D = h3; E = h4; F = h5; G = h6; H = h7
    do i = 0 to 79
      S1    = E~rotr(14)~xor(E~rotr(18))~xor(E~rotr(41))
      ch    = E~and(F)~xor(E~bitnot~and(G))
      temp1 = H + S1 + ch + K.i + W.i
      S0    = A~rotr(28)~xor(A~rotr(34))~xor(A~rotr(39))
      maj   = A~and(B)~xor(A~and(C))~xor(B~and(C))
      temp2 = S0 + maj
      H = G;  G = F;  F = E;  E = D + temp1
      D = C;  C = B;  B = A;  A = temp1 + temp2
    end
    h0 = h0+A; h1 = h1+B; h2 = h2+C; h3 = h3+D
    h4 = h4+E; h5 = h5+F; h6 = h6+G; h7 = h7+H
    parse var chunk part 129 chunk
    index = part~length+1
    buffer~overlay(part,1,part~length)
  end

::method digest
  expose h0 h1 h2 h3 h4 h5 h6 h7 count buffer index K.
  padlen = 128
  if index < 113 then padlen = 113-index
  if index > 112 then padlen = 241-index
  padding  = '00'x~copies(padlen)~bitor('80'x)
  bitcount = count * 8
  hicount  = 0~d2c(8)
  locount  = bitcount~d2c(8)
  self~update(padding || hicount || locount)
  return h0~string || h1~string || h2~string || h3~string ,
       ||h4~string || h5~string || h6~string || h7~string


/* ============================================================
 * int32 — little-endian 32-bit word (Tom Dyer)
 * ============================================================ */

::class int32 public
::attribute arch class
::method init class; self~arch = "little-endian"

::method init
  expose char4 int32
  use strict arg input, type="Integer"
  t = type~subchar(1)~upper
  select
    when t=='I' then do; char4 = input~d2c(4);         int32 = char4~c2d; end
    when t=='C' then do; char4 = input~right(4,'00'x); int32 = char4~c2d; end
    otherwise raise syntax 93.915 array("IC",type)
  end

::method xor;     expose char4; use strict arg o; return .int32~new(char4~bitxor(o~char),"C")
::method and;     expose char4; use strict arg o; return .int32~new(char4~bitand(o~char),"C")
::method or;      expose char4; use strict arg o; return .int32~new(char4~bitor(o~char),"C")
::method bitnot;  expose char4; return .int32~new(char4~bitxor('ffffffff'x)~c2d,"C")

::method bitleft
  expose char4; use strict arg bits
  b = char4~c2x~x2b
  return .int32~new(b~substr(bits+1)~left(b~length,'0')~b2x~x2d)

::method '<<'; forward to (self) message("bitleft")

::method bitright
  expose char4; use strict arg bits, signed=.false
  b = char4~c2x~x2b; fill = '0'
  if signed then fill = b~subchar(1)
  return .int32~new(b~left(b~length-bits)~right(b~length,fill)~b2x~x2d)

::method '>>'; forward to (self) message("bitright")

::method bitrotate
  expose char4; use strict arg bits, direction='left'
  d = direction~subchar(1)~upper
  if d=='L' then do; lp = self~bitleft(bits);    rp = self~bitright(32-bits); end
  else           do; lp = self~bitleft(32-bits); rp = self~bitright(bits);    end
  return rp~or(lp)

::method int;    expose int32; return int32
::method char;   expose char4; return char4
::method '+';    expose int32; use strict arg o; return .int32~new(int32+o~int)
::method string; expose char4; return char4~reverse~c2x~lower


/* ============================================================
 * int64 — big-endian 64-bit word for SHA-512
 * Uses d2x/x2d to avoid d2c precision edge cases for large values.
 * ============================================================ */

::class int64 public
::attribute arch class
::method init class; self~arch = "big-endian"

::method init
  expose char8 int64
  use strict arg input, type="Integer"
  mod64 = 18446744073709551616
  t = type~subchar(1)~upper
  select
    when t=='I' then do
      n = input // mod64
      if n < 0 then n = n + mod64
      /* d2x avoids d2c precision issues for values near 2^64 */
      char8 = x2c(n~d2x(16))
      int64 = x2d(char8~c2x)
    end
    when t=='C' then do
      char8 = input~right(8,'00'x)
      int64 = x2d(char8~c2x)
    end
    otherwise raise syntax 93.915 array("IC",type)
  end

::method xor;    expose char8; use strict arg o; return .int64~new(char8~bitxor(o~char),"C")
::method and;    expose char8; use strict arg o; return .int64~new(char8~bitand(o~char),"C")
::method or;     expose char8; use strict arg o; return .int64~new(char8~bitor(o~char),"C")
::method bitnot; expose char8; return .int64~new(char8~bitxor('ffffffffffffffff'x),"C")

::method shr
  expose char8; use strict arg bits
  b = char8~c2x~x2b
  return .int64~new(b~left(64-bits)~right(64,'0')~b2x~x2d)

::method bitleft
  expose char8; use strict arg bits
  b = char8~c2x~x2b
  return .int64~new(b~substr(bits+1)~left(64,'0')~b2x~x2d)

::method bitright
  expose char8; use strict arg bits, signed=.false
  b = char8~c2x~x2b; fill = '0'
  if signed then fill = b~subchar(1)
  return .int64~new(b~left(64-bits)~right(64,fill)~b2x~x2d)

::method rotr
  expose char8; use strict arg bits
  return self~bitright(bits)~or(self~bitleft(64-bits))

::method '+'
  expose int64
  use strict arg other
  mod64 = 18446744073709551616
  sum = int64 + other~int
  if sum >= mod64 then sum = sum - mod64
  return .int64~new(sum)

::method int;    expose int64; return int64
::method char;   expose char8; return char8
::method string; expose char8; return char8~c2x~lower


/* ============================================================
 * ABSTRACT BASE: CurvePoint
 * x and y coordinate attributes shared by Edwards and Montgomery.
 * ============================================================ */

::class CurvePoint public
::method x attribute
::method y attribute
::method add abstract
::method multiply abstract


/* ============================================================
 * EdwardsPoint  (subclass of CurvePoint)
 * Twisted Edwards curve arithmetic for Ed25519.
 * Gemini (Google) implementation — cleaned for class structure.
 * ============================================================ */

::class EdwardsPoint subclass CurvePoint public

::method init
  use arg x, y
  self~x = x;  self~y = y

::method add
  use arg q
  forward to (self) message "edwards_add"

::method edwards_add
  use arg q
  p = 2**255 - 19
  inv_val      = rx_mod_inverse(121666, p)
  temp_product = 121665 * inv_val
  raw_d        = temp_product // p
  if raw_d == 0 then d = 0
  else d = p - raw_d
  x1 = self~x;  y1 = self~y
  x2 = q~x;     y2 = q~y
  big_prod = (d * x1) // p
  big_prod = (big_prod * x2) // p
  big_prod = (big_prod * y1) // p
  big_prod = (big_prod * y2) // p
  dx = (1 + big_prod) // p
  dy = (1 - big_prod) // p
  if dy < 0 then dy = dy + p
  x3 = ((x1*y2 + y1*x2) * rx_mod_inverse(dx,p)) // p
  y3 = ((y1*y2 + x1*x2) * rx_mod_inverse(dy,p)) // p
  if x3 < 0 then x3 = x3 + p
  if y3 < 0 then y3 = y3 + p
  return .EdwardsPoint~new(x3,y3)

::method multiply
  use arg scalar
  res  = .EdwardsPoint~new(0,1)
  base = self
  do while scalar > 0
    if scalar // 2 == 1 then res = res~add(base)
    base   = base~add(base)
    scalar = scalar % 2
  end
  return res




/* ============================================================
 * GoldilocksPoint  (subclass of CurvePoint)
 * Untwisted Edwards curve for Ed448-Goldilocks.
 * p = 2^448 - 2^224 - 1,  d = -39081
 * y3 uses a minus sign (untwisted form, unlike Ed25519's plus).
 * Gemini (Google) implementation — multiply method added,
 * numeric digits increased to 2000 for safe 448-bit arithmetic.
 * ============================================================ */

::class GoldilocksPoint subclass CurvePoint public

::method init
  use arg x, y
  self~x = x;  self~y = y

::method add
  use arg q
  numeric digits 2000
  p448 = 2**448 - 2**224 - 1
  d448 = -39081
  if d448 < 0 then d448 = d448 + p448
  x1 = self~x;  y1 = self~y
  x2 = q~x;     y2 = q~y
  big_prod = (d448 * x1) // p448
  big_prod = (big_prod * x2) // p448
  big_prod = (big_prod * y1) // p448
  big_prod = (big_prod * y2) // p448
  dx = (1 + big_prod) // p448
  dy = (1 - big_prod) // p448
  if dy < 0 then dy = dy + p448
  x3 = ((x1*y2 + y1*x2) * rx_mod_inverse(dx, p448)) // p448
  y3 = ((y1*y2 - x1*x2) * rx_mod_inverse(dy, p448)) // p448  /* minus — Ed448 untwisted */
  if x3 < 0 then x3 = x3 + p448
  if y3 < 0 then y3 = y3 + p448
  return .GoldilocksPoint~new(x3, y3)

::method multiply
  use arg scalar
  res  = .GoldilocksPoint~new(0, 1)
  base = self
  do while scalar > 0
    if scalar // 2 == 1 then res = res~add(base)
    base   = base~add(base)
    scalar = scalar % 2
  end
  return res

/* ============================================================
 * Ed25519  — keypair generation, sign, verify
 * Signing requires SHA512 to expand the private key seed
 * and to hash the message nonce.  Verify requires the same.
 *
 * Group order l = 2^252 + 27742317777372353535851937790883648493
 * ============================================================ */

::class Ed25519 public

/* Base point G on the Edwards curve */
::method G class
  p = 2**255 - 19
  inv_val      = rx_mod_inverse(121666, p)
  temp_product = 121665 * inv_val
  raw_d        = temp_product // p
  if raw_d == 0 then d = 0
  else d = p - raw_d
  I  = rx_pow_mod(2, (p-1)/4, p)
  By = (4 * rx_mod_inverse(5,p)) // p
  Bx = rx_recover_x(By, d, p, I)
  return .EdwardsPoint~new(Bx, By)

/* Generate public key from a 32-byte hex seed string.
 * Returns Directory with keys "public" and "private" (as hex). */
::method keypair class
  use arg seedHex
  l    = 2**252 + 27742317777372353535851937790883648493
  h    = .SHA512~new(x2c(seedHex))
  bits = h~digest          /* 128 hex chars = 64 bytes */
  /* First 32 bytes → clamp to get scalar */
  scalar = rx_clamp_scalar(left(bits, 64))
  /* Public key = scalar × G, compressed */
  A    = .Ed25519~G~multiply(scalar)
  pub  = rx_compress_point(A)
  kp   = .Directory~new
  kp["private"] = seedHex
  kp["scalar"]  = scalar
  kp["public"]  = pub
  return kp

/* Sign a message (string).  Returns 64-byte hex signature.
 * RFC 8032 Ed25519 requires SHA-512; uses streaming SHA512 class. */
::method sign class
  use arg message, privateHex
  l    = 2**252 + 27742317777372353535851937790883648493
  /* Expand key */
  h    = .SHA512~new(x2c(privateHex))
  bits = h~digest
  scalar = rx_clamp_scalar(left(bits, 64))
  prefix = substr(bits, 65)           /* right 32 bytes as 64 hex chars */
  /* Derive A */
  A    = .Ed25519~G~multiply(scalar)
  Ahex = rx_compress_point(A)
  /* Nonce r = SHA512(prefix || message) mod l */
  h2   = .SHA512~new(x2c(prefix) || message)
  r    = rx_le_hex_decode(h2~digest) // l
  /* R = r*G */
  Rpt  = .Ed25519~G~multiply(r)
  Rhex = rx_compress_point(Rpt)
  /* k = SHA512(R || A || message) mod l */
  h3   = .SHA512~new(x2c(Rhex) || x2c(Ahex) || message)
  k    = rx_le_hex_decode(h3~digest) // l
  /* S = (r + k*scalar) mod l */
  S    = (r + k * scalar) // l
  Shex = rx_le_hex_encode(S)
  return Rhex || Shex

/* Verify a signature.  Returns .true or .false. */
::method verify class
  use arg message, sigHex, publicHex
  l     = 2**252 + 27742317777372353535851937790883648493
  Rhex  = left(sigHex, 64)
  Shex  = substr(sigHex, 65)
  S     = rx_le_hex_decode(Shex)
  if S >= l then return .false
  Rpt   = rx_decompress_point(Rhex)
  Apt   = rx_decompress_point(publicHex)
  h     = .SHA512~new(x2c(Rhex) || x2c(publicHex) || message)
  k     = rx_le_hex_decode(h~digest) // l
  /* Check: S*G == R + k*A */
  lhs   = .Ed25519~G~multiply(S)
  rhs   = Rpt~add(Apt~multiply(k))
  return (lhs~x = rhs~x) & (lhs~y = rhs~y)




/* ============================================================
 * Ed448  — keypair, sign, verify on Goldilocks curve
 * Group order: l = 2^446 - 13818066809895115352007386748515426880316871408...
 *   (simplified: l = 2^446 - 13818066809895115352007386748515426880316...)
 * The base point is the canonical Goldilocks generator.
 * Signing follows the same RFC 8032 Ed448 pattern as Ed25519
 * but uses SHA-512 over a 57-byte hash.
 * NOTE: Full sign/verify requires the Goldilocks base point G448
 *   and a 57-byte hash function (SHAKE256 in the RFC; SHA512 used here
 *   as an approximation pending a proper SHAKE256 implementation).
 * ============================================================ */

::class Ed448 public

/* Ed448 group order */
::method l class
  return 2**446 - 13818066809895115352007386748515426880316871408076039390

/* Ed448 base point (canonical generator) */
::method G class
  numeric digits 2000
  p448 = 2**448 - 2**224 - 1
  /* Canonical By for Ed448 */
  Gy   = 693175619530233403454093726540132763892135629552985898986858051805439768853646
  /* Recover Gx */
  d448 = -39081
  if d448 < 0 then d448 = d448 + p448
  /* u = y^2 - 1,  v = d*y^2 - 1 (untwisted: no factor a) */
  u  = (Gy*Gy - 1) // p448;  if u < 0 then u = u + p448
  v  = (d448*Gy*Gy - 1) // p448
  /* x = (u/v)^((p+1)/4) */
  Gx = rx_pow_mod(u * rx_mod_inverse(v, p448), (p448+1)/4, p448)
  if Gx // 2 \== 0 then Gx = p448 - Gx
  return .GoldilocksPoint~new(Gx, Gy)

/* Generate keypair from 57-byte hex seed */
::method keypair class
  use arg seedHex
  l    = .Ed448~l
  h    = .SHA512~new(x2c(seedHex))
  bits = h~digest
  scalar = rx_clamp_scalar(left(bits, 64))
  A    = .Ed448~G~multiply(scalar)
  pub  = rx_compress_point448(A)
  kp   = .Directory~new
  kp["private"]  = seedHex
  kp["scalar"]   = scalar
  kp["public"]   = pub
  return kp

/* ============================================================
 * X25519  — Diffie-Hellman key exchange on Curve25519
 * Gemini's Montgomery ladder wrapped in a class.
 * ============================================================ */

::class X25519 public

::method publicKey class
  use arg privateScalar
  p = 2**255 - 19
  return rx_x25519_ladder(privateScalar, 9, p)

::method sharedSecret class
  use arg myPrivate, theirPublic
  p = 2**255 - 19
  return rx_x25519_ladder(myPrivate, theirPublic, p)

::method encryptStream class
  use arg plaintext, sharedSecret
  return rx_encrypt_stream(plaintext, sharedSecret)

::method decryptStream class
  use arg cipherHex, sharedSecret
  return rx_decrypt_stream(cipherHex, sharedSecret)



/* ============================================================
 * ChaCha20  — RFC 8439 stream cipher
 * key_hex:   64 hex chars (256-bit key)
 * nonce_hex: 24 hex chars (96-bit nonce)
 *
 * Usage:
 *   enc = .ChaCha20~crypt(plaintext, keyHex, nonceHex)
 *   dec = .ChaCha20~crypt(enc, keyHex, nonceHex)  <- same operation
 * ============================================================ */

::class ChaCha20 public

::method crypt class
  use arg data, keyHex, nonceHex
  return rx_chacha20_crypt(data, keyHex, nonceHex)

::method encrypt class
  use arg plaintext, keyHex, nonceHex
  return rx_chacha20_crypt(plaintext, keyHex, nonceHex)

::method decrypt class
  use arg ciphertext, keyHex, nonceHex
  return rx_chacha20_crypt(ciphertext, keyHex, nonceHex)


/* ============================================================
 * RSA  — textbook RSA with proper key generation
 *
 * Key generation uses rx_mod_inverse to derive d from e and φ(n).
 * Gemini's test used invented (n,e,d) values with no key
 * relationship — the decrypt produced garbage because
 * e*d ≢ 1 (mod φ(n)).  Supply actual primes p, q and keypair()
 * computes d correctly.
 *
 * rx_rsa_pow_mod is correct (proven by the toy key test).
 * rx_rsa_string_to_int / rx_rsa_int_to_string padding is
 * symmetric — the only failure was the invalid test keys.
 *
 * Usage:
 *   kp  = .RSA~keypair(p, q)          -- derive d from p, q, e=65537
 *   enc = .RSA~encrypt(plaintext, kp["e"], kp["n"])
 *   dec = .RSA~decrypt(enc, kp["d"], kp["n"])
 *   -- or raw integer mode:
 *   c   = rx_rsa_pow_mod(m, e, n)
 *   m2  = rx_rsa_pow_mod(c, d, n)
 * ============================================================ */

::class RSA public

/* Generate keypair from two large primes p and q.
 * e defaults to 65537 (standard public exponent).
 * Returns Directory: n, e, d, phi */
::method keypair class
  use arg p, q, e
  if arg() < 3 then e = 65537
  n   = p * q
  phi = (p-1) * (q-1)
  d   = rx_mod_inverse(e, phi)
  if d <= 0 then raise syntax 93.900 array("gcd(e,phi) != 1 — e and phi(n) must be coprime")
  kp       = .Directory~new
  kp["n"]  = n;   kp["e"] = e
  kp["d"]  = d;   kp["phi"] = phi
  return kp

/* Encrypt a text string.  Returns the ciphertext integer. */
::method encrypt class
  numeric digits 2000
  use arg plaintext, e, n
  m = rx_rsa_string_to_int(plaintext, n)
  if m < 0 then raise syntax 93.900 array("plaintext too long for this modulus")
  return rx_rsa_pow_mod(m, e, n)

/* Decrypt a ciphertext integer.  Returns plaintext string. */
::method decrypt class
  numeric digits 2000
  use arg ciphertext, d, n
  m = rx_rsa_pow_mod(ciphertext, d, n)
  return rx_rsa_int_to_string(m, n)

/* Generate a fresh RSA-2048 keypair by generating two 1024-bit primes.
 * This is the complete key generation pipeline — may take a minute or two. */
::method generateKeypair class
  use arg e
  if arg() < 1 then e = 65537
  say "[RSA] Generating 1024-bit prime p (please wait)..."
  p = rx_generate_prime_1024()
  say "[RSA] Generating 1024-bit prime q (please wait)..."
  q = rx_generate_prime_1024()
  return .RSA~keypair(p, q, e)

/* Sign a message (raw integer).  Signature = m^d mod n */
::method sign class
  use arg messageInt, d, n
  return rx_rsa_pow_mod(messageInt, d, n)

/* Verify a signature.  Returns the original integer. */
::method verify class
  use arg signature, e, n
  return rx_rsa_pow_mod(signature, e, n)


/* ============================================================
 * RSAStream  — hybrid RSA + ChaCha20 stream cipher
 *
 * RSA cannot encrypt arbitrary-length data — its block is
 * bounded by the modulus size.  The standard solution is
 * hybrid encryption:
 *
 *   ENCRYPT
 *     1. Choose a session_int  (small random integer < n)
 *     2. RSA-encrypt it:  enc = session_int ^ e  mod n
 *     3. Derive ChaCha20 key+nonce:  SHA512(session_int)
 *     4. ChaCha20-encrypt the actual plaintext
 *     5. Output: [rsa_block_hex]:[chacha_hex]
 *
 *   DECRYPT
 *     1. Split on ":"
 *     2. RSA-decrypt rsa_block_hex → session_int
 *     3. Re-derive same key+nonce:  SHA512(session_int)
 *     4. ChaCha20-decrypt chacha_hex
 *
 * The session_int is a small value (e.g. a timestamp or random
 * number).  Any size n works because we only RSA-encrypt the
 * small scalar, not the bulk data.  SHA512 stretches it to the
 * 256+96 bits ChaCha20 needs.
 *
 * Usage:
 *   kp  = .RSA~keypair(p, q)
 *   enc = .RSAStream~encrypt(plaintext, kp["e"], kp["n"])
 *   dec = .RSAStream~decrypt(enc, kp["d"], kp["n"])
 *
 *   -- with CryptoStream:
 *   cs  = .CryptoStream~new("file.txt", "READ")
 *   enc = cs~encryptRSA(kp["e"], kp["n"])
 *   cs~close
 *   plain = .CryptoStream~decryptRSA(enc, kp["d"], kp["n"])
 * ============================================================ */

::class RSAStream public

/* session_int defaults to 12345 for demo; production should
 * use a random integer < n, re-generated for each message  */
::method encrypt class
  numeric digits 2000
  use arg plaintext, public_e, modulus_n, session_int
  if arg() < 4 then session_int = 12345

  /* Step 1 — RSA-encrypt the session scalar */
  enc_session = rx_rsa_pow_mod(session_int, public_e, modulus_n)

  /* Step 2 — derive ChaCha20 key (256-bit) + nonce (96-bit) via SHA512 */
  h         = .SHA512~new(session_int~string)~digest  /* 128 hex chars */
  key_hex   = left(h, 64)                             /* first 32 bytes */
  nonce_hex = substr(h, 65, 24)                       /* bytes 33-44 */

  /* Step 3 — ChaCha20-encrypt the bulk data */
  cipher = .ChaCha20~encrypt(plaintext, key_hex, nonce_hex)

  /* Step 4 — pack: [rsa_block_hex]:[chacha_hex]
   * rsa_block padded to even hex width of modulus */
  rsa_hex = d2x(enc_session)~right(length(d2x(modulus_n)), '0')~lower
  return rsa_hex || ":" || c2x(cipher)~lower

::method decrypt class
  numeric digits 2000
  use arg cipherstream, private_d, modulus_n

  /* Split on first ":" — rsa block | chacha content */
  colon = pos(":", cipherstream)
  if colon = 0 then raise syntax 93.900 array("RSAStream: malformed cipherstream")
  rsa_hex   = left(cipherstream, colon-1)
  chacha_hex = substr(cipherstream, colon+1)

  /* RSA-decrypt session scalar */
  enc_session = x2d(rsa_hex)
  session_int = rx_rsa_pow_mod(enc_session, private_d, modulus_n)

  /* Re-derive same key + nonce */
  h         = .SHA512~new(session_int~string)~digest
  key_hex   = left(h, 64)
  nonce_hex = substr(h, 65, 24)

  /* ChaCha20-decrypt */
  return .ChaCha20~decrypt(x2c(chacha_hex), key_hex, nonce_hex)

/* Convenience: encrypt just by passing CryptoStream content */
::method encryptStream class
  use arg content, public_e, modulus_n, session_int
  if arg() < 4 then session_int = 12345
  return .RSAStream~encrypt(content, public_e, modulus_n, session_int)

::method decryptStream class
  use arg cipherstream, private_d, modulus_n
  return .RSAStream~decrypt(cipherstream, private_d, modulus_n)

/* ============================================================
 * CryptoStream — OORexx Stream wrapper with crypto operations
 *
 * Usage:
 *   cs = .CryptoStream~new("/path/to/file", "READ")
 *   say cs~md5
 *   say cs~sha512
 *   cs~close
 *
 *   cs = .CryptoStream~new("/path/to/file", "READ")
 *   sig = cs~sign(privateKeyHex)
 *   cs~close
 *
 *   cs = .CryptoStream~new("/path/to/file", "READ")
 *   ok = cs~verify(sigHex, publicKeyHex)
 *   cs~close
 *
 *   enc = .CryptoStream~encryptFile("in.txt", sharedSecret)
 *   dec = .CryptoStream~decryptHex(enc, sharedSecret)
 * ============================================================ */

::class CryptoStream public

/* _key_hex / _nonce_hex: supply to enable streaming ChaCha20.
 * _offset:    ciphertext bytes written or read so far (for keystream position).
 * _line_buf:  decrypted plaintext buffer for lineIn in ChaCha20 mode.
 *
 * Plain mode (no key/nonce):
 *   cs = .CryptoStream~new("file", "READ")
 *   say cs~md5 / cs~sha512 / cs~sign(priv) / cs~verify(sig,pub)
 *
 * Streaming ChaCha20 mode:
 *   WRITE:
 *     cs = .CryptoStream~new("out.enc", "WRITE REPLACE", key_hex, nonce_hex)
 *     cs~charOut("chunk1")   -- encrypted immediately, offset tracked
 *     cs~lineOut("chunk2")   -- same, appends 0a newline
 *     cs~close
 *   READ:
 *     cs = .CryptoStream~new("out.enc", "READ", key_hex, nonce_hex)
 *     chunk = cs~charIn(, 1024)   -- decrypted on the fly
 *     line  = cs~lineIn           -- decrypted line
 *     cs~close
 *
 * Each charOut/charIn call advances _offset so the keystream
 * position is correct -- no keystream reuse, no full buffering. */

::attribute _path       unguarded
::attribute _mode       unguarded
::attribute _stream     unguarded
::attribute _key_hex    unguarded
::attribute _nonce_hex  unguarded
::attribute _offset     unguarded
::attribute _line_buf   unguarded

::method init
  expose _path _mode _stream _key_hex _nonce_hex _offset _line_buf
  use arg path, mode, key_hex, nonce_hex
  if arg() < 2 then mode      = "READ"
  if arg() < 3 then key_hex   = ""
  if arg() < 4 then nonce_hex = ""
  _path      = path
  _mode      = mode~upper
  _key_hex   = key_hex
  _nonce_hex = nonce_hex
  _offset    = 0
  _line_buf  = ""
  _stream    = .Stream~new(path)
  _stream~open(mode)

::method close
  expose _stream
  if _stream \== .nil then _stream~close

/* XOR data with ChaCha20 keystream at _offset, advance _offset.
 * Works for both encrypt (write) and decrypt (read) -- XOR is symmetric.
 * start_block = _offset / 64 + 1   (1-based ChaCha20 block)
 * pos_in_block = _offset mod 64    (byte offset within that block) */
::method _chacha_crypt private
  expose _key_hex _nonce_hex _offset
  use arg data
  if data = "" then return ""
  hex_in       = c2x(data)
  start_block  = _offset % 64 + 1
  pos_in_block = _offset // 64
  bytes_needed  = pos_in_block + length(data)
  blocks_needed = (bytes_needed + 63) % 64 + 1
  keystream = ""
  do blk = start_block to start_block + blocks_needed - 1
    keystream = keystream || rx_chacha20_block(_key_hex, _nonce_hex, blk)
  end
  ks_pos  = pos_in_block * 2 + 1
  out_hex = ""
  do i = 1 to length(hex_in) by 2
    pb = x2d(substr(hex_in,    i,            2))
    kb = x2d(substr(keystream, ks_pos+i-1,   2))
    out_hex = out_hex || right(d2x(rx_xor32(pb, kb)), 2, "0")
  end
  _offset = _offset + length(data)
  return x2c(out_hex)

/* Read whole file for bulk ops (md5/sha512/sign/RSA).
 * In ChaCha20 mode decrypts from byte 0 without disturbing _offset. */
::method _readAll private
  expose _stream _path _mode _key_hex _offset _line_buf
  _stream~close
  s = .Stream~new(_path)
  s~open("READ")
  chars = s~chars
  raw = ""
  if chars > 0 then raw = s~charIn(, chars)
  s~close
  _stream = .Stream~new(_path)
  _stream~open(_mode)
  _line_buf = ""
  if _key_hex \= "" then do
    save = _offset;  _offset = 0
    plain = self~_chacha_crypt(raw)
    _offset = save
    return plain
  end
  return raw

/* ---- Streaming write ---------------------------------------- */

::method charOut
  expose _stream _key_hex
  use arg data
  if _key_hex \= "" then data = self~_chacha_crypt(data)
  return _stream~charOut(data)

::method lineOut
  expose _stream _key_hex
  use arg text
  payload = text || "0a"x
  if _key_hex \= "" then payload = self~_chacha_crypt(payload)
  return _stream~charOut(payload)

/* ---- Streaming read ----------------------------------------- */

::method charIn
  expose _stream _key_hex
  use arg start, len
  if arg() < 2 | len == .nil  then len   = 4096
  if arg() < 1 | start == .nil then raw  = _stream~charIn(, len)
  else raw = _stream~charIn(start, len)
  if _key_hex \= "" then return self~_chacha_crypt(raw)
  return raw

/* Plain mode: delegate to stream~lineIn.
 * ChaCha20 mode: decrypt 512-byte chunks into _line_buf,
 * return text up to the next 0a newline. */
::method lineIn
  expose _stream _key_hex _line_buf
  if _key_hex = "" then return _stream~lineIn
  do while pos("0a"x, _line_buf) = 0 & _stream~state = "READY"
    chunk = _stream~charIn(, 512)
    if chunk = "" then leave
    _line_buf = _line_buf || self~_chacha_crypt(chunk)
  end
  nl = pos("0a"x, _line_buf)
  if nl = 0 then do
    line = _line_buf;  _line_buf = "";  return line
  end
  line = left(_line_buf, nl-1)
  _line_buf = substr(_line_buf, nl+1)
  return line

::method state
  expose _stream
  return _stream~state

/* ---- Bulk crypto (reads whole file) ------------------------- */

::method md5
  content = self~_readAll
  return .MD5~new(content)~digest

::method sha512
  content = self~_readAll
  return .SHA512~new(content)~digest

::method hash
  use arg algo
  if arg() < 1 then algo = "SHA512"
  if algo~upper = "MD5" then return self~md5
  return self~sha512

::method sign
  use arg privateKeyHex
  content = self~_readAll
  return .Ed25519~sign(content, privateKeyHex)

::method verify
  use arg sigHex, publicKeyHex
  content = self~_readAll
  return .Ed25519~verify(content, sigHex, publicKeyHex)

::method encrypt
  use arg key, nonce, mode
  if arg() < 3 then mode  = "X25519"
  if arg() < 2 then nonce = ""
  content = self~_readAll
  if mode~upper = "CHACHA20" then
    return .ChaCha20~encrypt(content, key, nonce)
  return .X25519~encryptStream(content, key)

::method decryptHex class
  use arg cipherHex, sharedSecret
  return .X25519~decryptStream(cipherHex, sharedSecret)

::method encryptRSA
  use arg public_e, modulus_n, session_int
  if arg() < 3 then session_int = 12345
  content = self~_readAll
  return .RSAStream~encrypt(content, public_e, modulus_n, session_int)

::method decryptRSA class
  use arg cipherstream, private_d, modulus_n
  return .RSAStream~decrypt(cipherstream, private_d, modulus_n)


/* ============================================================
 * ::routine directives  — flat helpers used by the classes above
 * ============================================================ */

/* ── Modular arithmetic ─────────────────────────────────── */

::routine rx_mod_inverse
  numeric digits 2000
  use arg a, m
  if a < 0 then a = m + (a // m)
  x0 = 0; x1 = 1; m0 = m
  do while a > 1
    q = a % m; t = m; m = a // m; a = t
    t = x0; x0 = x1 - q * x0; x1 = t
  end
  if x1 < 0 then x1 = x1 + m0
  return x1

::routine rx_pow_mod
  numeric digits 2000
  use arg base, exp, mod
  res = 1; base = base // mod
  do while exp > 0
    if exp // 2 == 1 then res = (res * base) // mod
    base = (base * base) // mod; exp = exp % 2
  end
  return res

::routine rx_recover_x
  use arg y, d, p, I
  num = (y*y - 1) // p
  if num < 0 then num = num + p
  denom = (d*y*y + 1) // p
  xx = (num * rx_mod_inverse(denom,p)) // p
  x  = rx_pow_mod(xx, (p+3)/8, p)
  check = (x*x - xx) // p
  if check \== 0 then x = (x * I) // p
  if x // 2 \== 0 then x = p - x
  return x

/* Ed25519 point decompression — inverse of rx_compress_point */
::routine rx_decompress_point
  use arg pub_key_hex
  p = 2**255 - 19
  inv_val      = rx_mod_inverse(121666, p)
  temp_product = 121665 * inv_val
  raw_d        = temp_product // p
  if raw_d == 0 then d = 0
  else d = p - raw_d
  I = rx_pow_mod(2, (p-1)/4, p)
  last_byte_dec  = x2d(right(pub_key_hex, 2))
  x_should_be_odd = (last_byte_dec >= 128)
  if x_should_be_odd then last_byte_dec = last_byte_dec - 128
  pure_le_hex = left(pub_key_hex, 62) || right(d2x(last_byte_dec), 2, '0')
  y = rx_le_hex_decode(pure_le_hex)
  x = rx_recover_x(y, d, p, I)
  if (x // 2 \== 0) \== x_should_be_odd then x = p - x
  return .EdwardsPoint~new(x, y)

/* ── X25519 Montgomery ladder ───────────────────────────── */

::routine rx_x25519_ladder
  use arg scalar, u_coord, prime
  x_1 = u_coord; x_2 = 1; z_2 = 0; x_3 = u_coord; z_3 = 1; a24 = 121665
  do t = 254 by -1 to 0
    bit = (rx_shr_large(scalar, t) // 2)
    if bit == 1 then do
      temp = x_2; x_2 = x_3; x_3 = temp
      temp = z_2; z_2 = z_3; z_3 = temp
    end
    A = (x_2+z_2) // prime;  AA = (A*A) // prime
    B = (x_2-z_2) // prime;  if B < 0 then B = B + prime
    BB = (B*B) // prime
    E  = (AA-BB) // prime;   if E < 0 then E = E + prime
    C  = (x_3+z_3) // prime
    D  = (x_3-z_3) // prime; if D < 0 then D = D + prime
    DA = (D*A) // prime;  CB = (C*B) // prime
    x_3 = ((DA+CB) * (DA+CB)) // prime
    z_3 = ((DA-CB) * (DA-CB)) // prime; z_3 = (z_3 * x_1) // prime
    x_2 = (AA*BB) // prime
    z_2 = (E * (AA + (a24*E))) // prime
    if bit == 1 then do
      temp = x_2; x_2 = x_3; x_3 = temp
      temp = z_2; z_2 = z_3; z_3 = temp
    end
  end
  return (x_2 * rx_mod_inverse_x(z_2, prime)) // prime

::routine rx_mod_inverse_x
  use arg base, mod
  return rx_pow_mod_x(base, mod-2, mod)

::routine rx_pow_mod_x
  use arg base, exp, mod
  res = 1; base = base // mod
  do while exp > 0
    if exp // 2 == 1 then res = (res * base) // mod
    base = (base * base) // mod; exp = exp % 2
  end
  return res

/* ── Encoding / decoding ────────────────────────────────── */

::routine rx_le_hex_decode
  use arg hex_str
  hex_str = space(hex_str~lower(),0)
  if length(hex_str) // 2 \== 0 then hex_str = "0" || hex_str
  big_endian_hex = ""
  do while length(hex_str) > 0
    byte = right(hex_str, 2); big_endian_hex = big_endian_hex || byte
    hex_str = left(hex_str, length(hex_str)-2)
  end
  base10_result = 0
  do i = 1 to length(big_endian_hex)
    val = pos(substr(big_endian_hex,i,1), "0123456789abcdef") - 1
    base10_result = (base10_result * 16) + val
  end
  return base10_result

::routine rx_le_hex_encode
  use arg integer_val
  big_endian_hex = ""
  do while integer_val > 0
    rem = integer_val // 16
    big_endian_hex = substr("0123456789abcdef",rem+1,1) || big_endian_hex
    integer_val = integer_val % 16
  end
  big_endian_hex = big_endian_hex~right(64,"0")
  little_endian_hex = ""
  do while length(big_endian_hex) > 0
    little_endian_hex = little_endian_hex || right(big_endian_hex,2)
    big_endian_hex = left(big_endian_hex,length(big_endian_hex)-2)
  end
  return little_endian_hex

::routine rx_be_hex_decode
  use arg hex_str
  hex_str = space(hex_str~lower(),0)
  if length(hex_str) // 2 \== 0 then hex_str = "0" || hex_str
  base10_result = 0
  do i = 1 to length(hex_str)
    val = pos(substr(hex_str,i,1), "0123456789abcdef") - 1
    base10_result = (base10_result * 16) + val
  end
  return base10_result

::routine rx_be_hex_encode
  use arg integer_val
  big_endian_hex = ""
  do while integer_val > 0
    rem = integer_val // 16
    big_endian_hex = substr("0123456789abcdef",rem+1,1) || big_endian_hex
    integer_val = integer_val % 16
  end
  return big_endian_hex~right(16,"0")

/* ── Ed25519 key helpers ─────────────────────────────────── */

::routine rx_clamp_scalar
  use arg raw_32byte_le_hex
  first_byte_hex = left(raw_32byte_le_hex,2)
  last_byte_hex  = substr(raw_32byte_le_hex,63,2)
  middle_bytes   = substr(raw_32byte_le_hex,3,60)
  b0  = x2d(first_byte_hex)
  b31 = x2d(last_byte_hex)
  b0  = (b0 % 8) * 8
  if b31 >= 128 then b31 = b31 - 128
  if (b31 % 64) // 2 == 0 then b31 = b31 + 64
  clamped_hex = right(d2x(b0),2,'0') || middle_bytes || right(d2x(b31),2,'0')
  return rx_le_hex_decode(clamped_hex)

::routine rx_compress_point
  use arg point_obj
  le_hex = rx_le_hex_encode(point_obj~y)
  if point_obj~x // 2 \== 0 then do
    last_byte_dec = x2d(right(le_hex,2)) + 128
    le_hex = left(le_hex,62) || right(d2x(last_byte_dec),2,'0')
  end
  return le_hex

/* ── Stream cipher (X25519-CBC-XOR) ─────────────────────── */

::routine rx_string_to_int
  use arg raw_text
  if length(raw_text) > 31 then return -1
  pad_len = 32 - length(raw_text)
  padded_text = raw_text || copies(d2c(pad_len), pad_len)
  hex_payload = c2x(padded_text)~lower()
  base10_out = 0
  do i = 1 to length(hex_payload)
    val = pos(substr(hex_payload,i,1), "0123456789abcdef") - 1
    base10_out = (base10_out * 16) + val
  end
  return base10_out

::routine rx_int_to_string
  use arg large_int
  hex_str = ""
  do while large_int > 0
    rem = large_int // 16
    hex_str = substr("0123456789abcdef",rem+1,1) || hex_str
    large_int = large_int % 16
  end
  hex_str = hex_str~right(64,"0")
  padded_text = x2c(hex_str)
  last_char = right(padded_text,1)
  pad_len = c2d(last_char)
  if pad_len < 1 | pad_len > 32 then return padded_text
  return left(padded_text, 32-pad_len)

::routine rx_encrypt_stream
  use arg long_text, shared_secret
  iv_seed = 987654321012345
  previous_block = rx_xor_large(shared_secret, iv_seed)
  ciphertext_stream = ""
  do while length(long_text) > 0
    chunk = left(long_text,31);  long_text = substr(long_text,32)
    plain_int = rx_string_to_int(chunk)
    cbc_mixed = rx_xor_large(plain_int, previous_block)
    encrypted_block = rx_xor_large(cbc_mixed, shared_secret)
    ciphertext_stream = ciphertext_stream || rx_le_hex_encode(encrypted_block)
    previous_block = encrypted_block
  end
  return ciphertext_stream

::routine rx_decrypt_stream
  use arg ciphertext_stream, shared_secret
  iv_seed = 987654321012345
  previous_block = rx_xor_large(shared_secret, iv_seed)
  decrypted_final_text = ""
  do while length(ciphertext_stream) > 0
    hex_chunk = left(ciphertext_stream,64); ciphertext_stream = substr(ciphertext_stream,65)
    encrypted_block = rx_le_hex_decode(hex_chunk)
    decrypted_cbc = rx_xor_large(encrypted_block, shared_secret)
    plain_int = rx_xor_large(decrypted_cbc, previous_block)
    decrypted_final_text = decrypted_final_text || rx_int_to_string(plain_int)
    previous_block = encrypted_block
  end
  return decrypted_final_text

/* ── 64-bit arithmetic primitives ───────────────────────── */

::routine rx_add64
  use arg a, b
  return (a + b) // 18446744073709551616

::routine rx_and64
  /* Bitwise AND on large integers via bit-by-bit loop */
  use arg a, b
  res = 0; bit = 1
  do while a > 0 | b > 0
    if (a // 2 == 1) & (b // 2 == 1) then res = res + bit
    a = a % 2; b = b % 2; bit = bit * 2
  end
  return res

::routine rx_or64
  use arg a, b
  res = 0; bit = 1
  do while a > 0 | b > 0
    if (a // 2 == 1) | (b // 2 == 1) then res = res + bit
    a = a % 2; b = b % 2; bit = bit * 2
  end
  return res

::routine rx_xor64
  use arg a, b
  res = 0; bit = 1
  do while a > 0 | b > 0
    if (a // 2) \== (b // 2) then res = res + bit
    a = a % 2; b = b % 2; bit = bit * 2
  end
  return res

::routine rx_shr64
  use arg val, shift
  return val % (2**shift)

::routine rx_rotr64
  use arg val, shift
  mask = 18446744073709551616
  right_part = val // (2**shift)
  left_part  = val  % (2**shift)
  return (right_part * (mask % (2**shift))) + left_part

::routine rx_shr_large
  use arg val, shift
  return val % (2**shift)

::routine rx_xor_large
  use arg a, b
  res = 0; bit = 1
  do while a > 0 | b > 0
    if (a // 2) \== (b // 2) then res = res + bit
    a = a % 2; b = b % 2; bit = bit * 2
  end
  return res

/* ── External ────────────────────────────────────────────── */



/* ── RSA routines ───────────────────────────────────────── */

/* Modular exponentiation for RSA — needs digits ≥ 2× decimal length of n */
::routine rx_rsa_pow_mod
  numeric digits 3000
  use arg base, exp, mod
  res = 1; base = base // mod
  do while exp > 0
    if exp // 2 == 1 then res = (res * base) // mod
    base = (base * base) // mod; exp = exp % 2
  end
  return res

/* Encode text as a big-endian integer padded to modulus byte width */
::routine rx_rsa_string_to_int
  numeric digits 3000
  use arg raw_text, modulus_n
  /* Compute byte width of modulus */
  mod_hex = ""
  temp = modulus_n
  do while temp > 0
    mod_hex = substr("0123456789abcdef", (temp//16)+1, 1) || mod_hex
    temp = temp % 16
  end
  /* floor((len-1)/2): guarantees m < n */
  block_bytes = (length(mod_hex) - 1) % 2
  if length(raw_text) >= block_bytes then return -1
  /* PKCS#7 pad */
  pad_len     = block_bytes - length(raw_text)
  padded_text = raw_text || copies(d2c(pad_len), pad_len)
  hex_payload = c2x(padded_text)~lower()
  n = 0
  do i = 1 to length(hex_payload)
    n = (n * 16) + pos(substr(hex_payload,i,1), "0123456789abcdef") - 1
  end
  return n

/* Decode big-endian integer back to text, stripping PKCS#7 */
::routine rx_rsa_int_to_string
  numeric digits 3000
  use arg large_int, modulus_n
  hex_str = ""
  do while large_int > 0
    hex_str = substr("0123456789abcdef", (large_int//16)+1, 1) || hex_str
    large_int = large_int % 16
  end
  /* Match width of modulus */
  mod_hex = ""
  temp = modulus_n
  do while temp > 0
    mod_hex = substr("0123456789abcdef", (temp//16)+1, 1) || mod_hex
    temp = temp % 16
  end
  /* floor match: block_bytes*2 hex chars */
  target = (length(mod_hex) - 1) % 2 * 2
  hex_str     = hex_str~right(target, "0")
  padded_text = x2c(hex_str)
  last_char   = right(padded_text, 1)
  pad_len     = c2d(last_char)
  if pad_len < 1 | pad_len > length(padded_text) then return padded_text
  return left(padded_text, length(padded_text) - pad_len)

/* ── Ed448 helpers ──────────────────────────────────────── */

/* Compress Ed448 point: LE-encode Y, stuff X parity in high bit */
::routine rx_compress_point448
  use arg point_obj
  numeric digits 2000
  /* Ed448 uses 57-byte (456-bit) encoding */
  y    = point_obj~y
  hex  = ""
  do while y > 0
    rem = y // 16
    hex = substr("0123456789abcdef", rem+1, 1) || hex
    y   = y % 16
  end
  hex = hex~right(114, "0")  /* 57 bytes = 114 hex chars */
  /* Reverse bytes for little-endian */
  le_hex = ""
  do while length(hex) > 0
    le_hex = le_hex || right(hex, 2)
    hex = left(hex, length(hex)-2)
  end
  /* Stuff X parity into high bit of last byte */
  if point_obj~x // 2 \== 0 then do
    last = x2d(right(le_hex, 2)) + 128
    le_hex = left(le_hex, 112) || right(d2x(last), 2, '0')
  end
  return le_hex


/* ── ChaCha20 primitives (RFC 8439) ─────────────────────── */

/* 32-bit XOR (semantically correct for ChaCha20 quarter round) */
::routine rx_xor32
  use arg a, b
  res = 0; bit = 1
  a = a // 4294967296
  b = b // 4294967296
  do while a > 0 | b > 0
    if (a // 2) \== (b // 2) then res = res + bit
    a = a % 2; b = b % 2; bit = bit * 2
  end
  return res

::routine rx_add32
  use arg a, b
  return (a + b) // 4294967296

/* Left rotation on 32-bit value */
::routine rx_rotl32
  use arg val, shift
  val = val // 4294967296
  left_part  = val  % (2**(32-shift))
  right_part = val // (2**(32-shift))
  return (right_part * (2**shift) + left_part) // 4294967296

/* Encode a 32-bit word as 8 hex chars in LITTLE-ENDIAN byte order */
::routine rx_le_hex_encode32
  use arg val
  val = val // 4294967296
  be  = right(d2x(val), 8, '0')
  /* reverse bytes: 12345678 → 78563412 */
  return substr(be,7,2) || substr(be,5,2) || substr(be,3,2) || left(be,2)

/* ChaCha20 quarter round — 4 state words in, 4 words out */
::routine rx_chacha_quarter_round
  use arg a, b, c, d
  a = rx_add32(a,b); d = rx_xor32(d,a); d = rx_rotl32(d,16)
  c = rx_add32(c,d); b = rx_xor32(b,c); b = rx_rotl32(b,12)
  a = rx_add32(a,b); d = rx_xor32(d,a); d = rx_rotl32(d, 8)
  c = rx_add32(c,d); b = rx_xor32(b,c); b = rx_rotl32(b, 7)
  return a b c d

/* ChaCha20 block: generate 64-byte (128 hex char) keystream */
::routine rx_chacha20_block
  use arg key_hex, nonce_hex, block_counter
  /* RFC 8439 §2.1 constants: "expand 32-byte k" as LE 32-bit words */
  s.0  = 16
  s.1  = rx_be_hex_decode("61707865")  /* expa */
  s.2  = rx_be_hex_decode("3320646e")  /* nd 3 */
  s.3  = rx_be_hex_decode("79622d32")  /* 2-by  ← fixed (was "2d6279") */
  s.4  = rx_be_hex_decode("6b206574")  /* te k  ← fixed (was "7465206b") */
  /* 256-bit key → 8 × 32-bit LE words */
  do i = 1 to 8
    j   = i - 1
    idx = 4 + i
    s.idx = rx_be_hex_decode(substr(key_hex, j*8+1, 8))
  end
  /* Block counter (32-bit) */
  s.13 = block_counter // 4294967296
  /* 96-bit nonce → 3 × 32-bit words */
  do i = 1 to 3
    j   = i - 1
    idx = 13 + i
    s.idx = rx_be_hex_decode(substr(nonce_hex, j*8+1, 8))
  end
  x. = s.  /* copy initial state */
  /* 20 rounds (10 double-rounds) */
  do i = 1 to 10
    parse value rx_chacha_quarter_round(x.1, x.5, x.9,  x.13) with x.1  x.5  x.9  x.13
    parse value rx_chacha_quarter_round(x.2, x.6, x.10, x.14) with x.2  x.6  x.10 x.14
    parse value rx_chacha_quarter_round(x.3, x.7, x.11, x.15) with x.3  x.7  x.11 x.15
    parse value rx_chacha_quarter_round(x.4, x.8, x.12, x.16) with x.4  x.8  x.12 x.16
    parse value rx_chacha_quarter_round(x.1, x.6, x.11, x.16) with x.1  x.6  x.11 x.16
    parse value rx_chacha_quarter_round(x.2, x.7, x.12, x.13) with x.2  x.7  x.12 x.13
    parse value rx_chacha_quarter_round(x.3, x.8, x.9,  x.14) with x.3  x.8  x.9  x.14
    parse value rx_chacha_quarter_round(x.4, x.5, x.10, x.15) with x.4  x.5  x.10 x.15
  end
  /* Add initial state, serialize each word as 4 bytes LE */
  keystream_hex = ""
  do i = 1 to s.0
    out_word = rx_add32(x.i, s.i)
    keystream_hex = keystream_hex || rx_le_hex_encode32(out_word)
  end
  return keystream_hex  /* 128 hex chars = 64 bytes */

/* ChaCha20 encrypt/decrypt — same operation, XOR with keystream */
::routine rx_chacha20_crypt
  use arg data, key_hex, nonce_hex
  hex_input  = c2x(data)
  hex_output = ""
  block_counter = 1
  keystream = rx_chacha20_block(key_hex, nonce_hex, block_counter)
  key_pos   = 1
  do i = 1 to length(hex_input) by 2
    if key_pos > 127 then do
      block_counter = block_counter + 1
      keystream = rx_chacha20_block(key_hex, nonce_hex, block_counter)
      key_pos = 1
    end
    plain_byte = x2d(substr(hex_input, i, 2))
    key_byte   = x2d(substr(keystream, key_pos, 2))
    key_pos    = key_pos + 2
    hex_output = hex_output || right(d2x(rx_xor32(plain_byte, key_byte)), 2, "0")
  end
  return x2c(hex_output)


/* ── 1024-bit prime generation (Gemini) ─────────────────── */

/* Generate a random 1024-bit prime via Miller-Rabin.
 * Typical time: a few seconds to a few minutes in pure OORexx
 * depending on how quickly a prime candidate is found.
 * All 1024-bit primes are in [10^308, 2×10^308] (309 decimal digits). */
::routine rx_generate_prime_1024 public
  numeric digits 1000
  candidate = rx_generate_1024_candidate()
  do while rx_is_prime_mr(candidate, 40) = 0
    candidate = candidate + 2
  end
  return candidate

/* Build a random 309-digit odd integer in [10^308, 2x10^308).
 * Starts with '1' (forces leading bit) then 307 random decimal digits
 * then one forced-odd last digit.
 * Note: covers the upper half of 1024-bit numbers -- sufficient for RSA. */
::routine rx_generate_1024_candidate public
  numeric digits 1000
  s = "1"
  do i = 1 to 307
    s = s || random(0, 9)
  end
  last = random(0, 9)
  if last // 2 == 0 then last = last + 1
  return (s || last) + 0

/* Miller-Rabin primality test.
 * rounds=40 gives < 4^(-40) ~= 10^(-24) false-prime probability. */
::routine rx_is_prime_mr public
  numeric digits 1000
  use arg n, rounds
  if n // 2 == 0 then return 0
  if n // 3 == 0 then return 0
  if n // 5 == 0 then return 0
  if n // 7 == 0 then return 0
  d = n - 1;  s = 0
  do while d // 2 == 0; d = d % 2; s = s + 1; end
  do i = 1 to rounds
    a = rx_get_prime_witness(i, n)
    x = rx_rsa_pow_mod(a, d, n)
    if x == 1 | x == (n-1) then iterate
    composite = 1
    do r = 1 to s - 1
      x = (x * x) // n
      if x == (n-1) then do; composite = 0; leave; end
      if x == 1 then return 0
    end
    if composite then return 0
  end
  return 1

/* Witness bases: first 25 primes, then deterministic hash of round+n */
::routine rx_get_prime_witness public
  numeric digits 1000
  use arg round_num, n
  witnesses = "2 3 5 7 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97"
  if round_num <= words(witnesses) then
    return word(witnesses, round_num)
  return (round_num * 100003) // (n - 3) + 2


/* Read a cached prime from pool file, randomly selected.
 * Falls back to generating fresh if pool is empty.
 * exclude_prime: pass p to guarantee p != q. */
::routine rx_get_cached_prime public
  numeric digits 2000
  use arg pool_file, exclude_prime
  if arg() < 2 then exclude_prime = ""
  primes = .Array~new
  s = .Stream~new(pool_file)
  if s~query("EXISTS") \== "" then do
    s~open("READ")
    do while s~lines > 0
      line = s~linein~strip
      if line \= "" & line \= exclude_prime~string then
        primes~append(line)
    end
    s~close
  end
  if primes~items > 0 then do
    idx = random(1, primes~items)
    say "  [PrimePool] selected prime" idx "of" primes~items "from" pool_file
    return primes[idx] + 0
  end
  say "  [PrimePool] pool empty, generating fresh prime..."
  p = rx_generate_prime_1024()
  s = .Stream~new(pool_file)
  s~open("WRITE APPEND")
  s~lineout(p)
  s~close
  say "  [PrimePool] saved to" pool_file
  return p

::routine sin EXTERNAL "LIBRARY rxmath RxCalcSin"
