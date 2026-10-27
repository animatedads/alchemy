#!/usr/bin/env rexx
say 'INSTRUMENTATION RELATIONSHIP ADAPTERS TEST START'

/* Queue Channel Fabric owns these configured traffic relationships. */
qm=.ObjectQueueManager~new
ignored=qm~createQueue('XMIT','TEMPORARY','MANAGEMENT',0,'queue-admin')
channels=.QueueChannelFabric~new('QM-A',qm,.QueueInProcessTransport~new,'queue-admin')
channelReply=channels~defineSenderChannel('A-TO-B','XMIT','QM-B','','','',0,'TEMPORARY','queue-admin')
call assertTrue channelReply~ok,'sender channel configured'
channelReply=channels~defineReceiverChannel('B-TO-A','QM-B','','TEMPORARY','queue-admin')
call assertTrue channelReply~ok,'receiver channel configured'
queueSource=.QueueChannelRelationshipSource~new('queue-manager://QM-A',channels)
queueSet=queueSource~relationshipSet('2026-10-10T08:35:00Z')
call assertEq queueSet['relationships']~items,2,'queue channel relationship count'
call assertEq queueSet['authority'],'QUEUE_FABRIC','queue scope authority'
call assertEq queueSet['relationships'][1]['kind'],'QUEUE_TRAFFIC_TO','queue sender direction'

/* IdentityPeerEpochAuthority owns the currently fenced holder.  It does not
 * imply that Instrumentation selected the promotion. */
epoch=.IdentityPeerEpochAuthority~new
epochReply=epoch~activate('peer-a',1,1,'node-a')
call assertTrue epochReply~ok,'identity epoch activated'
identitySource=.IdentityPeerAuthorityRelationshipSource~new(epoch,.array~of('peer-a'))
identitySet=identitySource~relationshipSet('2026-10-10T08:35:01Z')
call assertEq identitySet['relationships']~items,1,'identity holder relationship'
edge=identitySet['relationships'][1]
call assertEq edge['kind'],'AUTHORITY_HELD_BY','identity holder kind'
call assertEq edge['to_ref'],'runtime://node-a','current holder projected'
epochReply=epoch~promote('peer-a',2,1,'node-b')
call assertTrue epochReply~ok,'identity holder promoted by authority'
identitySet2=identitySource~relationshipSet('2026-10-10T08:35:02Z')
call assertEq identitySet2['relationships'][1]['to_ref'],'runtime://node-b','replacement holder projected'
call assertEq identitySet2['relationships'][1]['dimensions']['epoch'],2,'promoted epoch retained'

/* Management relationship meaning remains opaque.  The resolver is mandatory
 * because original domain objects are not silently converted to display text. */
left=.SemanticFixture~new('service://left')
right=.SemanticFixture~new('service://right')
provider=.RelationshipProviderFixture~new(.ManagementRelationship~new('dep-1','DEPENDS_ON',left,right,'SERVICE_CATALOGUE'))
resolver=.SemanticResolverFixture~new
managementSource=.ManagementRelationshipInstrumentationSource~new('service-catalogue',provider,resolver)
managementSet=managementSource~relationshipSet('2026-10-10T08:35:03Z')
call assertEq managementSet['relationships']~items,1,'management relationship bridged'
managed=managementSet['relationships'][1]
call assertEq managed['from_ref'],'service://left','from endpoint resolved explicitly'
call assertEq managed['to_ref'],'service://right','to endpoint resolved explicitly'
call assertEq managed['authority'],'SERVICE_CATALOGUE','domain authority preserved'

say 'PASS Queue, identity-holder and Management relationship adapters'
exit 0

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

::class SemanticFixture
::method init
  expose ref
  use strict arg refArg
  ref=refArg
::attribute ref get

::class SemanticResolverFixture
::method semanticRef
  use strict arg object
  return object~ref

::class RelationshipProviderFixture
::method init
  expose relationship
  use strict arg relationshipArg
  relationship=relationshipArg
::method discoverRelationships
  expose relationship
  use strict arg context=.nil
  return .array~of(relationship)

::requires 'InstrumentationMesh.cls'
::requires 'InstrumentationRelationshipAdapters.cls'
::requires 'ObjectQueueFabric.cls'
::requires 'ObjectQueueChannels.cls'
::requires 'IdentityPeerFabric.cls'
::requires 'ManagementRelationships.cls'
