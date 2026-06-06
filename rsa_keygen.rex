/* ============================================================
 * rsa_keygen.rex  —  RSA-2048 key generation demo
 *
 * Uses a shared prime pool (primes_pool.txt) so primes mined
 * by crypto_test.rex or a previous run are reused instantly.
 * A background PrimeMiner refills the pool while the script
 * runs; the pool grows across invocations.
 *
 * Usage:
 *   rexx rsa_keygen.rex                  -- use/build pool
 *   rexx rsa_keygen.rex primes_pool.txt  -- explicit pool file
 * ============================================================ */

numeric digits 2000

parse arg pool_file
if pool_file = "" then pool_file = "primes_pool.txt"

say copies("=", 60)
say "  RSA-2048 Key Generation — pure OORexx"
say "  Prime pool: " || pool_file
say copies("=", 60)
say ""

/* ── Start background miner to refill the pool ───────────── */
miner = .PrimeMiner~new(pool_file)
miner~start("mine")
call SysSleep 0.1   /* let miner announce itself */
say ""

/* ── Fetch p ─────────────────────────────────────────────── */
call time 'R'
say "Fetching 1024-bit prime p..."
p = rx_get_cached_prime(pool_file)
say "  p ready in" time('E') "seconds"
say "  p =" p~left(40) "..."
say ""

/* ── Fetch q (exclude p to guarantee p != q) ─────────────── */
call time 'R'
say "Fetching 1024-bit prime q..."
q = rx_get_cached_prime(pool_file, p)
say "  q ready in" time('E') "seconds"
say "  q =" q~left(40) "..."
say ""

/* ── Derive keypair ──────────────────────────────────────── */
say "Deriving keypair (n, e, d)..."
kp = .RSA~keypair(p, q)
say "  n bits ~" (kp["n"]~length * 3.32)~format(4,0)
say "  e =" kp["e"]
say "  d =" kp["d"]~left(40) "..."
say ""

/* ── Integer roundtrip ───────────────────────────────────── */
say "Verification 1: integer roundtrip..."
c = .RSA~sign(12345, kp["d"], kp["n"])
m = .RSA~verify(c, kp["e"], kp["n"])
if m = 12345 then
  say "  PASS  12345 -> " || c~left(20) || "... -> " || m
else
  say "  FAIL"

/* ── RSAStream roundtrip ─────────────────────────────────── */
say ""
say "Verification 2: RSAStream (arbitrary-length payload)..."
payload = copies("RSA keygen demo payload string. ", 16)
say "  payload:" length(payload) "chars"
enc = .RSAStream~encrypt(payload, kp["e"], kp["n"])
dec = .RSAStream~decrypt(enc, kp["d"], kp["n"])
if dec = payload then
  say "  PASS  " || length(payload) || "-char payload roundtrip"
else
  say "  FAIL"

/* ── Stop miner ──────────────────────────────────────────── */
say ""
miner~stop
say ""
say copies("=", 60)
say "  Keypair ready.  Pool saved to:" pool_file
say copies("=", 60)
exit 0


/* ============================================================
 * PrimeMiner — background thread; continuously adds primes
 * to the pool file so future runs start instantly.
 * ============================================================ */
::class PrimeMiner public

::method init
  expose poolFile keepMining
  use arg poolFile
  keepMining = .true

::method mine
  expose poolFile keepMining
  say "  [Miner] background prime miner started -> " || poolFile
  do while keepMining
    cand = rx_generate_1024_candidate()
    if rx_is_prime_mr(cand, 40) then do
      if keepMining then do
        s = .Stream~new(poolFile)
        s~open("WRITE APPEND")
        s~lineout(cand)
        s~close
        say "  [Miner] prime added to pool"
      end
    end
  end
  say "  [Miner] stopped"

::method stop
  expose keepMining
  keepMining = .false


::requires "crypto.cls"
