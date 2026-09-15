/* Synthetic SIMH framing regression: odd payload padding + error flag + EOM. */
numeric digits 30
path = "simh_odd_fixture.tap"
fixture = x2c("05000080") || x2c("0000000000") || x2c("00") ||,
          x2c("05000080") || x2c("00000000") || x2c("FFFFFFFF")
written = charout(path, fixture, 1)
ignore = charout(path)
if written \= 0 then do
  say "FAIL: fixture write returned" written
  exit 1
end

tape = .SimhTapeReader~new~~mount(path)
r = tape~next
call assertEq r~isData, 1, "data record"
call assertEq r~length, 5, "length mask"
call assertEq r~errorFlag, 1, "error flag"
call assertEq r~wordCount36, 1, "one PDP-10 slot"
call assertEq r~word36(0), 0, "zero word"
r = tape~next
call assertEq r~isMark, 1, "tape mark"
r = tape~next
call assertEq r~isEot, 1, "explicit EOM"
call assertEq r~reason, "MTR_EOM", "EOM reason"
tape~close
call sysfiledelete path
say "SIMH framing acceptance: PASS"
say "  odd-byte pad + error flag + tape mark + explicit EOM"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "../KL10TapeRaw.cls"
