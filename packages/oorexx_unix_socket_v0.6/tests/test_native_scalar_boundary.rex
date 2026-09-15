/* Unix Socket v0.6 forcing test: libc implementation-width scalars must be
   represented by Foreign Runtime's ABI-native C aliases, while struct layout
   remains guarded by the qualified ABI profile. */
bridge=value('OOREXX_UNIX_SOCKET_BRIDGE',,'ENVIRONMENT')
if bridge=='' then do
  say 'FAIL OOREXX_UNIX_SOCKET_BRIDGE is required for native scalar forcing test'
  exit 1
end
lib=.foreign~load(bridge)

caps=.foreign~capabilities
native=.false
do c over caps
  if c='abi-native-c-scalars' then native=.true
end
call ok native, 'Foreign Runtime advertises abi-native-c-scalars'

sizeT=.foreign~datatype('size_t')
ssizeT=.foreign~datatype('ssize_t')
sockT=.foreign~datatype('socklen_t')
ulongT=.foreign~datatype('unsigned long')
shortT=.foreign~datatype('short')
call ok sizeT~size=8 & sizeT~alignment=8 & \sizeT~signed, 'size_t resolves as LP64 unsigned 64-bit scalar'
call ok ssizeT~size=8 & ssizeT~alignment=8 & ssizeT~signed, 'ssize_t resolves as LP64 signed 64-bit scalar'
call ok sockT~size=4 & sockT~alignment=4 & \sockT~signed, 'socklen_t resolves as unsigned 32-bit scalar'
call ok ulongT~size=8 & ulongT~alignment=8 & \ulongT~signed, 'unsigned long resolves as LP64 unsigned 64-bit scalar'
call ok shortT~size=2 & shortT~alignment=2 & shortT~signed, 'short resolves as signed 16-bit scalar'

send=lib~method('posix_send')~signatures[1]
recv=lib~method('posix_recv')~signatures[1]
sendto=lib~method('posix_sendto')~signatures[1]
bind=lib~method('posix_bind')~signatures[1]
connect=lib~method('posix_connect')~signatures[1]
setopt=lib~method('posix_setsockopt')~signatures[1]
poll=lib~method('posix_poll')~signatures[1]
call ok send~returnTypeName='ssize_t' & send~inputs[3]~typeName='size_t', 'send uses ssize_t(size_t) native scalar boundary'
call ok recv~returnTypeName='ssize_t' & recv~inputs[3]~typeName='size_t', 'recv uses ssize_t(size_t) native scalar boundary'
call ok sendto~returnTypeName='ssize_t' & sendto~inputs[3]~typeName='size_t' & sendto~inputs[6]~typeName='socklen_t', 'sendto uses size_t/socklen_t native scalars'
call ok bind~inputs[3]~typeName='socklen_t' & connect~inputs[3]~typeName='socklen_t', 'bind/connect use socklen_t'
call ok setopt~inputs[5]~typeName='socklen_t', 'setsockopt uses socklen_t'
call ok poll~inputs[2]~typeName='unsigned long', 'poll nfds_t carrier uses ABI-native unsigned long on qualified Linux profile'

iov=lib~struct('iovec'); fields=iov~fields
call fieldType fields,'iov_len','size_t'
iov~close
msg=lib~struct('msghdr'); fields=msg~fields
call fieldType fields,'msg_namelen','socklen_t'
call fieldType fields,'msg_iovlen','size_t'
call fieldType fields,'msg_controllen','size_t'
msg~close
cmsg=lib~struct('cmsghdr'); call fieldType cmsg~fields,'cmsg_len','size_t'; cmsg~close
pfd=lib~struct('pollfd'); call fieldType pfd~fields,'events','short'; call fieldType pfd~fields,'revents','short'; pfd~close

lib~close
say 'PASS Unix Socket ABI-native C scalar binding 18 assertions'
exit 0

fieldType: procedure
  use arg fields,name,expected
  do i=1 to fields~items
    if fields[i][1]=name then do
      call ok fields[i][2]=expected, name 'uses' expected
      return
    end
  end
  say 'FAIL missing struct field' name
  exit 1

ok: procedure
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires 'foreign.cls'
