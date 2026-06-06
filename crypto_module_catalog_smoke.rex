/* crypto_module_catalog_smoke.rex */

say "ChaCha module has updateWrite:" .ChaCha20CipherSession~new("secret")~hasMethod("UPDATEWRITE")
say "RSA hybrid class available:" .RSAHybridCipherSession
say "ED209 class available:" .ED209CipherSession
say "Enigma class available:" .EnigmaM3CipherSession
say "PASS module catalog load"

::requires "crypto.cls"
