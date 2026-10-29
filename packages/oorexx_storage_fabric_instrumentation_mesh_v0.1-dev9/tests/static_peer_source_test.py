from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'src'/'StorageRepairPeerSource.cls').read_text()
planner=(root/'src'/'StorageRepairPlanner.cls').read_text()
required=[
 '::class StoragePeerRepairSourceResolver public',
 '::class StorageRepairPeerSelector public',
 '::class StorageRepairStagingPathAllocator public',
 'materialiser~materialise(client,peer,object~ref,target)',
 'result~code<>"VERIFIED"',
 'StoragePeerCodec~normaliseSha256',
 'StorageRepairSourceResult~success(target,"sha256:"||actual,.true)',
 'if \\temporary then return .true',
 'cleanupOk=source~cleanup',
]
missing=[x for x in required if x not in s+planner]
if missing: raise SystemExit('FAIL peer-source markers missing: '+repr(missing))
forbidden=['62801','0x817D','protocol 36','SocketProvider','XtpSocket','JobToNode','~addLocation(']
found=[x for x in forbidden if x in s]
if found: raise SystemExit('FAIL peer source acquired forbidden transport/admission authority: '+repr(found))
print('PASS verified StoragePeer repair-source boundary')
