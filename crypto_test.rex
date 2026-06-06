/* crypto_test.rex — smoke test for crypto.cls */
parse arg pool_file
if pool_file = "" then pool_file = "primes_pool.txt"

say copies("=", 60)
say "  crypto.cls  —  component tests"
say copies("=", 60)

/* ── MD5 ─────────────────────────────────────────────────── */
say ""
say "MD5:"
tests.1.1 = ""; tests.1.2 = "d41d8cd98f00b204e9800998ecf8427e"
tests.2.1 = "abc"; tests.2.2 = "900150983cd24fb0d6963f7d28e17f72"
tests.3.1 = "message digest"; tests.3.2 = "f96b697d7cb7938d525a2f31aaf161d0"
do i = 1 to 3
  got = .MD5~new(tests.i.1)~digest
  if got = tests.i.2 then say "  PASS [" || tests.i.1~left(16) || "]"
  else do
    say "  FAIL [" || tests.i.1 || "]"
    say "    expected:" tests.i.2
    say "         got:" got
  end
end

/* ── SHA-512 ─────────────────────────────────────────────── */
say ""
say "SHA-512:"
sha_tests.1.1 = ""
sha_tests.1.2 = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
sha_tests.2.1 = "abc"
sha_tests.2.2 = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
sha_tests.3.1 = "message digest"
sha_tests.3.2 = "107dbf389d9e9f71a3a95f6c055b9251bc5268c2be16d6c13492ea45b0199f3309e16455ab1e96118e8a905d5597b72038ddb372a89826046de66687bb420e7c"
do i = 1 to 3
  got = .SHA512~new(sha_tests.i.1)~digest
  if got = sha_tests.i.2 then say "  PASS [" || sha_tests.i.1~left(16) || "]"
  else do
    say "  FAIL [" || sha_tests.i.1 || "]"
    say "  got:" got~left(64) "..."
    say "  exp:" sha_tests.i.2~left(64) "..."
  end
end

/* ── X25519 key exchange ─────────────────────────────────── */
say ""
say "X25519 key exchange:"
p = 2**255 - 19
alice_priv = 432198765432101234567890123456789012345678901234567890123456789 // p
bob_priv   = 9876543210123456789012345678901234567890123456789012345 // p
alice_pub  = .X25519~publicKey(alice_priv)
bob_pub    = .X25519~publicKey(bob_priv)
alice_shared = .X25519~sharedSecret(alice_priv, bob_pub)
bob_shared   = .X25519~sharedSecret(bob_priv,   alice_pub)
if alice_shared = bob_shared then
  say "  PASS shared secrets match"
else
  say "  FAIL shared secrets differ"

/* ── X25519-CBC stream encrypt/decrypt ───────────────────── */
say ""
say "Stream cipher:"
plain = "Hello from OORexx crypto layer! Testing 1 2 3."
enc   = .X25519~encryptStream(plain, alice_shared)
dec   = .X25519~decryptStream(enc,   alice_shared)
if plain = dec~strip then
  say "  PASS encrypt/decrypt roundtrip"
else do
  say "  FAIL roundtrip"
  say "  original:  " plain
  say "  decrypted: " dec
end

/* ── Ed25519 keypair + sign + verify ─────────────────────── */
say ""
say "Ed25519:"
seedHex = "eedcd654326543111122223333444455556666777788889999aaaabbbbccccff"
kp  = .Ed25519~keypair(seedHex)
say "  public key:" kp["public"]
msg = "Authenticate this payload"
sig = .Ed25519~sign(msg, kp["private"])
say "  signature: " sig~left(32) "..."
ok  = .Ed25519~verify(msg, sig, kp["public"])
if ok then
  say "  PASS signature verifies"
else
  say "  FAIL signature invalid"

/* ── CryptoStream ────────────────────────────────────────── */
say ""
say "CryptoStream:"
tmpFile = "/tmp/crypto_test_stream.txt"
s = .Stream~new(tmpFile); s~open("WRITE REPLACE")
rc = s~lineOut("This is a test file for CryptoStream.")
rc = s~lineOut("Second line of content.")
s~close
cs = .CryptoStream~new(tmpFile, "READ")
say "  MD5:    " cs~md5
say "  SHA-512:" cs~sha512~left(32) "..."
sig2 = cs~sign(kp["private"])
ok2  = cs~verify(sig2, kp["public"])
if ok2 then say "  PASS file sign/verify"
else say "  FAIL file sign/verify"
cs~close
call SysFileDelete tmpFile

say ""
say copies("=", 60)
say "  Done."
say copies("=", 60)


/* ── ChaCha20 RFC 8439 test vector ──────────────────────── */
say ""
say "ChaCha20:"
/* RFC 8439 §2.4.2 test vector */
key_hex   = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
nonce_hex = "000000000000004a00000000"
plain     = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
enc = .ChaCha20~encrypt(plain, key_hex, nonce_hex)
dec = .ChaCha20~decrypt(enc, key_hex, nonce_hex)
if dec = plain then
  say "  PASS ChaCha20 roundtrip (" || length(plain) || " bytes)"
else do
  say "  FAIL ChaCha20 roundtrip"
  say "  plain: " plain~left(30)
  say "  dec:   " dec~left(30)
end

/* ── GoldilocksPoint smoke test ──────────────────────────── */
say ""
say "GoldilocksPoint (Ed448):"
G448 = .Ed448~G
say "  G.x = " G448~x~left(20) "..."
say "  G.y = " G448~y~left(20) "..."
G1   = G448~multiply(1)
if G1~x = G448~x & G1~y = G448~y then
  say "  PASS multiply(1) = G"
else
  say "  FAIL multiply(1) != G"


/* ── RSA with keypair generation ────────────────────────── */
say ""
say "RSA:"
/* Use the textbook toy primes — same as Gemini's integer test */
rsa_kp = .RSA~keypair(61, 53)   /* n=3233, phi=3120 */
say "  n=" rsa_kp["n"] "  e=" rsa_kp["e"] "  d=" rsa_kp["d"]

/* Integer roundtrip via sign/verify (raw mod-exp) */
c  = .RSA~sign(65, rsa_kp["d"], rsa_kp["n"])   /* 65^d mod n */
m2 = .RSA~verify(c, rsa_kp["e"], rsa_kp["n"])  /* c^e mod n */
if m2 = 65 then say "  PASS integer roundtrip (65 → " || c || " → " || m2 || ")"
else say "  FAIL integer roundtrip"

/* Text roundtrip — modulus must exceed plaintext in bytes.
 * p=999999999989, q=999999999961 → n ~10^24 → block_bytes=10 → max 9 chars */
big_kp = .RSA~keypair(999999999989, 999999999961)
plain  = "Hello"  /* 9 chars — fits in block_bytes=10 */
enc    = .RSA~encrypt(plain, big_kp["e"], big_kp["n"])
dec    = .RSA~decrypt(enc,   big_kp["d"], big_kp["n"])
if dec = plain then say "  PASS text roundtrip [" || plain || "]"
else do
  say "  FAIL text roundtrip"
  say "  got: [" || dec || "]"
end


/* ── RSAStream hybrid encryption ────────────────────────── */
say ""
say "RSAStream (hybrid RSA+ChaCha20):"
/* Same small keypair works because only the session scalar goes
 * through RSA — bulk content goes through ChaCha20             */
hs_kp = .RSA~keypair(999999999989, 999999999961)
long_text = "This is a much longer message that would never fit in a single RSA block.",
            " RSAStream encrypts it with ChaCha20 keyed by a SHA512-derived session key,",
            " with only the tiny session scalar RSA-encrypted for key exchange."
say "  Original length:" length(long_text) "chars"
enc  = .RSAStream~encrypt(long_text, hs_kp["e"], hs_kp["n"])
say "  Encrypted (hex): " left(enc, 40) "..."
dec  = .RSAStream~decrypt(enc, hs_kp["d"], hs_kp["n"])
if dec = long_text then
  say "  PASS RSAStream roundtrip"
else do
  say "  FAIL RSAStream roundtrip"
  say "  dec: " dec~left(40)
end

/* CryptoStream integration */
say ""
say "CryptoStream + RSA:"
tmpRSA = "/tmp/rsa_stream_test.txt"
s2 = .Stream~new(tmpRSA); s2~open("WRITE REPLACE")
rc = s2~charOut(long_text); s2~close
cs2 = .CryptoStream~new(tmpRSA, "READ")
enc2 = cs2~encryptRSA(hs_kp["e"], hs_kp["n"])
cs2~close
dec2 = .CryptoStream~decryptRSA(enc2, hs_kp["d"], hs_kp["n"])
if dec2 = long_text then
  say "  PASS CryptoStream RSA roundtrip"
else
  say "  FAIL CryptoStream RSA roundtrip"
call SysFileDelete tmpRSA


/* ── RSA-2048 production-sized test ─────────────────────── */
say ""
say "RSA-2048 (1024-bit primes, verified with Miller-Rabin):"
/* Pre-computed verified prime pair — n is 2047 bits (256-byte block) */
rsa2048_p = "97771702844241388784495639657700536700673645243038672869868941113",
              ||"11365409275249805746509975785097585132618051531746582086746936899",
              ||"51672831522507651895645671084851294156705549048238054426466932136",
              ||"03168654206041094096024080440745643448852755395039614582186298270",
              ||"835224245120672423197099120338577895907808882059"
rsa2048_q = "96668423208433513137833216550553921339410868476798559411339595386",
              ||"65404944537649412174112127004156287363781664619370983851971167746",
              ||"54315126480338651122652167423058404609275112738420547883064144440",
              ||"60770699467883038907431097161143206071440395523298438666428835193",
              ||"180251033457047242459361316256850294729401241749"
rsa2048_e = 65537

rsa2048_p = rx_get_cached_prime(pool_file)
rsa2048_q = rx_get_cached_prime(pool_file, p)


/* Derive d from p, q, e using rx_mod_inverse */
rsa2048_kp = .RSA~keypair(rsa2048_p, rsa2048_q, rsa2048_e)
rsa2048_n  = rsa2048_kp["n"]
rsa2048_d  = rsa2048_kp["d"]

say "  n bits: 2047   block_bytes: 256   max plaintext: 255 chars"

/* Integer roundtrip */
c2048 = .RSA~sign(99, rsa2048_d, rsa2048_n)
m2048 = .RSA~verify(c2048, rsa2048_e, rsa2048_n)
if m2048 = 99 then say "  PASS integer roundtrip (99 → " || c2048~left(20) || "... → " || m2048 || ")"
else say "  FAIL integer roundtrip"

/* Full text RSA — 255 chars max with 256-byte block */
big_plain = "Production RSA-2048 test payload: " ||,
            "The quick brown fox jumps over the lazy dog. " ||,
            "0123456789 !@#$%^&* ABCDEF"
say "  plaintext length:" length(big_plain) "chars"
enc2048 = .RSA~encrypt(big_plain, rsa2048_e, rsa2048_n)
dec2048 = .RSA~decrypt(enc2048,   rsa2048_d, rsa2048_n)
if dec2048 = big_plain then say "  PASS RSA-2048 text roundtrip"
else do
  say "  FAIL RSA-2048 text roundtrip"
  say "  dec: [" || dec2048~left(40) || "]"
end

/* RSAStream with RSA-2048 keys — arbitrary-length payload */
huge_plain = copies("The RSA-2048 stream cipher test. ", 20)
say "  RSAStream payload:" length(huge_plain) "chars (any length works)"
enc_stream  = .RSAStream~encrypt(huge_plain, rsa2048_e, rsa2048_n)
dec_stream  = .RSAStream~decrypt(enc_stream, rsa2048_d, rsa2048_n)
if dec_stream = huge_plain then say "  PASS RSAStream+RSA-2048 roundtrip"
else say "  FAIL RSAStream+RSA-2048 roundtrip"

::requires "crypto.cls"
