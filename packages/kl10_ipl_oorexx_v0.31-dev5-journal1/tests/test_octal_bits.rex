/* String-radix regression: no decimal conversion is used for octal/hex
 * fixture notation, including values wider than 36 bits. */
call assertEq Oct2Bin("405640600000"), "100000101110100000110000000000000000", "octal to binary"
call assertEq Oct2Hex("405640600000"), "82E830000", "real ANDI word octal to hex"
call assertEq Hex2Oct("82E830000"), "405640600000", "real ANDI word hex to octal"
call assertEq Oct2Hex("123456765432"), "29CBBEB1A", "synthetic AC octal to hex"
call assertEq Bin2Oct(Oct2Bin("123456701234567012345670")), "123456701234567012345670", "72-bit octal round trip"

signal on syntax name expectedBadOct
ignored = Oct2Bin("128")
signal off syntax
say "FAIL: invalid octal should fail"
exit 1

expectedBadOct:
signal off syntax
say "KL10 string radix acceptance: PASS"
say "  405640600000 octal = 82E830000 hex"
say "  123456765432 octal = 29CBBEB1A hex"
say "  72-bit round trip uses strings only"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL:" label
    say "  expected:" expected
    say "  actual:  " actual
    exit 1
  end
  return

::requires "../lib/OctalBits.cls"
