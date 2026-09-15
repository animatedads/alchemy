#!/usr/bin/env rexx
/* Regression for the v0.21.1 native Adler-32 precision repair. */
plain = copies('A', 100000)
compressed = .MySQLDeflate~compressZlib(plain)
call assertEq 'E20C346E', c2x(compressed~right(4)), '100000-byte Adler-32 checksum'
call assertEq plain, .MySQLDeflate~decompressZlib(compressed), 'native zlib round-trip'
say 'MYSQL DEFLATE PRECISION SMOKE PASS'
exit 0

assertEq: procedure
  use strict arg expected, actual, label
  if expected == actual then do
    say 'PASS' label
    return
  end
  say 'FAIL' label || ': expected=' || expected || ' actual=' || actual
  exit 1

::requires 'src/MySQLDeflate.cls'
