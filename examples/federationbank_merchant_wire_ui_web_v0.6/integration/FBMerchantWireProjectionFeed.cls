/*
 * FederationBank Merchant Banking Wire UI projection feed v0.6.
 *
 * This is a retained server-side read projection, not Merchant financial/risk/
 * settlement/accounting authority.  Production code may populate it only from
 * attributable authoritative projections.  The browser never writes this feed.
 */
::class FBMerchantWireProjectionFeed public
::method init
  expose rowsByRoot detailByRoot revision
  rowsByRoot=.directory~new; detailByRoot=.directory~new; revision=0

::method revision
  expose revision
  return revision

::method clear
  expose rowsByRoot detailByRoot revision
  rowsByRoot=.directory~new; detailByRoot=.directory~new; revision+=1
  return revision

::method putBook
  expose rowsByRoot detailByRoot revision
  use strict arg row,detail
  ignore=self~requireMap(row,"row")
  ignore=self~requireMap(detail,"detail")
  root=self~required(row,"rootTradeId")~string~upper
  if self~required(detail,"rootTradeId")~string~upper<>root then raise syntax 88.900 array("WIRE_DETAIL_ROOT_MISMATCH",root)
  if self~required(row,"schema")<>"federationbank.merchant.wire-book-row/1" then raise syntax 88.900 array("WIRE_ROW_SCHEMA_INVALID")
  if self~required(detail,"schema")<>"federationbank.merchant.wire-book-detail/1" then raise syntax 88.900 array("WIRE_DETAIL_SCHEMA_INVALID")
  rowsByRoot[root]=self~copyMap(row); detailByRoot[root]=self~copyMap(detail); revision+=1
  return root

::method row
  expose rowsByRoot
  use arg rootTradeId
  r=rowsByRoot[rootTradeId~string~upper]
  if r==.nil then return .nil
  return self~copyMap(r)

::method detail
  expose detailByRoot
  use arg rootTradeId
  d=detailByRoot[rootTradeId~string~upper]
  if d==.nil then return .nil
  return self~copyMap(d)

::method containsRootInScope
  use arg rootTradeId,filters=.nil
  r=self~row(rootTradeId); if r==.nil then return .false
  if filters==.nil then return .true
  return self~matches(r,filters)

::method rows
  expose rowsByRoot
  use arg filters=.nil,sortRef="ATTENTION",direction="DESC"
  if filters==.nil then filters=.table~new
  out=.array~new
  do root over rowsByRoot~allIndexes
    row=rowsByRoot[root]
    if self~matches(row,filters) then out~append(self~copyMap(row))
  end
  return self~sortRows(out,sortRef,direction)

::method window
  use arg filters=.nil,sortRef="ATTENTION",direction="DESC",offset=0,limit=50
  if \datatype(offset,"W") | offset<0 then raise syntax 88.900 array("WIRE_WINDOW_OFFSET_INVALID",offset)
  if \datatype(limit,"W") | limit<1 | limit>100 then raise syntax 88.900 array("WIRE_WINDOW_LIMIT_INVALID",limit)
  all=self~rows(filters,sortRef,direction)
  total=all~items
  out=.array~new
  if offset<total then do
    last=offset+limit
    if last>total then last=total
    do i=offset+1 to last
      out~append(all[i])
    end
  end
  d=.directory~new
  d["rows"]=out
  d["totalCount"]=total
  d["offset"]=offset
  d["limit"]=limit
  return d

::method summary
  use arg filters=.nil
  rows=self~rows(filters,"ROOT_TRADE_ID","ASC")
  d=.directory~new
  d["totalBooks"]=rows~items; d["riskAttention"]=0; d["executionDivergence"]=0; d["settlementOpen"]=0; d["accountingOpen"]=0; d["clientClosed"]=0
  do r over rows
    if r["riskState"]<>"NET_ZERO_WITH_MONITORING" & r["riskState"]<>"CLEAR" then d["riskAttention"]+=1
    if r["executionState"]="EXECUTION_DIVERGENCE" | r["executionState"]="DEVIATED" then d["executionDivergence"]+=1
    if r["settlementState"]<>"COMPLETE" & r["settlementState"]<>"SETTLED" & r["settlementState"]<>"NONE" then d["settlementOpen"]+=1
    if r["accountingState"]<>"COMPLETE" & r["accountingState"]<>"NONE" then d["accountingOpen"]+=1
    if r["clientState"]="CLOSED" then d["clientClosed"]+=1
  end
  return d

::method matches private
  use arg row,filters
  do key over filters~allIndexes
    wanted=filters[key]~string~strip~upper
    if wanted="" | wanted="ALL" | wanted="*" then iterate
    select
      when key~string~lower="risk_state" then actual=row["riskState"]
      when key~string~lower="settlement_state" then actual=row["settlementState"]
      when key~string~lower="accounting_state" then actual=row["accountingState"]
      when key~string~lower="client_state" then actual=row["clientState"]
      when key~string~lower="attention" then actual=row["attention"]
      otherwise return .false
    end
    if actual~string~upper<>wanted then return .false
  end
  return .true

::method sortRows private
  use arg rows,sortRef,direction
  sortRef=sortRef~string~upper; direction=direction~string~upper
  if direction<>"ASC" & direction<>"DESC" then direction="DESC"
  do i=2 to rows~items
    moving=rows[i]; j=i-1
    do while j>=1
      if \self~comesBefore(moving,rows[j],sortRef,direction) then leave
      rows[j+1]=rows[j]; j-=1
    end
    rows[j+1]=moving
  end
  return rows

::method comesBefore private
  use arg a,b,sortRef,direction
  select
    when sortRef="ROOT_TRADE_ID" then do; av=a["rootTradeId"]~string; bv=b["rootTradeId"]~string; end
    when sortRef="PORTFOLIO_ID" then do; av=a["portfolioId"]~string; bv=b["portfolioId"]~string; end
    when sortRef="RISK_STATE" then do; av=a["riskState"]~string; bv=b["riskState"]~string; end
    when sortRef="NET_EXPOSURE" then do; av=a["netBaseExposure"]+0; bv=b["netBaseExposure"]+0; end
    otherwise do; av=self~attentionRank(a["attention"]); bv=self~attentionRank(b["attention"]); end
  end
  if av=bv then return a["rootTradeId"]~string < b["rootTradeId"]~string
  if direction="ASC" then return av < bv
  return av > bv

::method attentionRank private
  use arg a
  select
    when a="URGENT" then return 5
    when a="ACTION_REQUIRED" then return 4
    when a="MONITOR" then return 3
    when a="WAITING_EXTERNAL" then return 2
    when a="CLEAR" then return 1
    otherwise return 0
  end

::method required private
  use arg source,key
  if \source~hasIndex(key) then raise syntax 88.900 array("WIRE_FIELD_REQUIRED",key)
  v=source[key]
  if v==.nil | v~string~strip="" then raise syntax 88.900 array("WIRE_FIELD_REQUIRED",key)
  return v

::method requireMap private
  use arg source,label
  if source==.nil | \source~hasMethod("HASINDEX") then raise syntax 88.900 array("WIRE_MAP_REQUIRED",label)
  return source

::method copyMap private
  use arg source
  d=.directory~new
  do k over source~allIndexes
    v=source[k]
    if v~isA(.Array) then do
      a=.array~new; do x over v; a~append(x); end; d[k]=a
    end
    else d[k]=v
  end
  return d
