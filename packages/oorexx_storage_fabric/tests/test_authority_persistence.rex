base='/tmp/storage-authority-dev21'
address system '/bin/rm -rf '||base
call SysMkDir base

cat=.StorageCatalogue~new
ref=.StorageRef~new('sha256:authority-object','sha256:001122')
obj=.StorageObject~new(ref,'authority.bin',256,'application/octet-stream')
loc=.StorageLocation~new('git-azure','refs/storage/authority-object','git:azure','AVAILABLE','',.true,'gitcommit:abc','SAFE','STABLE','azure-node','AZURE','UK-SOUTH','AZURE/UK-SOUTH')
obj~addLocation(loc); cat~put(obj)

snap=.StorageAuthoritySnapshot~new(0,cat)
live=.StorageEnvironment~new('LIVE','LIVE','',100,107,'VERSIONED')
test=.StorageEnvironment~new('TEST','TEST','LIVE',107,12,'COPY_ON_WRITE')
snap~addEnvironment(live); snap~addEnvironment(test)
nsLive=.StorageNamespace~new('ns-live',cat,live)
nsLive~bind('/media/authority.bin',ref,'VERSIONED')
nsLive~addAlias('/current/audio','/media/authority.bin','READ_ONLY')
f=.StorageFilter~new; f~add(.StorageFilterClause~new('mediaType','application/octet-stream','EQ'))
nsLive~addQueryFolder(.StorageQueryFolder~new('/by-type/binary',f,'READ_ONLY'))
snap~addNamespace(nsLive)
nsTest=.StorageNamespace~new('ns-test',cat,test,nsLive); snap~addNamespace(nsTest)

provider=.StorageAuthorityProviderRecord~new('git-azure','GIT','ELASTIC','AZURE','UK-SOUTH','AZURE/UK-SOUTH','SAFE','STABLE')
snap~addProvider(provider)
snap~replicaPolicies~put(ref~objectId,.StorageReplicaRequirement~new(2,2,2,2))

store=.StorageAuthorityStore~new(base)
r=store~save(snap)
call eq 1,r,'first revision'
call eq 1,snap~revision,'snapshot revision advances'

loaded=store~load
call ok loaded<>.nil,'load authority checkpoint'
call eq 1,loaded~revision,'loaded revision'
call eq 1,loaded~catalogue~count,'catalogue survives'
ll=loaded~catalogue~get(ref~objectId)
call ok ll<>.nil,'object survives'
call eq 'AZURE/UK-SOUTH',ll~locations[1]~failureDomainId,'location failure domain survives'
p2=loaded~provider('git-azure')
call eq 'ELASTIC',p2~capacityModel,'elastic provider capacity survives'
call eq 'UK-SOUTH',p2~siteId,'provider site survives'
req=loaded~replicaPolicies~get(ref~objectId)
call eq 2,req~requiredReplicas,'replica count policy survives'
call eq 2,req~distinctSites,'site diversity policy survives'
n2=loaded~namespace('ns-live')
call ok n2<>.nil,'namespace survives'
res=n2~resolve('/media/authority.bin')
call ok res~found,'binding survives'
call eq ref~objectId,res~entry~ref~objectId,'binding StorageRef survives'
al=n2~resolve('/current/audio')
call ok al~found,'alias survives'
q=n2~resolve('/by-type/binary/authority.bin')
call ok q~found,'query folder/filter survives'
child=loaded~namespace('ns-test')
call ok child<>.nil & child~parent<>.nil,'namespace parent survives'
call eq 'ns-live',child~parent~namespaceId,'namespace parent identity'

/* A second save goes to the alternate slot and CURRENT publishes it only
 * after both authority and catalogue files are complete. */
r=store~save(loaded)
call eq 2,r,'second revision'
again=store~load
call eq 2,again~revision,'alternate slot current revision'

say 'PASS surface-neutral Storage authority restart persistence'
exit 0

::routine ok
  use arg v,label
  if \v then do; say 'FAIL' label; raise syntax 88.900 array('assertion failed'); end
::routine eq
  use arg e,a,label
  if e<>a then do; say 'FAIL' label 'expected='e 'actual='a; raise syntax 88.900 array('assertion failed'); end
::requires 'src/StorageAuthority.cls'
