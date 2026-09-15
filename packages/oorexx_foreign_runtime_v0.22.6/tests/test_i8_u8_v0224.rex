/* v0.22.4 true 8-bit scalar and struct-field support. */
lib=.foreign~load('../examples/test.bridge.json')

dti=.foreign~datatype('i8')
dtu=.foreign~datatype('u8')
call ok dti~size=1 & dti~signed, 'i8 datatype is signed one byte'
call ok dtu~size=1 & \dtu~signed, 'u8 datatype is unsigned one byte'
call ok dti~carrier='i8' & dtu~carrier='u8', 'i8/u8 carriers preserved'

call ok lib~echo_i8(-128)=-128, 'i8 scalar minimum round trip'
call ok lib~echo_i8(127)=127, 'i8 scalar maximum round trip'
call ok lib~echo_u8(0)=0, 'u8 scalar minimum round trip'
call ok lib~echo_u8(255)=255, 'u8 scalar maximum round trip'
call ok lib~add_i8_u8(-5,250)=245, 'mixed i8/u8 scalar arguments use exact ABI widths'

st=lib~struct('foreign_byte_fields')
st~set('signed_byte',-7)
st~set('unsigned_byte',249)
call ok st~get('signed_byte')=-7, 'ForeignStruct i8 field read/write'
call ok st~get('unsigned_byte')=249, 'ForeignStruct u8 field read/write'
call ok lib~byte_fields_sum(st)=242, 'native C reads i8/u8 ForeignStruct layout'
lib~byte_fields_fill(st,-128,255)
call ok st~get('signed_byte')=-128 & st~get('unsigned_byte')=255, 'native C writes i8/u8 ForeignStruct layout'

sa=lib~structArray('foreign_byte_fields',2)
sa~set(1,'signed_byte',-1); sa~set(1,'unsigned_byte',255)
sa~set(2,'signed_byte',127); sa~set(2,'unsigned_byte',0)
call ok sa~get(1,'signed_byte')=-1 & sa~get(1,'unsigned_byte')=255, 'ForeignStructArray i8/u8 first element'
call ok sa~get(2,'signed_byte')=127 & sa~get(2,'unsigned_byte')=0, 'ForeignStructArray i8/u8 second element'

/* Fail closed instead of integer wrapping. */
rangeRejected=0
signal on syntax name badI8
ignored=lib~echo_i8(128)
signal off syntax
call ok 0, 'i8 +128 must be rejected'
signal badI8Done
badI8:
  signal off syntax
  rangeRejected+=1
  call ok 1, 'i8 +128 rejected'
badI8Done:
signal on syntax name badU8High
ignored=lib~echo_u8(256)
signal off syntax
call ok 0, 'u8 256 must be rejected'
signal badU8HighDone
badU8High:
  signal off syntax
  rangeRejected+=1
  call ok 1, 'u8 256 rejected'
badU8HighDone:
signal on syntax name badU8Neg
st~set('unsigned_byte',-1)
signal off syntax
call ok 0, 'u8 struct field -1 must be rejected'
signal badU8NegDone
badU8Neg:
  signal off syntax
  rangeRejected+=1
  call ok 1, 'u8 struct field -1 rejected'
badU8NegDone:
call ok rangeRejected=3, 'all i8/u8 range failures observed'

sa~close; st~close; lib~close
say 'PASS i8/u8 scalar and struct-field support 18 assertions'
exit 0

ok: procedure
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires '../rexx/foreign.cls'
