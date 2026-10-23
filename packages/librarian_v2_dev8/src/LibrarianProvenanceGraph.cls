/* Librarian v2 dev8: multi-parent evidence graph.
   Edges are statements with provenance, never verified independence. */
::class 'LibrarianProvenanceEdge' public
::method init
  expose edgeId child parent relation evidenceId
  use strict arg edgeId, child, parent, relation, evidenceId
  if edgeId=='' | child=='' | parent=='' | evidenceId=='' then raise syntax 93.900 array ('missing provenance')
  if child==parent then raise syntax 93.900 array ('self provenance')
  if relation\=='QUOTED' & relation\=='SYNDICATED' & relation\=='AGGREGATED' & relation\=='DERIVED' & relation\=='CORROBORATION_CLAIM' then raise syntax 93.900 array ('invalid relation')
::attribute edgeId get
::attribute child get
::attribute parent get
::attribute relation get
::attribute evidenceId get

::class 'LibrarianProvenanceGraph' public
::method init
  expose edges byId
  edges=.array~new
  byId=.directory~new
::method add
  expose edges byId
  use strict arg edge
  if \edge~isA(.LibrarianProvenanceEdge) then raise syntax 93.900 array ('invalid edge')
  if byId~hasIndex(edge~edgeId) then raise syntax 93.900 array ('duplicate edge')
  /* Check existing graph before inserting the new edge; this prohibits a cycle. */
  if self~reaches(edge~parent,edge~child) then raise syntax 93.900 array ('cycle')
  byId[edge~edgeId]=edge
  edges~append(edge)
  return self
::method reaches
  expose edges
  use strict arg start,target
  if start==target then return .true
  visited=.directory~new
  pending=.queue~new
  pending~queue(start)
  do while pending~items>0
    current=pending~pull
    if visited~hasIndex(current) then iterate
    visited[current]=1
    do edge over edges
      if edge~child\==current then iterate
      if edge~parent==target then return .true
      if \visited~hasIndex(edge~parent) then pending~queue(edge~parent)
    end
  end
  return .false
::method ancestors
  expose edges
  use strict arg node
  resultSet=.directory~new
  visited=.directory~new
  pending=.queue~new
  pending~queue(node)
  do while pending~items>0
    current=pending~pull
    if visited~hasIndex(current) then iterate
    visited[current]=1
    do edge over edges
      if edge~child\==current then iterate
      resultSet[edge~parent]=1
      if \visited~hasIndex(edge~parent) then pending~queue(edge~parent)
    end
  end
  return resultSet
::method relationship
  use strict arg left,right
  if left==right then return 'SAME_SOURCE'
  if self~reaches(left,right) | self~reaches(right,left) then return 'DECLARED_DEPENDENCY'
  l=self~ancestors(left)
  r=self~ancestors(right)
  do upstream over l~allIndexes
    if r~hasIndex(upstream) then return 'DECLARED_SHARED_UPSTREAM'
  end
  return 'INDEPENDENCE_NOT_ESTABLISHED'
::method independenceVerdict
  return 'NOT_ESTABLISHED'
