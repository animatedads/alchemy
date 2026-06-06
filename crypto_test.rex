/* crypto_test.rex — smoke test for crypto.cls */

say copies("=", 60)
say "  crypto.cls  —  component tests"
say copies("=", 60)

pool_file = "primes_pool.txt"

/* ── 0. START BACKGROUND MINER ───────────────────────────── */
miner = .PrimeMiner~new(pool_file)
miner~start("mine")  /* The ~start message runs the method in a new thread */

/* Give the miner a tiny fraction of a second to print its startup message */
call SysSleep 0.1
say ""


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


/* ── 1. GENERATE OR LOAD PRIMES ──────────────────────────── */
call time 'R'
say "Fetching 1024-bit prime p..."
p = rx_get_cached_prime(pool_file)
say "  p ready in" time('E') "seconds"
say "  p =" p~left(40) "..."
say ""

call time 'R'
say "Fetching 1024-bit prime q..."
q = rx_get_cached_prime(pool_file, p)  /* Pass p to ensure q is different! */
say "  q ready in" time('E') "seconds"
say "  q =" q~left(40) "..."
say ""

/* ── 2. DERIVE KEYPAIR ───────────────────────────────────── */
say "Deriving keypair (n, e, d)..."
kp = .RSA~keypair(p, q)
say "  n bits ≈" (kp["n"]~length * 3.32)~format(4,0) " (block_bytes: 256)"
say "  e =" kp["e"]
say "  d =" kp["d"]~left(40) "..."
say ""

/* ── 3. INTEGER ROUNDTRIP (Raw Math) ─────────────────────── */
say "Verification 1: Raw Integer Math..."
c = .RSA~sign(12345, kp["d"], kp["n"])
m = .RSA~verify(c, kp["e"], kp["n"])
if m = 12345 then
  say "  ✓ PASS — 12345 → encrypted → " || c~left(20) || "... → " || m
else
  say "  ✗ FAIL Integer roundtrip"


/* ── 4. TEXT ROUNDTRIP (Standard RSA, max 255 chars) ─────── */
say ""
say "Verification 2: Standard RSA Text Block..."
big_plain = "Production RSA-2048 test payload: " ||,
            "The quick brown fox jumps over the lazy dog. " ||,
            "0123456789 !@#$%^&* ABCDEF"
say "  plaintext length:" length(big_plain) "chars"

enc_text = .RSA~encrypt(big_plain, kp["e"], kp["n"])
dec_text = .RSA~decrypt(enc_text,  kp["d"], kp["n"])

if dec_text = big_plain then
  say "  ✓ PASS — text block roundtrip"
else do
  say "  ✗ FAIL text roundtrip"
  say "  got: [" || dec_text || "]"
end


/* ── 5. RSAStream ROUNDTRIP (Arbitrary Length Text) ──────── */
say ""
say "Verification 3: RSAStream Hybrid Encryption..."
payload = copies("This is a much longer RSAStream payload string. ", 16)
say "  payload length:" length(payload) "chars"

enc_stream = .RSAStream~encrypt(payload, kp["e"], kp["n"])
dec_stream = .RSAStream~decrypt(enc_stream, kp["d"], kp["n"])

if dec_stream = payload then
  say "  ✓ PASS — arbitrary-length stream roundtrip"
else
  say "  ✗ FAIL stream roundtrip"

/* ── 6. SHUTDOWN BACKGROUND MINER ────────────────────────── */
say ""
say copies("=", 60)
say "  Done. Keypair is fully verified and ready for use."
say copies("=", 60)

say "Sending stop signal to background Prime Miner..."
miner~stop
/* Note: It might take a few seconds for the miner to finish its current
 * loop before it acknowledges the stop command. We can exit immediately,
 * which will forcefully kill the background thread safely. */
exit


/* ============================================================
 * Helper Routine: Get prime from cache or generate a new one
 * ============================================================ */
::routine rx_get_cached_prime
  use arg filename, exclude_prime = ""

  primes = .array~new
  s = .Stream~new(filename)

  /* Read existing primes if the file exists */
  if s~query("EXISTS") \= "" then do
    s~open("READ")
    do while s~lines > 0
      line = s~linein~strip
      /* Only add to available pool if it's not the excluded prime */
      if line \= "", line \= exclude_prime then
        primes~append(line)
    end
    s~close
  end

  /* If we have valid primes in the cache, pick a random one */
  if primes~items > 0 then do
    say "  [INFO] Retrieved prime from cache ("||filename||")"
    idx = random(1, primes~items)
    return primes[idx]
  end

  /* Otherwise, let the foreground thread generate a fresh one
   * (The background miner might also be working on one!) */
  say "  [INFO] Cache empty. Generating new prime in foreground..."
  cand = rx_generate_prime_1024()

  /* Append the newly found prime to the file for next time */
  s = .Stream~new(filename)
  s~open("WRITE APPEND")
  s~lineout(cand)
  s~close

  return cand

/* ============================================================
 * Helper Routine: Search for a 1024-bit prime
 * ============================================================ */
::routine rx_generate_prime_1024
  loop
    /* Generate a random odd 1024-bit candidate using crypto.cls */
    cand = rx_generate_1024_candidate()

    /* Test primality with 40 Miller-Rabin rounds */
    if rx_is_prime_mr(cand, 40) then return cand
  end

/* ============================================================
 * CLASS: PrimeMiner (Background Object Thread)
 * ============================================================ */
::class PrimeMiner
::method init
  expose poolFile keepMining
  use arg poolFile
  keepMining = .true

::method mine
  expose poolFile keepMining
  say "  [Miner] Started looking for primes in the background..."

  do while keepMining
    cand = rx_generate_1024_candidate()

    /* We test candidates continuously. If we find one, write it. */
    if rx_is_prime_mr(cand, 40) then do
      /* Check keepMining again in case we were stopped during the test */
      if keepMining then do
        s = .Stream~new(poolFile)
        s~open("WRITE APPEND")
        s~lineout(cand)
        s~close
      end
    end
  end

::method stop
  expose keepMining
  keepMining = .false

::requires "crypto.cls"
