#!/usr/bin/env rexx
say 'INSTRUMENTATION SOURCE SHAPE TEST START'

/* Current RexxOS Grid dev14 publishes one controller plus a dynamic set of MU
 * snapshots through a plural snapshots() source. */
grid=.FakeGridController~new
estateSource=.RexxOSGridEstateInstrumentation~new(grid)

/* HTTPS v0.4.7 exposes instrumentationSnapshot() on the service object rather
 * than a source wrapper. Model that public source shape directly. */
httpsIdentity=.InstrumentationCodec~identity('alchemy','https','https-a','ed209a','','HTTPS')
httpsEmitter=.InstrumentationEmitter~new(httpsIdentity)
httpsEmitter~setHealth(.InstrumentationHealth~HEALTHY)
https=.FakeHttpsLikeService~new(httpsEmitter)

registry=.InstrumentationRegistry~new
registry~register('rexxos-estate',estateSource)
registry~register('https-service',https)
snapshots=registry~snapshots('2026-10-09T20:05:00Z')
call assertEq snapshots~items,4,'estate controller + two MUs + HTTPS snapshot'
call assertEq countKind(snapshots,'GRID_CONTROLLER'),1,'grid controller snapshot'
call assertEq countKind(snapshots,'MANAGEMENT_UNIT'),2,'management unit snapshots'
call assertEq countKind(snapshots,'HTTPS'),1,'HTTPS service snapshot'

service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(8)
transport=.InstrumentationLocalCollectorTransport~new(.InstrumentationCollectorService~new(collector),'ed209a')
publisher=.InstrumentationPublisher~new('estate-publisher',service,transport,'noc')
publishResult=publisher~publish('2026-10-09T20:05:01Z')
call assertTrue publishResult~ok,'mixed source shapes publish atomically'
call assertEq publishResult~receipt['accepted'],4,'collector accepted all mixed-source snapshots'

say 'PASS single/plural/service-owned snapshot source protocol'
exit 0

countKind: procedure
  use arg snapshots,kind
  n=0
  do s over snapshots
    if s['identity']['service_kind']=kind then n+=1
  end
  return n

assertTrue: procedure
  use arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1

assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::class FakeHttpsLikeService public
::method init
  expose emitter
  use strict arg emitterArg
  emitter=emitterArg
::method instrumentationSnapshot
  expose emitter
  use strict arg observedAt=''
  return emitter~snapshot(observedAt)

::class FakeMuController public
::method init
  expose muId
  use strict arg muIdArg
  muId=muIdArg
::method identity
  expose muId
  d=.directory~new; d['grid_id']='alchemy-grid'; d['mu_id']=muId; return d
::method estateRecord
  d=.directory~new; d['node_count']=2; d['membership_state']='REGISTERED'; return d

::class FakeGridController public
::method init
  expose mus
  mus=.directory~new
  mus['MU-A']=.FakeMuController~new('MU-A')
  mus['MU-B']=.FakeMuController~new('MU-B')
::method capabilities
  d=.directory~new; d['grid_id']='alchemy-grid'; return d
::method estateSnapshot
  d=.directory~new
  d['management_unit_count']=2; d['mesh_instance_count']=4
  m=.directory~new; m['estate_minimum_satisfied']=.true; d['minimum']=m
  return d
::method listManagementUnits
  expose mus
  return mus~allIndexes~sort
::method managementUnit
  expose mus
  use strict arg muId
  return mus[muId]

::requires 'src/InstrumentationMesh.cls'
::requires 'RexxOSGridInstrumentation.cls'
