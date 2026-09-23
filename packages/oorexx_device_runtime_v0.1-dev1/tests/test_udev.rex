provider=.LinuxUdevProvider~new
all=provider~enumerate
call assert all~items>0, 'udev enumeration returned devices'
net=provider~enumerate('net')
call assert net~items>=1, 'net subsystem enumeration'
do d over net
  call assert d~subsystem='net', 'subsystem filter preserved'
end
call assert provider~start('net'), 'udev monitor start'
e=provider~pollEvent(0)
/* No live event is required; the important contract is a nonblocking nil. */
call assert (e==.nil | e~isA(.DeviceEvent)), 'poll event contract'
provider~close
say 'DEVICE RUNTIME UDEV: OK devices='all~items 'net='net~items
exit 0

assert: procedure
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  return

::requires 'LinuxUdevProvider.cls'
