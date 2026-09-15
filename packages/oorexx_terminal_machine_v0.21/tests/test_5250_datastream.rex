failures = 0
cp = .CodePage037~new

/* IBM Table 15-6 / 15-8 format-word decoding. */
ffw = .FieldFormatWord5250~new("4000"x)
call assertTrue \ffw~bypass, "basic FFW non-bypass"
call assertEq ffw~shiftName, "ALPHA_SHIFT", "basic FFW alpha shift"
call assertTrue \ffw~modified, "basic FFW MDT clear"
ffw2 = .FieldFormatWord5250~new("6AAE"x)
call assertTrue ffw2~bypass, "FFW bypass bit"
call assertTrue ffw2~modified, "FFW MDT bit"
call assertEq ffw2~shiftName, "NUMERIC_SHIFT", "FFW numeric shift"
call assertTrue ffw2~autoEnter, "FFW auto enter"
call assertTrue ffw2~monocase, "FFW monocase"
call assertTrue ffw2~mandatoryEnter, "FFW mandatory enter"
call assertEq ffw2~adjustCode, 6, "FFW adjust code"
fcw = .FieldControlWord5250~new("84A5"x)
call assertEq fcw~kind, "TRANSPARENT", "transparent FCW"
call assertTrue fcw~isTransparent, "transparent predicate"
call assertTrue .DisplayAttribute5250~new("27"x)~nonDisplay, "x27 nondisplay"
call assertTrue .DisplayAttribute5250~new("3F"x)~nonDisplay, "x3f nondisplay"

/* A real WTD byte stream: protected text + normal input + nondisplay input. */
model = .PresentationSpace5250~new
machine = .DataStream5250Machine~new(model, cp)
wtd = "0411"x || "0008"x ||,                 /* WTD, unlock at end */
      "11"x || d2c(2) || d2c(5) || cp~encode("HELLO") ||,
      "11"x || d2c(10) || d2c(19) || "1D400020000A"x || cp~encode("FRED") ||,
      "11"x || d2c(11) || d2c(19) || "1D400027000A"x || cp~encode("SECRET") ||,
      "13"x || d2c(10) || d2c(20)
parsed = machine~consume(wtd)
call assertTrue parsed~ok, "parse WTD"
call assertEq parsed~value~commandName, "WRITE_TO_DISPLAY", "WTD outcome"
call assertEq model~readLinearText(2,5,5), "HELLO", "protected text decoded"
user = model~field("F0740")
password = model~field("F0820")
call assertTrue user \== .nil, "user field created"
call assertTrue password \== .nil, "password field created"
call assertEq user~value~strip, "FRED", "host user data"
call assertEq password~value~strip, "SECRET", "wire-side password retained"
call assertTrue password~nonDisplay, "password nondisplay"
call assertEq model~readLinearText(11,20,6), "******", "nondisplay rendered masked"
call assertEq model~keyboardState, "UNLOCKED", "WTD unlock"
call assertEq model~cursorRow, 10, "IC cursor row"
call assertEq model~cursorColumn, 20, "IC cursor column"
snap = model~hostCommit
call assertEq snap~field("F0820")~value, "<SECRET>", "snapshot password redacted"
call assertTrue snap~contentDigest \= "", "content fingerprint created"
call assertTrue snap~layoutFingerprint \= "", "layout fingerprint created"

/* MC wins cursor position but does not replace the IC/home position. */
wtd2 = "0411"x || "0008"x || "13"x || d2c(4) || d2c(7) || "14"x || d2c(5) || d2c(9)
parsed = machine~consume(wtd2)
call assertTrue parsed~ok, "parse IC+MC"
call assertEq model~homeRow, 4, "IC updates home row"
call assertEq model~homeColumn, 7, "IC updates home column"
call assertEq model~cursorRow, 5, "MC final cursor row"
call assertEq model~cursorColumn, 9, "MC final cursor column"

/* A later WTD with no IC removes the older home address.  Home then falls
 * back to the first non-bypass input field, as IBM Chapter 16 specifies. */
wtdNoIC = "0411"x || "0000"x || "14"x || d2c(6) || d2c(10)
parsed = machine~consume(wtdNoIC)
call assertTrue parsed~ok, "parse WTD without IC"
model~setKeyboardState("UNLOCKED")
model~setSessionState("OPERATOR_WAIT")
call assertTrue model~homeCursor~ok, "Home fallback after WTD without IC"
call assertEq model~cursorRow, 10, "Home fallback first input row"
call assertEq model~cursorColumn, 20, "Home fallback first input col"

/* Repeat-to-address and erase-to-address operate on linear display addresses. */
wtd3 = "0411"x || "0000"x || "11"x || d2c(3) || d2c(1) ||,
       "02"x || d2c(3) || d2c(5) || cp~encode("X")
parsed = machine~consume(wtd3)
call assertTrue parsed~ok, "parse RA"
call assertEq model~readLinearText(3,1,5), "XXXXX", "RA inclusive fill"
wtd4 = "0411"x || "0000"x || "11"x || d2c(3) || d2c(1) ||,
       "03"x || d2c(3) || d2c(5) || d2c(2) || "00"x
parsed = machine~consume(wtd4)
call assertTrue parsed~ok, "parse EA"
call assertEq model~readLinearText(3,1,5), "     ", "EA clears display range"

/* TD uses an explicit two-byte length and accepts byte values ordinary WTD text cannot. */
wtd5 = "0411"x || "0000"x || "11"x || d2c(4) || d2c(1) || "10"x || "0003"x || "00FF41"x
parsed = machine~consume(wtd5)
call assertTrue parsed~ok, "parse TD"
truncated = machine~consume("0411"x || "0000"x || "10"x || "0004"x || "0102"x)
call assertTrue \truncated~ok, "truncated TD rejected"
call assertEq truncated~code, "5250_TRUNCATED", "truncated TD error"

/* The RFC 1205 row1/column0 exception is legal only immediately before SF. */
row1 = .PresentationSpace5250~new
m2 = .DataStream5250Machine~new(row1, cp)
r1 = "0411"x || "0008"x || "11"x || d2c(1) || d2c(0) || "1D4000200005"x || cp~encode("ABCDE")
parsed = m2~consume(r1)
call assertTrue parsed~ok, "row1 col0 SF accepted"
call assertTrue row1~field("F0001") \== .nil, "row1 col1 field created"
call assertEq row1~field("F0001")~value, "ABCDE", "row1 col1 field data"
badR1 = m2~consume("0411"x || "0000"x || "11"x || d2c(1) || d2c(0) || cp~encode("X"))
call assertTrue \badR1~ok, "row1 col0 without SF rejected"
call assertEq badR1~code, "5250_SBA_ROW1_COL0_REQUIRES_SF", "row1 col0 error"
badSecretR1 = m2~consume("0411"x || "0000"x || "11"x || d2c(1) || d2c(0) || "1D4000270005"x)
call assertTrue \badSecretR1~ok, "row1 col1 nondisplay input rejected"
call assertEq badSecretR1~code, "5250_ROW1_COL1_NONDISPLAY", "row1 nondisplay error"

/* Unknown WTD orders are fail-closed, not treated as display bytes. */
bad = machine~consume("0411"x || "0000"x || "06"x)
call assertTrue \bad~ok, "unknown order rejected"
call assertEq bad~code, "5250_WTD_ORDER_UNKNOWN", "unknown order error"

/* CLEAR FORMAT TABLE keeps pixels; CUA x80 clears both screen and format. */
fmt = .PresentationSpace5250~new
m3 = .DataStream5250Machine~new(fmt, cp)
call assertTrue m3~consume("0411"x || "0008"x || "11"x || d2c(2) || d2c(2) || "1D4000200003"x || cp~encode("ABC"))~ok, "setup format"
before = fmt~readLinearText(2,3,3)
call assertEq before, "ABC", "setup visible data"
call assertTrue m3~consume("0450"x)~ok, "clear format table"
call assertEq fmt~fieldsForDriver~items, 0, "format gone"
call assertEq fmt~readLinearText(2,3,3), "ABC", "screen retained"
call assertTrue m3~consume("042080"x)~ok, "CUA 80"
call assertEq fmt~fieldsForDriver~items, 0, "CUA format empty"
call assertEq fmt~readLinearText(2,3,3), "   ", "CUA screen cleared"
cu27 = m3~consume("042000"x)
call assertTrue \cu27~ok, "unsupported 27x132 rejected"
call assertEq cu27~code, "5250_SCREEN_SIZE_UNSUPPORTED", "CUA size error"


/* IBM Table 15-2 uses MSB-first bit numbering: operation selector bits 0-2
 * are x'20' increments, while bit 7/x'01' is independently non-stream.
 * Nulling and MDT reset are separate effects. */
cc = .PresentationSpace5250~new
call assertTrue cc~defineField("IN", 6, 5, 4, "ABCD", .true, .false, .false, .false, .nil, .true)~ok, "CC0 input setup"
call assertTrue cc~defineField("BYP", 7, 5, 4, "WXYZ", .false, .true, .false, .false, .nil, .true)~ok, "CC0 bypass setup"
cm = .DataStream5250Machine~new(cc, cp)

/* 001: reset pending AID / lock keyboard only.  Existing data and MDT stay. */
cc~setKeyboardState("UNLOCKED")
call assertTrue cm~consume("0411"x || "2000"x)~ok, "CC0 001"
call assertEq cc~keyboardState, "LOCKED", "CC0 001 locks keyboard"
call assertEq cc~field("IN")~value, "ABCD", "CC0 001 retains input data"
call assertTrue cc~field("IN")~modified, "CC0 001 retains input MDT"
call assertTrue cc~field("BYP")~modified, "CC0 001 retains bypass MDT"

/* 100: null only non-bypass fields whose MDT is on; do not reset MDT. */
call assertTrue cm~consume("0411"x || "8000"x)~ok, "CC0 100"
call assertEq cc~field("IN")~value, "", "CC0 100 nulls modified non-bypass"
call assertTrue cc~field("IN")~modified, "CC0 100 preserves MDT"
call assertEq cc~field("BYP")~value, "WXYZ", "CC0 100 leaves bypass value"
call assertTrue cc~field("BYP")~modified, "CC0 100 leaves bypass MDT"

/* Restore values/MDT, then 010 resets non-bypass MDT but does not null data. */
dummy = cc~hostFieldValue("IN", "ABCD")
dummy = cc~setFieldModifiedById("IN", .true)
call assertTrue cm~consume("0411"x || "4000"x)~ok, "CC0 010"
call assertEq cc~field("IN")~value, "ABCD", "CC0 010 retains input data"
call assertTrue \cc~field("IN")~modified, "CC0 010 resets non-bypass MDT"
call assertTrue cc~field("BYP")~modified, "CC0 010 leaves bypass MDT"

/* 011 resets MDT in all fields. */
dummy = cc~setFieldModifiedById("IN", .true)
dummy = cc~setFieldModifiedById("BYP", .true)
call assertTrue cm~consume("0411"x || "6000"x)~ok, "CC0 011"
call assertTrue \cc~field("IN")~modified, "CC0 011 resets input MDT"
call assertTrue \cc~field("BYP")~modified, "CC0 011 resets bypass MDT"

/* 101 resets non-bypass MDT and nulls all non-bypass fields. */
dummy = cc~hostFieldValue("IN", "ABCD")
dummy = cc~setFieldModifiedById("IN", .true)
call assertTrue cm~consume("0411"x || "A000"x)~ok, "CC0 101"
call assertEq cc~field("IN")~value, "", "CC0 101 nulls non-bypass"
call assertTrue \cc~field("IN")~modified, "CC0 101 resets non-bypass MDT"

/* 110 nulls only MDT-on non-bypass fields then resets non-bypass MDT. */
dummy = cc~hostFieldValue("IN", "ABCD")
dummy = cc~setFieldModifiedById("IN", .true)
call assertTrue cm~consume("0411"x || "C000"x)~ok, "CC0 110"
call assertEq cc~field("IN")~value, "", "CC0 110 nulls modified non-bypass"
call assertTrue \cc~field("IN")~modified, "CC0 110 resets MDT"

/* 111 nulls all non-bypass fields and resets MDT everywhere. */
dummy = cc~hostFieldValue("IN", "ABCD")
dummy = cc~setFieldModifiedById("IN", .true)
dummy = cc~setFieldModifiedById("BYP", .true)
call assertTrue cm~consume("0411"x || "E000"x)~ok, "CC0 111"
call assertEq cc~field("IN")~value, "", "CC0 111 nulls non-bypass"
call assertTrue \cc~field("IN")~modified, "CC0 111 resets input MDT"
call assertTrue \cc~field("BYP")~modified, "CC0 111 resets bypass MDT"

/* x'01' is non-stream only; it must not be mistaken for CC0 mode 001. */
cc~setKeyboardState("UNLOCKED")
call assertTrue cm~consume("0411"x || "0100"x)~ok, "CC0 non-stream bit"
call assertEq cc~keyboardState, "UNLOCKED", "non-stream flag does not lock keyboard"
call assertTrue cc~snapshot~metadata["wtdNonStream"], "non-stream metadata true"

/* TD's length owns its bytes, including x'04'.  The following x'04' really is
 * the next command and must leave READ_MDT pending. */
tdseq = .PresentationSpace5250~new
ms = .DataStream5250Machine~new(tdseq, cp)
seq = "0411"x || "0000"x || "11"x || d2c(9) || d2c(1) ||,
      "10"x || "0003"x || "410442"x || "04520000"x
seqResult = ms~consumeSequence(seq)
call assertTrue seqResult~ok, "TD embedded ESC sequence"
call assertEq seqResult~value~commandName, "WRITE_TO_DISPLAY+READ_MDT", "TD x04 is not command boundary"
call assertEq tdseq~pendingReadKind, "READ_MDT", "command after TD consumed"

if failures > 0 then do
  say "FAIL test_5250_datastream" failures
  exit 1
end
say "PASS test_5250_datastream"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "DataStream5250.cls"
