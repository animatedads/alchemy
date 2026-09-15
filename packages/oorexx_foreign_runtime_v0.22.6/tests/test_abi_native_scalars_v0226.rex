/* v0.22.6 ABI-derived native C scalar aliases. */
lib=.foreign~load('../examples/test.bridge.json')
ri=.foreign~runtimeInfo
call ok ri~abiProfile='linux-x86_64-le-lp64', 'qualification runtime profile is Linux x86-64 LP64'

longT=.foreign~datatype('long')
ulongT=.foreign~datatype('unsigned long')
sizeT=.foreign~datatype('size_t')
ssizeT=.foreign~datatype('ssize_t')
diffT=.foreign~datatype('ptrdiff_t')
sockT=.foreign~datatype('socklen_t')

call ok longT~size=8 & longT~carrier='i64' & longT~signed, 'LP64 long resolves to signed i64'
call ok ulongT~size=8 & ulongT~carrier='u64' & \ulongT~signed, 'LP64 unsigned long resolves to u64'
call ok sizeT~size=8 & sizeT~carrier='u64' & \sizeT~signed, 'LP64 size_t resolves to u64'
call ok ssizeT~size=8 & ssizeT~carrier='i64' & ssizeT~signed, 'LP64 ssize_t resolves to i64'
call ok diffT~size=8 & diffT~carrier='i64' & diffT~signed, 'LP64 ptrdiff_t resolves to i64'
call ok sockT~size=4 & sockT~carrier='u32' & \sockT~signed, 'Linux x86-64 socklen_t resolves to u32'

big=4294967297
call ok lib~echo_c_long(big)=big, 'C long scalar preserves value beyond 32-bit'
call ok lib~echo_c_ulong(big)=big, 'C unsigned long scalar preserves value beyond 32-bit'
call ok lib~echo_c_size_t(big)=big, 'C size_t scalar preserves value beyond 32-bit'
call ok lib~echo_c_ptrdiff_t('-4294967297')='-4294967297', 'C ptrdiff_t scalar preserves signed 64-bit value'
call ok lib~echo_c_ssize_t('-4294967297')='-4294967297', 'POSIX ssize_t scalar preserves signed 64-bit value'
call ok lib~echo_c_socklen_t(65535)=65535, 'socklen_t scalar uses native width'

st=lib~struct('foreign_native_scalars')
st~set('signed_long','-4294967297')
st~set('unsigned_long','4294967297')
st~set('size_value','4294967298')
st~set('diff_value','-1234567890123')
st~set('ssize_value','-4294967299')
st~set('socklen_value',4096)
call ok st~get('signed_long')='-4294967297', 'ForeignStruct long field uses ABI-derived width'
call ok st~get('unsigned_long')='4294967297', 'ForeignStruct unsigned long field uses ABI-derived width'
call ok st~get('size_value')='4294967298', 'ForeignStruct size_t field uses ABI-derived width'
call ok st~get('diff_value')='-1234567890123', 'ForeignStruct ptrdiff_t field uses ABI-derived width'
call ok st~get('ssize_value')='-4294967299', 'ForeignStruct ssize_t field uses ABI-derived width'
call ok st~get('socklen_value')=4096, 'ForeignStruct socklen_t field uses ABI-derived width'
call ok lib~native_scalars_long(st)='-4294967297', 'native C reads ABI-derived long struct field'
call ok lib~native_scalars_size(st)='4294967298', 'native C reads ABI-derived size_t struct field'
call ok lib~native_scalars_ssize(st)='-4294967299', 'native C reads ABI-derived ssize_t struct field'
call ok lib~native_scalars_socklen(st)=4096, 'native C reads ABI-derived socklen_t struct field'

caps=.foreign~capabilities
found=0
do c over caps
  if c='abi-native-c-scalars' then found=1
end
call ok found, 'runtime advertises ABI-native C scalar capability'

st~close; lib~close
say 'PASS ABI-native C scalar aliases 23 assertions'
exit 0

ok: procedure
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires '../rexx/foreign.cls'
