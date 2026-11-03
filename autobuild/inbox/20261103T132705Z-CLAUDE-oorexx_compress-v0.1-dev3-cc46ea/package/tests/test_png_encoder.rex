/* compress dev3: Adler-32, zlib framing, indexed PNG (PURE vs FOREIGN). */
n = 0
call check c2x(.NativeAdler32~new~calculate('Wikipedia')) == '11E60398', 'Adler-32 known vector'
z = .Rfc1950Framing~wrapStored('hello')
call check left(z, 2) == '7801'x & .NativeCompressProvider~new~inflate(substr(z, 3, length(z) - 6)) == 'hello', 'zlib stored frame round-trips'
pal = .directory~new; pal['.'] = '191 218 238'; pal['~'] = '51 126 173'; pal['x'] = '101 104 112'; pal['1'] = '70 0 0'
rows = .array~of('..x1', '~~~~', '.1x.')
pure = .IndexedPngEncoder~new(pal, 2)
b = pure~encodeBase64(rows)
call charout 'png_pure.b64', b; call stream 'png_pure.b64', 'c', 'close'
call check left(b~decodeBase64, 8) == '89504E470D0A1A0A'x, 'PURE writes PNG signature'
signal on syntax name badSym
x = pure~encodeBase64(.array~of('..Z.')); call check .false, 'unknown symbol rejected'
badSym: signal off syntax
n = n + 1
if .ForeignPngProvider~available then do
  f = .IndexedPngEncoder~new(pal, 2, .ForeignPngProvider~new)
  fb = f~encodeBase64(rows)
  call charout 'png_foreign.b64', fb; call stream 'png_foreign.b64', 'c', 'close'
  call check f~lane == 'FOREIGN' & length(fb) < length(b), 'FOREIGN lane compresses'
  say 'FOREIGN lane checked'
end
else say 'SKIP FOREIGN lane (Python zlib bridge unavailable)'
say 'PASS oorexx_compress dev3 png encoder' n 'assertions'
exit 0
check: procedure expose n
  use arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
  n = n + 1
  return
::requires 'IndexedPngEncoder.cls'
::requires 'ForeignPngProvider.cls'
