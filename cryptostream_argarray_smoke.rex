/* cryptostream_argarray_smoke.rex
 * Exercises optional forwarding paths that previously leaked START/LEN names.
 */

numeric digits 2000

path = "/tmp/cryptostream_argarray_smoke.dat"
secret = 987654321234567898765432123456789
call SysFileDelete path

w = .CryptoStream~new(path, "WRITE REPLACE", secret)
w~charOut("HELLO")
w~charOut("WORLD")
w~close

r = .CryptoStream~new(path, "READ", secret)
say "chars-before:" r~chars
chunk = r~charIn(5)
say "chunk:" chunk
rest = r~charIn(5)
say "rest:" rest
if chunk || rest = "HELLOWORLD" then say "PASS charIn length forwarding"
else say "FAIL got:" chunk || rest
r~close

::requires "crypto_virtual_stream.cls"
