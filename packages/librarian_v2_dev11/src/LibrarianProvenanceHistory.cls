/* Librarian v2 dev11: occurrence-anchored, bitemporal provenance evidence.
   Clean-room evidence objects. No assertions of independence or causal truth.
   Single Time Service owns civil-time resolution via LibrarianTimePoint. */
::class 'LibrarianProvenanceClaim' public
::method init
  expose identifier lineage predecessor action eventId propositionId childEdition childOccurrence childSpan parentEdition parentOccurrence parentSpan relation evidenceId published observed publishedZone observedZone publishedEdition observedEdition
  use strict arg identifier,lineage,predecessor,action,eventId,propositionId,childEdition,childOccurrence,childSpan,parentEdition,parentOccurrence,parentSpan,relation,evidenceId,pubPoint,obsPoint
  if identifier=='' | lineage=='' | eventId=='' | propositionId=='' then raise syntax 93.900 array ('claim identity missing')
  if childEdition=='' | childOccurrence=='' | childSpan=='' then raise syntax 93.900 array ('child source occurrence and span required')
  if parentEdition=='' | parentOccurrence=='' | parentSpan=='' then raise syntax 93.900 array ('parent source occurrence and span required')
  if evidenceId=='' then raise syntax 93.900 array ('evidence reference missing')
  if action\=='ASSERT' & action\=='CORRECT' & action\=='RETRACT' then raise syntax 93.900 array ('invalid action')
  if action=='ASSERT' & predecessor\=='' then raise syntax 93.900 array ('original cannot supersede')
  if action\=='ASSERT' & predecessor=='' then raise syntax 93.900 array ('revision requires predecessor')
  if relation\=='QUOTED' & relation\=='SYNDICATED' & relation\=='AGGREGATED' & relation\=='DERIVED' & relation\=='CORROBORATION_CLAIM' then raise syntax 93.900 array ('invalid provenance relation')
  if childEdition==parentEdition & childOccurrence==parentOccurrence then raise syntax 93.900 array ('self provenance occurrence')
  if \pubPoint~isA(.LibrarianTimePoint) then raise syntax 93.900 array ('publication point required')
  if \obsPoint~isA(.LibrarianTimePoint) then raise syntax 93.900 array ('observation point required')
  numeric digits 30
  published=pubPoint~seconds+0
  observed=obsPoint~seconds+0
  if observed<published then raise syntax 93.900 array ('observation precedes publication')
  publishedZone=pubPoint~zone
  observedZone=obsPoint~zone
  publishedEdition=pubPoint~edition
  observedEdition=obsPoint~edition
::attribute identifier get
::attribute lineage get
::attribute predecessor get
::attribute action get
::attribute eventId get
::attribute propositionId get
::attribute childEdition get
::attribute childOccurrence get
::attribute childSpan get
::attribute parentEdition get
::attribute parentOccurrence get
::attribute parentSpan get
::attribute relation get
::attribute evidenceId get
::attribute published get
::attribute observed get
::attribute publishedZone get
::attribute observedZone get
::attribute publishedEdition get
::attribute observedEdition get

::class 'LibrarianProvenanceHistory' public
::method init
  expose records byId
  records=.array~new
  byId=.directory~new
::method append
  expose records byId
  use strict arg rec
  if \rec~isA(.LibrarianProvenanceClaim) then raise syntax 93.900 array ('claim type')
  if byId~hasIndex(rec~identifier) then raise syntax 93.900 array ('duplicate provenance assertion')
  if rec~predecessor\=='' then do
    if \byId~hasIndex(rec~predecessor) then raise syntax 93.900 array ('missing predecessor')
    old=byId[rec~predecessor]
    if old~lineage\==rec~lineage then raise syntax 93.900 array ('cross-lineage correction')
    if old~eventId\==rec~eventId | old~propositionId\==rec~propositionId then raise syntax 93.900 array ('cross-claim correction')
    if old~childEdition\==rec~childEdition | old~childOccurrence\==rec~childOccurrence then raise syntax 93.900 array ('cross-occurrence correction')
    if rec~published<old~published then raise syntax 93.900 array ('retrograde published correction')
    if rec~observed<old~observed then raise syntax 93.900 array ('retrograde observed correction')
  end
  else do prior over records
    if prior~lineage==rec~lineage then raise syntax 93.900 array ('duplicate lineage root')
  end
  byId[rec~identifier]=rec
  records~append(rec)
  return self
::method snapshot
  expose records
  use strict arg eventId,propositionId,pubCut,obsCut
  if \pubCut~isA(.LibrarianTimePoint) then raise syntax 93.900 array ('publication cutoff type')
  if \obsCut~isA(.LibrarianTimePoint) then raise syntax 93.900 array ('observation cutoff type')
  numeric digits 30
  eligible=.directory~new
  superseded=.directory~new
  tips=.directory~new
  count=0
  do rec over records
    if rec~eventId\==eventId | rec~propositionId\==propositionId then iterate
    if rec~published>pubCut~seconds | rec~observed>obsCut~seconds then iterate
    eligible[rec~identifier]=rec
    count=count+1
  end
  do rec over eligible~allItems
    if rec~predecessor\=='' then superseded[rec~predecessor]=1
  end
  do rec over eligible~allItems
    if superseded~hasIndex(rec~identifier) then iterate
    if \tips~hasIndex(rec~lineage) then tips[rec~lineage]=.array~new
    tips[rec~lineage]~append(rec)
  end
  return .LibrarianProvenanceSnapshot~new(tips,count,eventId,propositionId,pubCut,obsCut,eligible)
::requires 'LibrarianTemporal.cls'

::class 'LibrarianProvenanceSnapshot' public
::method init
  expose active recordsSeen retracted conflicted canonicalRows canonicalLedger scopeHeader conflictedNodes
  use strict arg tips,recordsSeen,eventId,propositionId,pubCut,obsCut,eligible
  active=.array~new
  retracted=0
  conflicted=0
  canonicalRows=.array~new
  canonicalLedger=.array~new
  conflictedNodes=.directory~new
  /* Scope and both knowledge-cutoff identities belong to the snapshot key.
     Omitted scope made two different event/proposition views serialize alike. */
  scopeHeader=self~token('LIBRARIAN-PROVENANCE-SNAPSHOT/2')||self~token(eventId)||self~token(propositionId)||self~token(pubCut~seconds)||self~token(pubCut~zone)||self~token(pubCut~edition)||self~token(obsCut~seconds)||self~token(obsCut~zone)||self~token(obsCut~edition)
  /* Include every eligible historical record, including superseded rows and
     complete contradictory tips. Tip counts alone are not evidence identity. */
  do rec over eligible~allItems
    encoded=self~token(rec~identifier)||self~token(rec~lineage)||self~token(rec~predecessor)||self~token(rec~action)||self~token(rec~eventId)||self~token(rec~propositionId)||self~token(rec~childEdition)||self~token(rec~childOccurrence)||self~token(rec~childSpan)||self~token(rec~parentEdition)||self~token(rec~parentOccurrence)||self~token(rec~parentSpan)||self~token(rec~relation)||self~token(rec~evidenceId)||self~token(rec~published)||self~token(rec~observed)||self~token(rec~publishedZone)||self~token(rec~observedZone)||self~token(rec~publishedEdition)||self~token(rec~observedEdition)
    canonicalLedger~append(encoded)
  end
  canonicalLedger~sort
  do lineage over tips~allIndexes
    group=tips[lineage]
    if group~items\==1 then do
      conflicted=conflicted+1
      /* The unresolved lineage taints the child occurrence and everything
         depending on it, not unrelated source subgraphs. */
      do fork over group
        conflictedNodes[self~node(fork~childEdition,fork~childOccurrence)]=1
      end
      forks=.array~new
      do fork over group
        forks~append(self~token(fork~identifier)||self~token(fork~action)||self~token(fork~evidenceId)||self~token(fork~published)||self~token(fork~observed))
      end
      forks~sort
      encoded=self~token(lineage)||self~token('CONFLICT')
      do forkData over forks
        encoded=encoded||self~token(forkData)
      end
      canonicalRows~append(encoded)
      iterate
    end
    rec=group[1]
    if rec~action=='RETRACT' then do
      retracted=retracted+1
      canonicalRows~append(self~token(lineage)||self~token('RETRACT')||self~token(rec~identifier)||self~token(rec~evidenceId)||self~token(rec~published)||self~token(rec~observed)||self~token(rec~publishedZone)||self~token(rec~publishedEdition)||self~token(rec~observedZone)||self~token(rec~observedEdition))
      iterate
    end
    active~append(rec)
    canonicalRows~append(self~token(lineage)||self~token('ACTIVE')||self~token(rec~identifier)||self~token(rec~relation)||self~token(rec~childEdition)||self~token(rec~childOccurrence)||self~token(rec~childSpan)||self~token(rec~parentEdition)||self~token(rec~parentOccurrence)||self~token(rec~parentSpan)||self~token(rec~evidenceId)||self~token(rec~published)||self~token(rec~observed)||self~token(rec~publishedZone)||self~token(rec~publishedEdition)||self~token(rec~observedZone)||self~token(rec~observedEdition))
  end
  canonicalRows~sort
::method token private
  use strict arg value
  return value~length||':'||value
::attribute recordsSeen get
::attribute retracted get
::attribute conflicted get
::method activeCount
  expose active
  return active~items
::method canonical
  expose canonicalRows canonicalLedger scopeHeader
  output=self~token(scopeHeader)
  do piece over canonicalLedger
    output=output||self~token(piece)
  end
  /* Explicit projected outcomes remain inside the canonical representation. */
  do piece over canonicalRows
    output=output||self~token(piece)
  end
  return output
::method node private
  use strict arg edition,occurrence
  return self~token(edition)||self~token(occurrence)
::method dependencyAncestors private
  expose active
  use strict arg source
  found=.directory~new
  visited=.directory~new
  pending=.queue~new
  pending~queue(source)
  do while pending~items>0
    current=pending~pull
    if visited~hasIndex(current) then iterate
    visited[current]=1
    do rec over active
      /* Alleged corroboration is NOT a lineage dependency. */
      if rec~relation=='CORROBORATION_CLAIM' then iterate
      if self~node(rec~childEdition,rec~childOccurrence)\==current then iterate
      parent=self~node(rec~parentEdition,rec~parentOccurrence)
      found[parent]=1
      if \visited~hasIndex(parent) then pending~queue(parent)
    end
  end
  return found
::method hasCycle
  expose active
  do rec over active
    if rec~relation=='CORROBORATION_CLAIM' then iterate
    parent=self~node(rec~parentEdition,rec~parentOccurrence)
    child=self~node(rec~childEdition,rec~childOccurrence)
    ancestors=self~dependencyAncestors(parent)
    if ancestors~hasIndex(child) then return .true
  end
  return .false
::method conflictAffects private
  expose conflictedNodes
  use strict arg left,right
  if conflictedNodes~items==0 then return .false
  if conflictedNodes~hasIndex(left) then return .true
  if conflictedNodes~hasIndex(right) then return .true
  /* Active edges pointing to a disputed child carry its uncertainty
     downstream. An unrelated disputed component must not contaminate
     an otherwise defensible evidence relationship. */
  leftAnc=self~dependencyAncestors(left)
  rightAnc=self~dependencyAncestors(right)
  do parent over leftAnc~allIndexes
    if conflictedNodes~hasIndex(parent) then return .true
  end
  do parent over rightAnc~allIndexes
    if conflictedNodes~hasIndex(parent) then return .true
  end
  return .false
::method cycleAffects private
  use strict arg left,right
  /* Only cycles reachable in the queried dependency closures matter.
     Global hasCycle remains available as a whole-snapshot diagnostic. */
  participants=.directory~new
  participants[left]=1
  participants[right]=1
  leftAnc=self~dependencyAncestors(left)
  rightAnc=self~dependencyAncestors(right)
  do parent over leftAnc~allIndexes
    participants[parent]=1
  end
  do parent over rightAnc~allIndexes
    participants[parent]=1
  end
  do subject over participants~allIndexes
    ancestors=self~dependencyAncestors(subject)
    if ancestors~hasIndex(subject) then return .true
  end
  return .false
::method relationship
  use strict arg leftEdition,leftOccurrence,rightEdition,rightOccurrence
  left=self~node(leftEdition,leftOccurrence)
  right=self~node(rightEdition,rightOccurrence)
  if left==right then return 'SAME_OCCURRENCE'
  if self~conflictAffects(left,right) then return 'INDETERMINATE_CONFLICT'
  if self~cycleAffects(left,right) then return 'UNRESOLVED_CYCLE'
  leftAnc=self~dependencyAncestors(left)
  rightAnc=self~dependencyAncestors(right)
  if leftAnc~hasIndex(right) | rightAnc~hasIndex(left) then return 'DECLARED_DEPENDENCY'
  do parent over leftAnc~allIndexes
    if rightAnc~hasIndex(parent) then return 'DECLARED_SHARED_UPSTREAM'
  end
  return 'INDEPENDENCE_NOT_ESTABLISHED'
::method independenceVerdict
  return 'NOT_ESTABLISHED'
