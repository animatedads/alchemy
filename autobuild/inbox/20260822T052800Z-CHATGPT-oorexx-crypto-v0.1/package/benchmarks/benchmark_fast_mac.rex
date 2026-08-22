/* Informational benchmark: no pass/fail speed threshold. */
key = "000102030405060708090a0b0c0d0e0f"
msg = "reservation|CHAT-001|generation=143|wlu=20|rate=5"
mac = .SipHash128~new("bench", key)
iterations = 10
start = time('R')
do i = 1 to iterations
  tag = mac~mac(msg)
end
sipSeconds = time('E')
start = time('R')
do i = 1 to iterations
  h = .HMACSHA512~digest(key, msg)
end
hmacSeconds = time('E')
say "iterations=" || iterations
say "siphash128_seconds=" || sipSeconds
say "hmac_sha512_seconds=" || hmacSeconds
if sipSeconds > 0 then say "hmac_over_siphash_ratio=" || (hmacSeconds / sipSeconds)
exit 0
::requires "crypto.cls"
