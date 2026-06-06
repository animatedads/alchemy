/* cryptostream_virtual_smoke.rex
 * Manual smoke for the rewritten virtual CryptoStream.
 */

numeric digits 2000

path = "/tmp/cryptostream_virtual_smoke.dat"
secret = 1234567890123456789012345678901234567890

call SysFileDelete path

cs = .CryptoStream~new(path, "WRITE REPLACE", secret)
cs~charOut("a word")
cs~charOut("another word")
cs~charOut("a further word")
cs~lineOut("a line")
say "chars during write should be ciphertext-hidden; close finalises"
cs~close

raw = .Stream~new(path)
raw~open("READ")
rawText = raw~charIn(, raw~chars)
say "physical ciphertext chars:" rawText~length
say "physical ciphertext hex:" c2x(rawText)
if pos(c2x("a word"), c2x(rawText)) = 0 then say "PASS no direct plaintext hex marker"
else say "WARN plaintext hex marker visible"
raw~close

rs = .CryptoStream~new(path, "READ", secret)
say "virtual plaintext chars:" rs~chars
say "virtual plaintext lines:" rs~lines
line = rs~lineIn
say "line:" line
if line = "a wordanother worda further worda line" then say "PASS virtual stream continuity"
else say "FAIL got:" line
rs~close

::requires "crypto.cls"
