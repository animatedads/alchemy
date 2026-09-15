/* FederationBank Staff Wire UI read model v0.1. */
::class FederationBankStaffWireReadModelBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.staff.wire.read-model/0.1"

::class FederationBankStaffWireReadModel public
::method init
  expose channelService
  use strict arg channelServiceArg
  if channelServiceArg==.nil then raise syntax 88.994 array("Staff Channel Service required")
  channelService=channelServiceArg

::method rows
  expose channelService
  use arg filters=.nil,sortRef="WORK_ID",direction="ASC"
  if filters==.nil then filters=.directory~new
  stateFilter="ALL"
  if filters~hasIndex("state") then stateFilter=filters["state"]~string~upper
  sortRef=sortRef~string~upper; direction=direction~string~upper
  works=channelService~state~works
  ids=.array~new
  do id over works
    w=works[id]
    if stateFilter<>"ALL" & stateFilter<>"*" & w~state<>stateFilter then iterate
    ids~append(id~string)
  end
  ids~sort
  out=.array~new
  if direction="DESC" then do i=ids~items to 1 by -1; out~append(self~rowFor(works[ids[i]])); end
  else do id over ids; out~append(self~rowFor(works[id])); end
  if sortRef="STATE" then out=self~sortRowsByState(out,direction)
  return out

::method containsWorkInScope
  expose channelService
  use arg workId,filters=.nil
  if filters==.nil then filters=.directory~new
  w=channelService~state~work(workId)
  if w==.nil then return .false
  if filters~hasIndex("state") then do
    f=filters["state"]~string~upper
    if f<>"ALL" & f<>"*" & w~state<>f then return .false
  end
  return .true

::method work
  expose channelService
  use arg workId
  return channelService~state~work(workId)

::method summary
  expose channelService
  use arg filters=.nil
  if filters==.nil then filters=.directory~new
  s=.directory~new
  do k over .array~of("TOTAL","RECEIVED","APPROVAL_REQUIRED","READY_FOR_CORE","COMPLETED","CORE_REJECTED","REJECTED","NO_BANK_ACTION"); s[k]=0; end
  rows=self~rows(filters)
  s["TOTAL"]=rows~items
  do r over rows
    st=r["state"]
    if s~hasIndex(st) then s[st]=s[st]+1
  end
  return s

::method rowFor
  use arg work
  r=.directory~new
  r["workId"]=work~workId
  r["originClass"]=work~originClass
  r["state"]=work~state
  r["outcomeCode"]=work~outcomeCode
  r["route"]=work~route
  r["ruleId"]=work~ruleId
  r["updatedAt"]=work~updatedAt~utcIsoDate
  r["revision"]=work~revision
  r["coreCode"]=work~coreCode
  req=work~request
  r["staffId"]=req~staffId
  r["branchId"]=req~branchId
  r["deskId"]=req~deskId
  r["sessionId"]=req~sessionId
  cmd=work~command
  if cmd==.nil then do
    r["customerId"]=""; r["operation"]="NONE"; r["currency"]=""; r["amountMinor"]=0; r["sourceAccountId"]=""; r["targetAccountId"]=""
  end
  else do
    r["customerId"]=cmd~customerId; r["operation"]=cmd~operation; r["currency"]=cmd~currency; r["amountMinor"]=cmd~amountMinor; r["sourceAccountId"]=cmd~sourceAccountId; r["targetAccountId"]=cmd~targetAccountId
  end
  if work~state="APPROVAL_REQUIRED" then r["checkerRequired"]=.true; else r["checkerRequired"]=.false
  return r

::method sortRowsByState private
  use arg rows,direction="ASC"
  keys=.array~new; by=.directory~new
  do r over rows
    key=r["state"]||"|"||r["workId"]
    keys~append(key); by[key]=r
  end
  keys~sort; out=.array~new
  if direction="DESC" then do i=keys~items to 1 by -1; out~append(by[keys[i]]); end
  else do k over keys; out~append(by[k]); end
  return out
