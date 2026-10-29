/* Single Time Service v0.7 — read-only temporal impact analysis.
 * Compare two committed authority revisions, with explicit timezone service
 * snapshots. No mutation, subscriptions, dispatch, or fabricated future rule.
 * Unknown/gap/fold status is retained as meaningful evidence, not flattened.
 */
::requires 'TimeAuthorityLedger.cls'

::class 'TimeImpactAnalyzer' public
::method init
  expose ledger olderRules newerRules rulesMode
  use strict arg ledger, olderRules, newerRules = .nil
  if \ledger~isA(.TimeAuthorityLedger) then raise syntax 93.900 array ('TimeAuthorityLedger required')
  if \olderRules~hasMethod('resolveIsoLocal') then raise syntax 93.900 array ('prior timezone service required')
  if newerRules == .nil then do
    newerRules=olderRules
    rulesMode='SAME_PROVIDER'
  end
  else do
    if \newerRules~hasMethod('resolveIsoLocal') then raise syntax 93.900 array ('current timezone service required')
    rulesMode='EXPLICIT_SNAPSHOTS'
  end

/* No implicit NOW or calendar inference; caller must supply a closed range.
 * Changes are atomic per civil date; the result is an observation, not an
 * executable scheduling instruction or a subscription delivery receipt. */
::attribute authorityLedger get
  expose ledger
  return ledger

::method compare
  expose ledger olderRules newerRules rulesMode
  use strict arg institution, phrase, fromDate, throughDate, fromRevision, toRevision, maxDays = 31
  numeric digits 30
  if institution == '' | phrase == '' then raise syntax 93.900 array ('institution and intention required')
  if \datatype(fromRevision,'W') | \datatype(toRevision,'W') then raise syntax 93.900 array ('integer authority revisions required')
  if fromRevision < 0 | toRevision < 0 | fromRevision > ledger~revision | toRevision > ledger~revision then
    raise syntax 93.900 array ('authority revision outside committed history')
  if \datatype(maxDays,'W') | maxDays < 1 | maxDays > 366 then raise syntax 93.900 array ('impact maximum must be 1..366 days')
  if fromDate~length \= 10 | throughDate~length \= 10 then raise syntax 93.900 array ('ISO dates required')
  first=.IsoCivilClock~parseLocal(fromDate || 'T00:00:00')~coordinate % 86400
  last=.IsoCivilClock~parseLocal(throughDate || 'T00:00:00')~coordinate % 86400
  if last < first | last-first+1 > maxDays then raise syntax 93.900 array ('impact date range exceeds bound or is reversed')
  changes=.array~new
  unchanged=0
  do day=first to last
    onDate=left(.IsoCivilClock~formatLocal(.TimeLocalReading~new(day*86400)),10)
    prior=ledger~resolveAt(institution,phrase,onDate,olderRules,fromRevision)
    current=ledger~resolveAt(institution,phrase,onDate,newerRules,toRevision)
    reasons=self~reasons(prior,current)
    if reasons~items == 0 then do
      unchanged+=1
      iterate
    end
    delta=.nil
    oldTick=self~onlyInstant(prior)
    newTick=self~onlyInstant(current)
    if oldTick \== .nil & newTick \== .nil then delta=newTick-oldTick
    item=.directory~new
    item['date']=onDate
    item['reasonCodes']=reasons
    item['before']=prior
    item['after']=current
    item['utcDeltaSeconds']=delta
    changes~append(item)
  end
  record=.directory~new
  record['schema']='single.time.impact/0.1'
  record['institution']=institution
  record['phrase']=phrase
  record['fromDate']=fromDate
  record['throughDate']=throughDate
  record['fromRevision']=fromRevision
  record['toRevision']=toRevision
  record['fromHeadChecksum']=self~headAt(fromRevision)
  record['toHeadChecksum']=self~headAt(toRevision)
  record['integrity']='ACCIDENTAL_CORRUPTION_ONLY'
  record['ruleComparisonMode']=rulesMode
  record['scannedDays']=last-first+1
  record['changedDays']=changes~items
  record['unchangedDays']=unchanged
  record['changes']=changes
  record['effect']='ADVISORY_ONLY'
  return record

/* The ledger owns the historical witness contract, without exposing
 * its mutable catalog or the implementation of the checksum algorithm. */
::method headAt private
  expose ledger
  use strict arg target
  witness=ledger~revisionWitness(target)
  return witness['headChecksum']

::method read private
  use strict arg entry, key, fallback = ''
  if entry~hasIndex(key) then do
    if entry[key] \== .nil then return entry[key]
  end
  return fallback

::method onlyInstant private
  use strict arg snapshot
  rows=self~read(snapshot,'occurrences',.array~new)
  if rows~items \= 1 then return .nil
  return self~read(rows[1],'instantPosixSeconds',.nil)

::method reasons private
  use strict arg prior, current
  numeric digits 30
  reasons=.array~new
  if self~read(prior,'status') \== self~read(current,'status') then reasons~append('STATUS_CHANGED')
  if self~read(prior,'eventId') \== self~read(current,'eventId') |,
     self~meaningKey(prior) \== self~meaningKey(current) then reasons~append('MEANING_CHANGED')
  if self~read(prior,'label') \== self~read(current,'label') |,
     self~read(prior,'classification') \== self~read(current,'classification') then reasons~append('EVENT_DESCRIPTION_CHANGED')
  if self~read(prior,'zone') \== self~read(current,'zone') then reasons~append('ZONE_CHANGED')
  if self~read(prior,'elapsedDurationSeconds') \== self~read(current,'elapsedDurationSeconds') then reasons~append('DURATION_CHANGED')
  if self~read(prior,'tzdbEdition') \== self~read(current,'tzdbEdition') then reasons~append('RULE_EDITION_CHANGED')
  if self~read(prior,'reason') \== self~read(current,'reason') |,
     self~read(prior,'exception') \== self~read(current,'exception') then reasons~append('EXPLANATION_CHANGED')
  before=self~read(prior,'occurrences',.array~new)
  after=self~read(current,'occurrences',.array~new)
  if self~occurrenceField(before,'local') \== self~occurrenceField(after,'local') then reasons~append('LOCAL_TIME_CHANGED')
  if self~occurrenceField(before,'instantPosixSeconds') \== self~occurrenceField(after,'instantPosixSeconds') then reasons~append('UTC_PROJECTION_CHANGED')
  if self~occurrenceField(before,'abbreviation') \== self~occurrenceField(after,'abbreviation') then reasons~append('ZONE_ABBREVIATION_CHANGED')
  if self~occurrenceField(before,'offsetSeconds') \== self~occurrenceField(after,'offsetSeconds') |,
     self~occurrenceField(before,'status') \== self~occurrenceField(after,'status') |,
     self~occurrenceField(before,'selection') \== self~occurrenceField(after,'selection') then reasons~append('RESOLUTION_CHANGED')
  return reasons

/* Deterministic order and field boundaries: avoid unqualified concatenation
 * collisions for numeric-looking IDs and variable-size occurrence arrays. */
::method occurrenceField private
  use strict arg rows, field
  signature=rows~items || ':'
  do row over rows
    if row~hasIndex(field) then value=row[field]
    else value=.nil
    if value == .nil then token='N'
    else token='V' || value~length || ':' || value
    signature=signature || token~length || ':' || token
  end
  return signature

::method meaningKey private
  use strict arg snapshot
  meanings=self~read(snapshot,'meanings',.array~new)
  fingerprint=meanings~items || ':'
  do m over meanings
    identity=self~read(m,'eventId')
    caption=self~read(m,'label')
    fingerprint=fingerprint || identity~length || ':' || identity || caption~length || ':' || caption
  end
  return fingerprint

/* Optional LOCAL pull watch. Its cursor is consumer-owned: poll is read-only
 * and never acknowledges itself. A crash before explicit acknowledgement
 * therefore replays the same advisory impact. No remote push or Queue Fabric
 * delivery guarantee is claimed; caller persists checkpoint when required. */
::class 'TimeChangeWatch' public
::method init
  expose ledger analyzer identifier institution phrase fromDate throughDate maxDays cursor cursorHead offerRevision offerHead
  use strict arg ledger, analyzer, identifier, institution, phrase, fromDate, throughDate, cursor, cursorHead = .nil, maxDays = 31
  if \ledger~isA(.TimeAuthorityLedger) | \analyzer~isA(.TimeImpactAnalyzer) then raise syntax 93.900 array ('time authority and impact analyzer required')
  if analyzer~authorityLedger \== ledger then raise syntax 93.900 array ('watch and analyzer must use same authority instance')
  if identifier == '' | identifier~length > 128 then raise syntax 93.900 array ('bounded watch identifier required')
  if \datatype(cursor,'W') then raise syntax 93.900 array ('integer watch revision required')
  proof=ledger~revisionWitness(cursor)
  if cursorHead \== .nil & cursorHead \== proof['headChecksum'] then raise syntax 93.900 array ('watch checkpoint witness mismatch')
  cursorHead=proof['headChecksum']
  offerRevision=.nil
  offerHead=.nil
  /* Validate the scope before exposing the watch. A zero-change scan is safe
   * and cannot advance a cursor or publish anything. */
  ignore=analyzer~compare(institution,phrase,fromDate,throughDate,cursor,cursor,maxDays)
::attribute identifier get
::attribute cursorRevision get
  expose cursor
  return cursor

::method checkpoint
  expose identifier cursor cursorHead
  answer=.directory~new
  answer['id']=identifier
  answer['revision']=cursor
  answer['headChecksum']=cursorHead
  answer['durability']='CALLER_OWNED'
  return answer

::method poll
  expose ledger analyzer identifier institution phrase fromDate throughDate maxDays cursor cursorHead offerRevision offerHead
  /* A rewritten journal of the same length must not be accepted as history. */
  at=ledger~revisionWitness(cursor)
  if at['headChecksum'] \== cursorHead then raise syntax 93.900 array ('watch cursor history diverged')
  target=ledger~revision
  answer=.directory~new
  answer['id']=identifier
  answer['fromRevision']=cursor
  answer['toRevision']=target
  answer['ackRequired']=.false
  answer['impact']=.nil
  if target == cursor then do
    answer['status']='NO_NEW_REVISION'
    return answer
  end
  comparison=analyzer~compare(institution,phrase,fromDate,throughDate,cursor,target,maxDays)
  /* Reject if the writer advanced while calculating the comparison. */
  if ledger~revision \= target then raise syntax 93.900 array ('authority changed during impact scan')
  offerRevision=target
  offerHead=comparison['toHeadChecksum']
  answer['status']='IMPACT' 
  if comparison['changedDays'] == 0 then answer['status']='NO_EFFECT'
  answer['impact']=comparison
  answer['ackRequired']=.true
  return answer

/* Only the exact last offered head can advance the cursor. A caller must
 * durably save checkpoint() itself; returning a receipt is not a durable ack. */
::method acknowledge
  expose ledger cursor cursorHead offerRevision offerHead
  use strict arg revision, headChecksum
  if offerRevision == .nil | revision \= offerRevision | headChecksum \== offerHead then
    raise syntax 93.900 array ('watch acknowledgement has no matching offer')
  at=ledger~revisionWitness(revision)
  if at['headChecksum'] \== headChecksum then raise syntax 93.900 array ('watch acknowledgement history changed')
  cursor=revision
  cursorHead=headChecksum
  offerRevision=.nil
  offerHead=.nil
  return self~checkpoint
