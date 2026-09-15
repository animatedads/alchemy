/*
 * RIDWireReadModel.cls - firm-scoped retained Queue Fabric read model component v0.6, retained by RID package v0.7.
 *
 * This is deliberately a projection consumer, not product/case authority.  It
 * consumes retained RID.CASE.ATTENTION and RID.WORK.STATUS publications and
 * exposes only the authenticated intermediary firm's slice to Wire UI.
 */

::class RIDWireReadModelBuild public
::constant VERSION "0.6"
::constant API_VERSION "regulated.intermediary.wire-read/0.6"

::class RIDIntermediaryWireFeed public
::attribute attentionQueue get
::attribute workQueue get
::attribute firmId get
::attribute representativeId get
::method init
  expose queueManager topicFabric principal feedId firmId representativeId attentionQueue workQueue attentionByCase workById
  use arg queueManagerArg, topicFabricArg, feedIdArg, firmIdArg, representativeIdArg="*", principalArg="RID_ADMIN"
  queueManager=queueManagerArg; topicFabric=topicFabricArg; principal=principalArg~string
  feedId=.RIDCanonical~required("feedId",feedIdArg)~upper
  firmId=.RIDCanonical~required("firmId",firmIdArg)~upper
  representativeId=representativeIdArg~string~upper
  if representativeId="" then representativeId="*"
  attentionQueue="RID.UI."||feedId||".ATTENTION"
  workQueue="RID.UI."||feedId||".WORK"
  attentionByCase=.directory~new; workById=.directory~new

::method configure
  expose queueManager topicFabric principal feedId firmId attentionQueue workQueue
  domain="FEDERATION_INTERMEDIARY"
  do q over .array~of(attentionQueue,workQueue)
    if queueManager~queue(q)==.nil then do
      r=queueManager~createQueue(q,"PERMANENT",domain,0,principal,principal)
      if \r~ok then return .RIDResult~failure("WIRE_FEED_QUEUE_CONFIG_FAILED",q||":"||r~code)
    end
  end
  aSub="RID.UI."||feedId||".ATTENTION.SUB"
  if topicFabric~subscription(aSub)==.nil then do
    o=.table~new; o["deliverRetained"]=.true
    r=topicFabric~subscribe(aSub,"RID.CASE.ATTENTION",firmId||"/#",attentionQueue,"PERMANENT",principal,o)
    if \r~ok then return .RIDResult~failure("WIRE_FEED_SUBSCRIBE_FAILED",r~code||":"||r~detail)
  end
  wSub="RID.UI."||feedId||".WORK.SUB"
  if topicFabric~subscription(wSub)==.nil then do
    o=.table~new; o["deliverRetained"]=.true
    r=topicFabric~subscribe(wSub,"RID.WORK.STATUS",firmId||"/#",workQueue,"PERMANENT",principal,o)
    if \r~ok then return .RIDResult~failure("WIRE_FEED_SUBSCRIBE_FAILED",r~code||":"||r~detail)
  end
  return self~pump

::method pump
  expose attentionQueue workQueue
  a=self~pumpQueue(attentionQueue,"ATTENTION")
  if \a~ok then return a
  w=self~pumpQueue(workQueue,"WORK")
  if \w~ok then return w
  d=.directory~new; d["attention"]=a~value; d["work"]=w~value
  return .RIDResult~success(d,"WIRE_FEED_PUMPED")

::method pumpQueue private
  expose queueManager principal
  use arg queueName,kind
  count=0
  do forever
    dr=queueManager~depth(queueName,principal)
    if \dr~ok then return .RIDResult~failure("WIRE_FEED_DEPTH_FAILED",dr~code)
    if dr~value["ready"]<=0 then leave
    gr=queueManager~get(queueName,principal)
    if \gr~ok then return .RIDResult~failure("WIRE_FEED_GET_FAILED",gr~code)
    payload=gr~value~payload
    if kind="ATTENTION" then r=self~acceptAttention(payload)
    else r=self~acceptWork(payload)
    if \r~ok then return r
    count+=1
  end
  return .RIDResult~success(count)

::method acceptAttention private
  expose attentionByCase firmId representativeId
  use arg p
  if p==.nil | \p~hasMethod("HASINDEX") then return .RIDResult~failure("WIRE_ATTENTION_INVALID")
  if p["schema"]<>"regulated.intermediary.case-attention/1" then return .RIDResult~failure("WIRE_ATTENTION_SCHEMA_INVALID")
  if p["firm_id"]~string~upper<>firmId then return .RIDResult~success(.false,"WIRE_ATTENTION_OUT_OF_SCOPE")
  if representativeId<>"*" then if p["representative_id"]~string~upper<>representativeId then return .RIDResult~success(.false,"WIRE_ATTENTION_OUT_OF_SCOPE")
  attentionByCase[p["case_id"]~string~upper]=self~copyMap(p)
  return .RIDResult~success(.true)

::method acceptWork private
  expose workById firmId representativeId
  use arg p
  if p==.nil | \p~hasMethod("HASINDEX") then return .RIDResult~failure("WIRE_WORK_INVALID")
  if p["schema"]<>"regulated.intermediary.work-projection/1" then return .RIDResult~failure("WIRE_WORK_SCHEMA_INVALID")
  if p["firm_id"]~string~upper<>firmId then return .RIDResult~success(.false,"WIRE_WORK_OUT_OF_SCOPE")
  if representativeId<>"*" then if p["representative_id"]~string~upper<>representativeId then return .RIDResult~success(.false,"WIRE_WORK_OUT_OF_SCOPE")
  workById[p["work_item_id"]~string~upper]=self~copyMap(p)
  return .RIDResult~success(.true)

::method attention
  expose attentionByCase
  use arg caseId
  v=attentionByCase[.RIDCanonical~token(caseId)]
  if v==.nil then return .nil
  return self~copyMap(v)

::method work
  expose workById
  use arg workId
  v=workById[.RIDCanonical~token(workId)]
  if v==.nil then return .nil
  return self~copyMap(v)

::method activeWorkForCase
  expose workById
  use arg caseId
  wanted=.RIDCanonical~token(caseId); best=.nil
  do id over workById~allIndexes
    w=workById[id]
    if w["case_id"]<>wanted then iterate
    st=w["status"]~string~upper
    if st<>"OPEN" & st<>"OVERDUE" then iterate
    if best==.nil then best=w
    else if st="OVERDUE" & best["status"]<>"OVERDUE" then best=w
    else if st=best["status"] & (w["priority"]+0)>(best["priority"]+0) then best=w
    else if st=best["status"] & (w["priority"]+0)=(best["priority"]+0) & (w["source_provider_sequence"]+0)>(best["source_provider_sequence"]+0) then best=w
  end
  if best==.nil then return .nil
  return self~copyMap(best)

::method latestWorkForCase
  expose workById
  use arg caseId
  wanted=.RIDCanonical~token(caseId); best=.nil
  do id over workById~allIndexes
    w=workById[id]
    if w["case_id"]<>wanted then iterate
    if best==.nil then best=w
    else if (w["source_provider_sequence"]+0)>(best["source_provider_sequence"]+0) then best=w
    else if (w["source_provider_sequence"]+0)=(best["source_provider_sequence"]+0) & (w["priority"]+0)>(best["priority"]+0) then best=w
  end
  if best==.nil then return .nil
  return self~copyMap(best)

::method rows
  expose attentionByCase
  use arg filters=.nil, sortRef="PRIORITY", direction="DESC"
  if filters==.nil then filters=.table~new
  a=.array~new
  do caseId over attentionByCase~allIndexes
    row=attentionByCase[caseId]
    if \self~matches(row,filters) then iterate
    a~append(self~copyMap(row))
  end
  return self~sortRows(a,sortRef,direction)

::method summary
  use arg filters=.nil
  rows=self~rows(filters,"CASE_ID","ASC")
  d=.directory~new; d["TOTAL"]=rows~items; d["ACTION_REQUIRED"]=0; d["OVERDUE"]=0; d["WAITING_PROVIDER"]=0; d["COMPLETE"]=0
  do r over rows
    k=r["attention_state"]~string~upper
    if d~hasIndex(k) then d[k]=d[k]+1
  end
  return d

::method containsCaseInScope
  use arg caseId, filters=.nil
  r=self~attention(caseId)
  if r==.nil then return .false
  if filters==.nil then return .true
  return self~matches(r,filters)

::method matches private
  use arg row,filters
  do key over filters~allIndexes
    value=filters[key]~string~strip~upper
    if value="" | value="*" | value="ALL" then iterate
    select
      when key~string~lower="attention_state" then actual=row["attention_state"]
      when key~string~lower="product_family" then actual=row["product_family"]
      when key~string~lower="provider_status" then actual=row["provider_status"]
      when key~string~lower="waiting_on" then actual=row["waiting_on"]
      otherwise return .false
    end
    if actual~string~upper<>value then return .false
  end
  return .true

::method sortRows private
  use arg rows,sortRef,direction
  sortRef=sortRef~string~upper; direction=direction~string~upper
  if direction<>"ASC" & direction<>"DESC" then direction="DESC"
  do i=2 to rows~items
    moving=rows[i]; j=i-1
    do while j>=1 & self~comesBefore(moving,rows[j],sortRef,direction)
      rows[j+1]=rows[j]; j-=1
    end
    rows[j+1]=moving
  end
  return rows

::method comesBefore private
  use arg a,b,sortRef,direction
  select
    when sortRef="CASE_ID" then do; av=a["case_id"]~string; bv=b["case_id"]~string; end
    when sortRef="PROVIDER_STATUS" then do; av=a["provider_status"]~string; bv=b["provider_status"]~string; end
    when sortRef="PRODUCT_FAMILY" then do; av=a["product_family"]~string; bv=b["product_family"]~string; end
    when sortRef="ATTENTION" then do; av=self~attentionRank(a["attention_state"]); bv=self~attentionRank(b["attention_state"]); end
    otherwise do; av=a["priority"]+0; bv=b["priority"]+0; end
  end
  if av=bv then return a["case_id"]~string < b["case_id"]~string
  if direction="ASC" then return av < bv
  return av > bv

::method attentionRank private
  use arg state
  select
    when state="OVERDUE" then return 4
    when state="ACTION_REQUIRED" then return 3
    when state="WAITING_PROVIDER" then return 2
    when state="COMPLETE" then return 1
    otherwise return 0
  end

::method copyMap private
  use arg source
  d=.directory~new
  do k over source~allIndexes
    v=source[k]
    if v~isA(.Array) then do; a=.array~new; do x over v; a~append(x); end; d[k]=a; end
    else d[k]=v
  end
  return d

::requires "RegulatedIntermediaryDistribution.cls"
