/* ============================================================
 * rsa_keygen.rex  —  RSA-2048 key generation demo
 *
 * Generates two fresh 1024-bit primes using Miller-Rabin,
 * derives d = e^-1 mod phi(n), and proves the keypair works.
 *
 * Timing: each prime candidate takes a Miller-Rabin pass with
 * 40 witnesses × up to 1024 squarings of 309-digit numbers.
 * Expect ~1-5 minutes per prime in pure OORexx.
 * ============================================================ */

numeric digits 2000

say copies("=", 60)
say "  RSA-2048 Key Generation — pure OORexx"
say copies("=", 60)
say ""

call time 'R'

say "Generating 1024-bit prime p..."
p = rx_generate_prime_1024()
say "  p found in" time('E') "seconds"
say "  p =" p~left(40) "..."
say ""

call time 'R'
say "Generating 1024-bit prime q..."
q = rx_generate_prime_1024()
say "  q found in" time('E') "seconds"
say "  q =" q~left(40) "..."
say ""

say "Deriving keypair (n, e, d)..."
kp = .RSA~keypair(p, q)
say "  n bits ≈" (kp["n"]~length * 3.32)~format(4,0)
say "  e =" kp["e"]
say "  d =" kp["d"]~left(40) "..."
say ""

say "Verification (encrypt 12345 then decrypt)..."
c = .RSA~sign(12345, kp["d"], kp["n"])
m = .RSA~verify(c, kp["e"], kp["n"])
if m = 12345 then say "  ✓ PASS — 12345 → encrypted → " || c~left(20) || "... → " || m
else say "  ✗ FAIL"

say ""
say "RSAStream (encrypt 500-char payload)..."
payload = copies("RSA keygen demo payload string. ", 16)
enc = .RSAStream~encrypt(payload, kp["e"], kp["n"])
dec = .RSAStream~decrypt(enc, kp["d"], kp["n"])
if dec = payload then say "  ✓ PASS — " || length(payload) || "-char payload roundtrip"
else say "  ✗ FAIL"

say ""
say copies("=", 60)
say "  Keypair ready for use."
say copies("=", 60)

::requires "crypto.cls"
