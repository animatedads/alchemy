ref=.StorageRef~new('audio:layered:source:001','sha256:deadbeef')
obj=.StorageObject~new(ref,'layered-audio-source',1000000,'audio/wav')

/* Primary centre: processing may occur on mi-01ed209c / mu-ed209c. */
c=.StorageLocation~new('MU-A','/fabric/audio/source001','mu-ed209c-cap','AVAILABLE','',.true,'verify:c','SAFE','STABLE','mu-ed209c','VENDOR-A','CENTRE-C','VENDOR-A/CENTRE-C')
/* Independent centre: this copy may simultaneously serve mi-06ed209e work. */
e=.StorageLocation~new('MU-B','/fabric/audio/source001','mu-ed209e-cap','AVAILABLE','',.true,'verify:e','SAFE','STABLE','mu-ed209e','VENDOR-B','CENTRE-E','VENDOR-B/CENTRE-E')
obj~addLocation(c); obj~addLocation(e)

policy=.StorageReplicaPolicy~new
req=.StorageReplicaRequirement~new(2,2,2,2)
a=policy~assess(obj,req)
call assertTrue a~satisfied,'two-centre/two-vendor source must satisfy policy'
call assertEq 2,a~durableReplicas,'replica count'
call assertEq 2,a~vendors,'vendor diversity'
call assertEq 2,a~sites,'site diversity'

/* A second copy in the same physical/vendor centre must NOT satisfy it. */
same=.StorageObject~new(ref,'bad-layout',1000000,'audio/wav')
same~addLocation(c)
c2=.StorageLocation~new('MU-A2','/fabric2/audio/source001','other-cap','AVAILABLE','',.true,'verify:c2','SAFE','STABLE','mu-ed209c-2','VENDOR-A','CENTRE-C','VENDOR-A/CENTRE-C')
same~addLocation(c2)
b=policy~assess(same,req)
call assertFalse b~satisfied,'same centre copies must not count as independent'
call assertEq 'INSUFFICIENT_VENDOR_DIVERSITY',b~reason,'vendor diversity should fail first'

/* If mu-ed209c dies, CENTRE-E remains an independently verified source from
 * which mi-04ed209d may materialise the exact StorageRef. Policy is degraded
 * until a replacement second centre is rebuilt; source identity is unchanged. */
cDown=.StorageLocation~new('MU-A','/fabric/audio/source001','mu-ed209c-cap','OFFLINE','',.true,'verify:c','SAFE','STABLE','mu-ed209c','VENDOR-A','CENTRE-C','VENDOR-A/CENTRE-C')
obj~addLocation(cDown)
degraded=policy~assess(obj,req)
call assertFalse degraded~satisfied,'loss of one centre must mark redundancy degraded'
call assertEq 1,degraded~durableReplicas,'one surviving durable copy'
call assertTrue e~countsAsDurable,'surviving centre remains source-capable'


/* Failure-domain evidence is catalogue state and must survive restart. */
cat=.StorageCatalogue~new; cat~put(obj)
tmp=SysTempFileName('/tmp/storage-failure-domain-??????')
cat~save(tmp)
cat2=.StorageCatalogue~new; cat2~load(tmp); call SysFileDelete tmp
loaded=cat2~get(ref~objectId)
call assertTrue loaded<>.nil,'catalogue reload object'
foundE=.false
do l over loaded~locations
  if l~providerId='MU-B' then do
    call assertEq 'VENDOR-B',l~vendorId,'persist vendor'
    call assertEq 'CENTRE-E',l~siteId,'persist site'
    call assertEq 'VENDOR-B/CENTRE-E',l~failureDomainId,'persist failure domain'
    foundE=.true
  end
end
call assertTrue foundE,'catalogue reload independent location'

say 'PASS Storage two-centre/two-vendor failure-domain replication policy'
exit 0

::routine assertTrue
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertFalse
  use arg value,label
  if value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end
::requires 'src/StorageFabric.cls'
