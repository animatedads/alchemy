/* time pure-ooRexx HMAC-SHA512 (crypto v0.8.3, no reference switch) on r13196 */
key = copies("ab", 32)
do len over .array~of(64, 512, 4096)
  msg = copies("x", len)
  t0 = time("E")
  d = .HMACSHA512~digest(key, msg)
  t1 = time("E")
  say "HMAC-SHA512 msg=" || len || "B  seconds=" || format(t1 - t0,,3) || "  digest=" || d~left(16)
end
s = .SHA512~new("abc")~digest
say "SHA512('abc') ok:" (s~left(16) = "ddaf35a193617aba")
exit 0
::requires "crypto.cls"
