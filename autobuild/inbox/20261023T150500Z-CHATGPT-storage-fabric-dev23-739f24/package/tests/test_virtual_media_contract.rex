path='/tmp/storage-virtual-media-test.bin'
call stream path,'c','close'; call SysFileDelete path
call charout path,'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
call stream path,'c','close'

ref=.StorageRef~new('obj:dasd-image','sha256:disk')
source=.StorageLocalFileByteSource~new(path)
view=.StorageRandomAccessByteView~new(source,ref,8)
call assertEq '56789',view~readAt(5,5),'bounded random access view'

failed=.false
signal on syntax name TooLargeFailed
x=view~readAt(0,9)
signal off syntax
signal ContinueRange
TooLargeFailed:
  failed=.true
  signal off syntax
ContinueRange:
call assertTrue failed,'range bound enforced'

pin=.StoragePinnedRef~new(ref,'12')
d=.StorageVirtualMediaDescriptor~new('MVTRES','S370','DASD',pin,36,'3330-compatible',.StorageVirtualMediaState~LIVE)
call assertEq .StorageVirtualMediaState~LIVE,d~state,'media begins live'

hostSnap=.StorageVirtualMediaSnapshot~new('MVTRES','12',ref,.StorageVirtualMediaConsistency~HOST_BYTES_ATOMIC,'host-barrier')
call assertFalse .StorageVirtualMediaSnapshotPolicy~admissible(hostSnap,.true),'host byte atomicity is not guest consistency'
call assertTrue .StorageVirtualMediaSnapshotPolicy~admissible(hostSnap,.false),'host atomic accepted when guest consistency not required'

guestRef=.StorageRef~new('obj:dasd-snapshot','sha256:frozen')
guestSnap=.StorageVirtualMediaSnapshot~new('MVTRES','13',guestRef,.StorageVirtualMediaConsistency~GUEST_CONSISTENT,'s370:quiesce-13')
call assertTrue .StorageVirtualMediaSnapshotPolicy~admissible(guestSnap,.true),'guest-consistent frozen snapshot admitted'
call assertTrue guestSnap~publish,'publish frozen snapshot'
call assertEq .StorageVirtualMediaState~PUBLISHED,guestSnap~state,'snapshot published'
call assertTrue .StorageVirtualMediaSnapshotPolicy~admissible(guestSnap,.true),'published snapshot remains admissible'
call assertEq 'obj:dasd-snapshot',guestSnap~frozenRef~objectId,'publication has new StorageRef identity'

call stream path,'c','close'; call SysFileDelete path
say 'PASS generic virtual-media/random-access compatibility contract'
exit 0

::routine assertTrue
  use arg v,l
  if \v then do; say 'FAIL' l; raise syntax 88.900 array('test assertion failed'); end
::routine assertFalse
  use arg v,l
  if v then do; say 'FAIL' l; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say 'FAIL' l 'expected='e 'actual='a; raise syntax 88.900 array('test assertion failed'); end

::requires "src/StorageFabric.cls"
::requires "src/StorageBinding.cls"
::requires "src/StorageStreaming.cls"
::requires "src/StorageVirtualMedia.cls"
