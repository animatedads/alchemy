call main
exit 0

main:
  say "OBJECT QUEUE FABRIC V0.8 SHARED CRYPTO KNOWN-ANSWER START"

  publicKey = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  signature = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
  if \.Ed25519~verify("", signature, publicKey) then do
    say "FAILED: RFC 8032 Ed25519 test vector 1"
    exit 40
  end

  badSignature = "f" || substr(signature, 2)
  if .Ed25519~verify("", badSignature, publicKey) then do
    say "FAILED: modified RFC signature accepted"
    exit 41
  end

  sha = .SHA512~new("abc")~digest
  expectedSha = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a" ||,
                "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  if sha \== expectedSha then do
    say "FAILED: SHA-512 known-answer mismatch"
    exit 42
  end

  say "  ed25519_rfc8032_vector=OK"
  say "  sha512_abc_vector=OK"
  say "OBJECT QUEUE FABRIC V0.8 SHARED CRYPTO KNOWN-ANSWER: OK"
  return

::requires "crypto.cls"
