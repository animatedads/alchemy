# OORexx Crypto class 
crypto.cls  —  OORexx Cryptography Library

 Inheritance tree:

   CryptoHash (abstract)
     ├── MD5       — streaming MD5, little-endian int32
     └── SHA512    — streaming SHA-512, big-endian int64

   CurvePoint (abstract)
     ├── EdwardsPoint  — twisted Edwards  Ed25519 (255-bit)
     └── GoldilocksPoint — untwisted Edwards  Ed448  (448-bit)

   Ed25519    — keypair, sign, verify  (needs SHA512)
   Ed448      — keypair, sign, verify  (needs SHA512; Goldilocks curve)
   X25519     — key exchange, shared secret
   ChaCha20   — stream cipher (RFC 8439); key=256-bit, nonce=96-bit
   RSA        — keypair(p,q), encrypt, decrypt, sign, verify
              — generateKeypair() generates fresh 1024-bit primes
   RSAStream  — hybrid RSA+ChaCha20: session scalar RSA-wrapped, bulk ChaCha20

   CryptoStream — wraps OORexx Stream with crypto operations
     hash(algo)  → MD5 or SHA512 digest of stream content
     sign(key)   → Ed25519 hex signature
     verify(sig,key) → boolean
     encrypt/decrypt → X25519-CBC stream cipher

   Word helpers (not public API):
     int32  — 32-bit little-endian word for MD5
     int64  — 64-bit big-endian word for SHA-512

 Routines (::routine directives at bottom of file):
   Curve:    rx_mod_inverse, rx_pow_mod, rx_recover_x
             rx_x25519_ladder, rx_mod_inverse_x, rx_pow_mod_x
   Encoding: rx_le_hex_encode/decode, rx_be_hex_encode/decode
             rx_string_to_int, rx_int_to_string
             rx_compress_point, rx_clamp_scalar
   64-bit:   rx_add64, rx_and64, rx_or64, rx_xor64, rx_shr64
             rx_rotr64, rx_shr_large, rx_xor_large
   Cipher:   rx_encrypt_stream, rx_decrypt_stream
             rx_chacha20_block, rx_chacha20_crypt (fixed)
             rx_le_hex_encode32, rx_xor32, rx_add32, rx_rotl32
   Extern:   sin (rxmath)


# OORexx Runtime Object Serializer v2

Modernised from the original `rto.cls` by Tom Dyer.

## What it does

Serializes a live OORexx object — including its class definition,
all attribute values, and running state — to a JSON payload that can
be transported to another process or machine and reconstructed there
without the original class definition being present.

## Pipeline

```
OORexx object
    ↓  RTOSerializer~serialize
JSON (class source + attribute values)
    ↓  RTOTransport~toBase64
base64 (single line, no wrapping)
    ↓  RTOTransport~md5  +  envelope
{"schema":"oorexx.transport.v1", "md5":"...", "payload":"..."}
    ↓  RTOTransport~_pushToQueue
OORexx .Queue  (in-process via .local)
+  /tmp/rto_transport_queue.json  (cross-process file queue)
    ↑  RTOTransport~receive
verify MD5
    ↑  fromBase64  →  JSON  →  RTOSerializer~deserialize
reconstructed object  (class rebuilt from stored method source)
```

## The alarm that survives transport

`Ticker.cls` runs a `.Alarm` that fires `~tick` every N seconds.
The serializer:
1. Records `_running = .true` in the payload
2. Skips the `.Alarm` instance itself (it is a system timer)
3. On the receiver side, after restoring all attributes,
   detects `_running = .true` and calls `~start` automatically

The alarm resumes on the receiving side. Ticks continue from
the count recorded at serialization time.

## Type spectrum covered

| OORexx type | Serialized as |
|-------------|---------------|
| `.nil` | `{"$t":"nil"}` |
| `.true` / `.false` | `{"$t":"bool","v":1/0}` |
| String / Integer / Decimal | `{"$t":"str","v":"..."}` |
| Array | `{"$t":"arr","$id":N,"v":[...]}` |
| Directory | `{"$t":"dir","$id":N,"v":{...}}` |
| OrderedCollection | `{"$t":"oc","$id":N,"v":[...]}` |
| Queue | `{"$t":"queue","$id":N,"v":[...]}` |
| List | `{"$t":"list","$id":N,"v":[...]}` |
| Set | `{"$t":"set","$id":N,"v":[...]}` |
| Bag | `{"$t":"bag","$id":N,"v":[...]}` |
| Custom object | `{"$t":"obj","cls":"NAME","mixins":[...],"attrs":{...}}` |

Circular references: every collection and object gets an `$id`.
On second encounter a `{"$ref":N}` is emitted instead.

## Running the demo

```bash
chmod +x run_demo.sh
./run_demo.sh
```

Expected output:

```
SENDER  (has Ticker.cls)
[MyTicker]  alarm started — interval: 2s
Waiting for 3 ticks...
[MyTicker]  tick 1 at 10:23:41.123456
[MyTicker]  tick 2 at 10:23:43.234567
[MyTicker]  tick 3 at 10:23:45.345678
...
[Transport]  sent 4821 bytes  →  b64: 6428  md5: a3f2b1c9...

RECEIVER  (no Ticker.cls — class from serialized source)
[Transport]  MD5 verified: a3f2b1c9...
[RTOSerializer]  object was running — restarting...
[MyTicker]  alarm started — interval: 2s
Object received and reconstructed:
  Class:     TICKER
  Ticks so far: 3
  Was running:  1
...
[MyTicker]  tick 4 at 10:23:57.456789   ← alarm alive on receiver
[MyTicker]  tick 5 at 10:23:59.567890
[MyTicker]  tick 6 at 10:24:01.678901
```

## Files

| File | Purpose |
|------|---------|
| `RTOSerializer.cls` | Serialize/deserialize, full type spectrum, circular refs |
| `RTOTransport.cls` | Base64, MD5, in-process Queue + file queue |
| `sender/Ticker.cls` | Demo class — alarm + all collection types |
| `sender/sender.rex` | Create, run, serialize, transport |
| `receiver/receiver.rex` | Receive, reconstruct, verify alarm resumes |
| `run_demo.sh` | Run both in sequence |

## Requirements

- Open Object Rexx 5.x
- `json.cls` (standard ooRexx 5.x package)
- `base64` command
- `md5sum` command
