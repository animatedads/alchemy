/* Single Time Service v0.6: an optional append-only temporal authority store.
 * This owns catalog mutation durability, not event execution or transport.
 * Records are checksummed for accidental corruption, NOT authenticated.
 * Single process writer required; no fsync or advisory/mandatory locking.
 * Recovery rejects any divergent, truncated or checksum-invalid history.
 */
::requires 'TimeEvents.cls'

::class 'TimeAuthorityLedger' public
::method init
  expose pathname records revision head catalog dirty
  use strict arg pathname
  if pathname == '' then raise syntax 93.900 array ('journal pathname required')
  records=.array~new
  revision=0
  head='GENESIS'
  dirty=.false
  catalog=.TimeEventCatalog~new
  self~reload
::attribute revision get
::attribute headChecksum get
  expose head
  return head
::attribute journalPath get
  expose pathname
  return pathname

/* Always reconstruct the entire ledger; never trust a partial tail.
 * The already-recovered object is unchanged when reading fails. */
::method reload
  expose pathname records revision head catalog dirty
  numeric digits 30
  if dirty then raise syntax 93.900 array ('journal is dirty; create a new ledger instance')
  pending=.array~new
  prev='GENESIS'
  if stream(pathname,'C','QUERY EXISTS') \== '' then do
    opened=stream(pathname,'C','OPEN READ')
    if left(opened,6) == 'ERROR:' then raise syntax 93.900 array ('unable to open journal')
    do while lines(pathname)>0
      line=linein(pathname)
      if line~length > 65536 then do
        unused=stream(pathname,'C','CLOSE')
        raise syntax 93.900 array ('journal record too large')
      end
      row=self~decode(line,pending~items+1,prev)
      pending~append(row)
      prev=self~checksum(line)
      if pending~items > 100000 then do
        unused=stream(pathname,'C','CLOSE')
        raise syntax 93.900 array ('journal too large')
      end
    end
    unused=stream(pathname,'C','CLOSE')
  end
  candidate=self~build(pending,pending~items)
  records=pending
  catalog=candidate
  revision=records~items
  head=prev
  return self

/* Historical inspection builds a fresh catalog: no mutation of the current
 * view, and no earlier state is rewritten to reflect later amendments. */
::method catalogAt private
  expose records revision
  use strict arg target
  if \datatype(target,'W') | target < 0 | target > revision then raise syntax 93.900 array ('revision out of range')
  return self~build(records,target)
::method resolve
  expose catalog
  use strict arg context, phrase, date, service
  return catalog~resolve(context,phrase,date,service)
::method resolveAt
  expose revision
  use strict arg context, phrase, date, service, target
  old=self~catalogAt(target)
  answer=old~resolve(context,phrase,date,service)
  answer['authoritySequence']=target
  answer['authorityHeadChecksum']=self~checksumAt(target)
  answer['integrity']='ACCIDENTAL_CORRUPTION_ONLY'
  return answer
/* Recalculate the exact committed head of an earlier authority revision.
 * This is a consistency witness, NOT a signature or trusted timestamp. */
::method checksumAt private
  expose records revision head
  use strict arg target
  if \datatype(target,'W') | target < 0 | target > revision then raise syntax 93.900 array ('revision out of range')
  if target == revision then return head
  old='GENESIS'
  do i=1 to target
    row=records[i]
    fields=.array~new
    do j=2 to row~items
      fields~append(row[j])
    end
    old=self~checksum(self~encode(i,old,row[1],fields))
  end
  return old
/* Read-only witness for a precise committed authority prefix. This is a
 * non-cryptographic consistency checksum, not notarisation or authentication.
 * Consumers must not infer a TZif snapshot is retained by this witness. */
::method revisionWitness
  expose revision
  use strict arg target
  head=self~checksumAt(target)
  witness=.directory~new
  witness['revision']=target
  witness['headChecksum']=head
  witness['integrity']='ACCIDENTAL_CORRUPTION_ONLY'
  return witness

::method resolveCurrent
  expose revision
  use strict arg context, phrase, date, service
  return self~resolveAt(context,phrase,date,service,revision)

/* Client-supplied expectedRevision implements optimistic concurrency for
 * this process. A disk reload immediately before appending detects external
 * changes, although concurrent processes remain explicitly unsupported. */
::method apply
  expose pathname records revision head catalog dirty
  use strict arg operation, fields, expectedRevision
  numeric digits 30
  if dirty then raise syntax 93.900 array ('journal is dirty')
  if \datatype(expectedRevision,'W') | expectedRevision \= revision then raise syntax 93.900 array ('authority revision conflict')
  if \fields~isA(.Array) then raise syntax 93.900 array ('field array required')
  if records~items >= 100000 then raise syntax 93.900 array ('journal size limit')
  /* Detect both appended revisions and same-length rewritten histories. */
  oldHead=head
  self~reload
  if expectedRevision \= revision | oldHead \== head then raise syntax 93.900 array ('external journal mutation conflict')
  candidateRecords=.array~new
  do entry over records
    candidateRecords~append(entry)
  end
  candidateRecords~append(self~entry(operation,fields))
  candidate=self~build(candidateRecords,candidateRecords~items)
  line=self~encode(candidateRecords~items,head,operation,fields)
  if line~length > 65536 then raise syntax 93.900 array ('journal record too large')
  dirty=.true
  opened=stream(pathname,'C','OPEN WRITE APPEND')
  if left(opened,6) == 'ERROR:' then raise syntax 93.900 array ('cannot open journal for append')
  written=lineout(pathname,line)
  closed=stream(pathname,'C','CLOSE')
  if written \= 0 | left(closed,6) == 'ERROR:' then raise syntax 93.900 array ('cannot commit journal record')
  records=candidateRecords
  revision=records~items
  catalog=candidate
  head=self~checksum(line)
  dirty=.false
  return revision

/* Each method records an intent; no caller gets a mutable catalog reference.
 * All management calls are trusted, local operations, not public RPC calls. */
::method addCalendar
  use strict arg identifier, zone, edition, expectedRevision
  return self~apply('CALENDAR',.array~of(identifier,zone,edition),expectedRevision)
::method addEvent
  use strict arg identifier, calendarId, label, kind, startDate, endDate, clockTime, frequency, interval, weekdays, duration, gap, fold, edition, expectedRevision
  return self~apply('EVENT',.array~of(identifier,calendarId,label,kind,startDate,endDate,clockTime,frequency,interval,weekdays,duration,gap,fold,edition),expectedRevision)
::method closeDate
  use strict arg context, date, reason, expectedRevision
  return self~apply('CLOSE',.array~of(context,date,reason),expectedRevision)
::method cancelDate
  use strict arg eventId, date, reason, expectedRevision
  return self~apply('CANCEL',.array~of(eventId,date,reason),expectedRevision)
::method moveDate
  use strict arg eventId, date, clockTime, reason, expectedRevision
  return self~apply('MOVE',.array~of(eventId,date,clockTime,reason),expectedRevision)
::method bindPhrase
  use strict arg context, phrase, eventId, expectedRevision
  return self~apply('BIND',.array~of(context,phrase,eventId),expectedRevision)
::method unbindPhrase
  use strict arg context, phrase, eventId, expectedRevision
  return self~apply('UNBIND',.array~of(context,phrase,eventId),expectedRevision)

::method entry private
  use strict arg op, fields
  r=.array~new
  r~append(op)
  do value over fields
    r~append(value)
  end
  return r
::method build private
  use strict arg records, limit
  catalog=.TimeEventCatalog~new
  do i=1 to limit
    row=records[i]
    op=row[1]
    select
      when op == 'CALENDAR' & row~items == 4 then
        catalog~registerCalendar(.TimeInstitutionCalendar~new(row[2],row[3],row[4]))
      when op == 'EVENT' & row~items == 15 then
        catalog~registerEvent(.TimeNamedEvent~new(row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],row[13],row[14],row[15]))
      when op == 'CLOSE' & row~items == 4 then catalog~calendarFor(row[2])~closeDate(row[3],row[4])
      when op == 'CANCEL' & row~items == 4 then self~eventFor(catalog,row[2])~cancelDate(row[3],row[4])
      when op == 'MOVE' & row~items == 5 then self~eventFor(catalog,row[2])~moveDate(row[3],row[4],row[5])
      when op == 'BIND' & row~items == 4 then catalog~bindPhrase(row[2],row[3],row[4])
      when op == 'UNBIND' & row~items == 4 then catalog~unbindPhrase(row[2],row[3],row[4])
      otherwise raise syntax 93.900 array ('unknown or invalid journal operation')
    end
  end
  return catalog

/* A restricted lookup is used only by replay. It does not escape the catalog. */
::method eventFor private
  use strict arg catalog, id
  return catalog~authorityEventFor(id)

::method encode private
  use strict arg sequence, previous, operation, fields
  if operation == '' | pos('|',operation)>0 then raise syntax 93.900 array ('invalid operation')
  record='STS6|' || sequence || '|' || previous || '|' || operation || '|' || fields~items
  do field over fields
    if \field~isA(.String) | field~length > 8192 then raise syntax 93.900 array ('invalid authority field')
    record=record || '|' || c2x(field)
  end
  return record || '|' || self~checksum(record) || '|COMMIT'

::method decode private
  use strict arg line, wantedSeq, wantedPrev
  pieces=line~makeArray('|')
  if pieces~items < 7 | pieces[1] \== 'STS6' | pieces[3] \== wantedPrev | pieces[pieces~items] \== 'COMMIT' then
    raise syntax 93.900 array ('invalid journal envelope')
  if \datatype(pieces[2],'W') | pieces[2] \= wantedSeq then raise syntax 93.900 array ('non-monotonic journal sequence')
  n=pieces[5]
  if \datatype(n,'W') | n < 0 | n > 14 | pieces~items \= n+7 then raise syntax 93.900 array ('invalid journal field count')
  content='STS6|' || pieces[2] || '|' || pieces[3] || '|' || pieces[4] || '|' || pieces[5]
  fields=.array~new
  do i=1 to n
    encoded=pieces[i+5]
    if encoded~length//2 \= 0 | \verify(encoded,'0123456789ABCDEF') == 0 then raise syntax 93.900 array ('invalid hex journal field')
    fields~append(x2c(encoded))
    content=content || '|' || encoded
  end
  if self~checksum(content) \== pieces[pieces~items-1] then raise syntax 93.900 array ('journal checksum mismatch')
  return self~entry(pieces[4],fields)

/* Lightweight corruption detector. DO NOT USE AS A SECURITY SIGNATURE. */
::method checksum private
  use strict arg value
  numeric digits 30
  h=2166136261
  do i=1 to value~length
    h=(h*16777619+c2d(substr(value,i,1)))//4294967291
  end
  return h
