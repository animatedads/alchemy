/* Read-only multi-MU catalogue view.  This is a composition of authenticated
 * StoragePeerClient calls; it is NOT an independent transport or authority.
 * The resident controller must pass only policy-authorised peer IDs.
 */
/* Storage byte counts, offsets and capacity values routinely exceed the ooRexx
 * default 9-digit arithmetic context (a 2,005,735,208-byte object already does).
 * Keep them exact in every Storage package.  (precision1, from dev22 backup-floor
 * line; Claude (Opus 5.5).) */
::options digits 30

::class StorageMeshCatalogueSearch public
::method init
  expose client nodes
  use strict arg clientArg, nodesArg
  if clientArg==.nil | nodesArg==.nil then raise syntax 88.900 array('client and approved peer nodes required')
  if \nodesArg~isA(.Array) | nodesArg~items<1 | nodesArg~items>64 then -
    raise syntax 88.900 array('approved peer list must contain 1..64 nodes')
  client=clientArg
  nodes=.array~new
  seen=.directory~new
  do v over nodesArg
    n=v~string~strip
    if n=='' | seen~hasIndex(n) then raise syntax 88.900 array('blank or duplicate catalogue peer')
    seen[n]=.true
    nodes~append(n)
  end

/* Per-node all-or-nothing page acceptance.  An unreachable/changed peer
 * cannot leave an incomplete set of results that looks authoritative. */
::method search
  expose client nodes
  use strict arg query='',pageSize=25,maxPages=8
  if \datatype(pageSize,'W') | \datatype(maxPages,'W') then -
    raise syntax 88.900 array('integer page limits required')
  if pageSize<1 | pageSize>100 | maxPages<1 | maxPages>100 then -
    raise syntax 88.900 array('page limits outside bounds')
  if length(query~string)>1024 then raise syntax 88.900 array('query too long')
  records=.array~new; coverage=.directory~new
  complete=.true
  do node over nodes
    nodeItems=.array~new
    rev=.nil; offset=0; code='UNREACHABLE'; pages=0
    do ix=1 to maxPages
      pages=ix
      r=client~catalogueList(node,query,offset,pageSize,rev)
      if r==.nil then do
        code='UNREACHABLE'
        leave
      end
      if \r~isA(.Directory) then do
        code='INVALID_RESPONSE'
        leave
      end
      if r['status']<>'OK' then do
        code=r['code']
        leave
      end
      p=r['payload']
      if p==.nil | \p~isA(.Directory) then do
        code='INVALID_RESPONSE'; leave
      end
      if \p~hasIndex('node_id') | \p~hasIndex('revision') | \p~hasIndex('items') | \p~hasIndex('offset') | \p~hasIndex('more') then do
        code='INVALID_RESPONSE'; leave
      end
      if p['node_id']<>node | p['offset']<>offset | \p['items']~isA(.Array) then do
        code='INVALID_RESPONSE'; leave
      end
      if p['items']~items>pageSize then do
        code='INVALID_RESPONSE'; leave
      end
      if rev==.nil then rev=p['revision']
      else if rev<>p['revision'] then do
        code='REVISION_CHANGED';leave
      end
      do item over p['items']
        if \item~isA(.Directory) then do
          code='INVALID_RESPONSE';leave
        end
        nodeItems~append(item)
      end
      if code='INVALID_RESPONSE' then leave
      if p['more']==.false | p['more']==0 then do
        code='OK';leave
      end
      if p['more']\==.true & p['more']\==1 then do
        code='INVALID_RESPONSE';leave
      end
      if p['items']~items=0 then do
        code='INVALID_RESPONSE';leave
      end
      offset+=p['items']~items
      code='TRUNCATED'
    end
    state=.directory~new
    state['code']=code;state['node_id']=node;state['pages']=pages
    state['revision']=rev;state['accepted']=0
    if code='OK' then do
      state['accepted']=nodeItems~items
      do item over nodeItems
        row=.directory~new
        row['node_id']=node;row['revision']=rev;row['item']=item
        records~append(row)
      end
    end
    else complete=.false
    coverage[node]=state
  end
  aggregate=.directory~new
  aggregate['ok']=complete;aggregate['complete']=complete
  aggregate['code']='PARTIAL'
  if complete then aggregate['code']='OK'
  aggregate['nodes']=nodes~items;aggregate['records']=records
  aggregate['coverage']=coverage;aggregate['record_count']=records~items
  return aggregate

::requires 'StoragePeer.cls'
