#!/usr/bin/env rexx
say 'INSTRUMENTATION RTO RELATIONSHIP ADAPTER TEST START'

estate=.RexxOSGridEstateController~new('REXXOS-GRID-REL',2,4)
call addManagementUnit estate,'MU1','MI1-1','MI1-2'
call addManagementUnit estate,'MU2','MI2-1','MI2-2'

source=.RexxOSGridRelationshipSource~new(estate)
set1=source~relationshipSet('2026-10-10T08:30:00Z')
call assertTrue set1['complete'],'RTO membership scope complete'
call assertEq set1['authority'],'REXXOS_GRID','RTO authority retained'
call assertEq set1['relationships']~items,6,'2 MU + 4 MI edges'
call assertEq countKind(set1,'HAS_MANAGEMENT_UNIT'),2,'MU membership edges'
call assertEq countKind(set1,'HAS_MESH_INSTANCE'),4,'MI membership edges'
call assertEq countKind(set1,'ACTIVE'),0,'adapter does not invent ACTIVE/SPARE role'

/* Complete-scope update follows Grid membership exactly. */
removed=estate~deregisterManagementUnit('MU2','TEST_WITHDRAWAL')
call assertEq removed['state'],'DEREGISTERED','MU withdrawal'
set2=source~relationshipSet('2026-10-10T08:31:00Z')
call assertEq set2['relationships']~items,3,'withdrawn MU subtree absent from current complete scope'
call assertEq countKind(set2,'HAS_MANAGEMENT_UNIT'),1,'one current MU edge'
call assertEq countKind(set2,'HAS_MESH_INSTANCE'),2,'two current MI edges'

say 'PASS RTO2 current membership projects as authority-labelled complete relationship scope'
exit 0

addManagementUnit: procedure
  use arg estate,muId,firstNodeId,secondNodeId
  muProfile=.RexxOSManagementUnitProfile~new('REXXOS-GRID-REL',muId,'mu-inc-'||muId)
  mu=.RexxOSManagementUnitController~new(muProfile)
  registration=estate~registerManagementUnit(mu,'GRID.MU.'||muId)
  call assertEq registration['state'],'REGISTERED','MU registration'
  node=.RexxOSMeshNodeProfile~new('REXXOS-GRID-REL',firstNodeId,muId,'mi-inc-'||firstNodeId)
  registrationReply=mu~registerNode(node,'GRID.MN.'||firstNodeId)
  call assertEq registrationReply['state'],'REGISTERED','MI registration'
  node=.RexxOSMeshNodeProfile~new('REXXOS-GRID-REL',secondNodeId,muId,'mi-inc-'||secondNodeId)
  registrationReply=mu~registerNode(node,'GRID.MN.'||secondNodeId)
  call assertEq registrationReply['state'],'REGISTERED','MI registration'
return

countKind: procedure
  use arg relationshipSet,kind
  n=0
  do relationship over relationshipSet['relationships']
    if relationship['kind']=kind then n+=1
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

::requires 'InstrumentationMesh.cls'
::requires 'InstrumentationRelationshipAdapters.cls'
::requires 'RexxOSGridEstateController.cls'
::requires 'RexxOSManagementUnitController.cls'
::requires 'RexxOSManagementUnitProfile.cls'
::requires 'RexxOSMeshNodeProfile.cls'
