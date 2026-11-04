/* Single Time Service v0.5: contextual events and named temporal intentions.
 * Scheduling is an external concern. This code only resolves meaning and
 * projects civil occurrences through the existing timezone rule authority.
 * Calendar closure is never silently overridden by an event-level change.
 */
::requires 'TimeRecurrence.cls'

/* An institution's local civil calendar; closed dates are explicit facts,
 * not guessed from weekends, locale, country, or an untrusted host clock. */
::class 'TimeInstitutionCalendar' public
::method init
  expose identifier zone revision closures revisionCounter
  use strict arg identifier, zone, revision
  if identifier == '' | zone == '' | revision == '' then raise syntax 93.900 array ('calendar identifier, timezone and revision required')
  closures=.table~new
  revisionCounter=0
::attribute authorityVersion get
  expose revision revisionCounter
  return revision || "/" || revisionCounter
::attribute identifier get
::attribute zone get
::attribute revision get
::method closeDate
  expose closures revisionCounter
  use strict arg date, reason
  if reason == '' then raise syntax 93.900 array ('calendar closure requires a reason')
  self~validateDate(date)
  closures[date]=reason
  revisionCounter+=1
  return self
::method closureReason
  expose closures
  use strict arg date
  self~validateDate(date)
  if closures~hasIndex(date) then return closures[date]
  return .nil
::method validateDate
  use strict arg date
  if date~length \= 10 then raise syntax 93.900 array ('date must be YYYY-MM-DD')
  reading=.IsoCivilClock~parseLocal(date || 'T00:00:00')
  return .true

/* Named event with an explicitly dated weekly/daily local-time intention.
 * Changes require an explicit exception reason. Duration is elapsed seconds.
 * The institution defines whether a particular day is open. */
::class 'TimeNamedEvent' public
::method init
  expose identifier calendarId label classification startDate endDate clockTime frequency interval weekdays durationSeconds gapPolicy foldPolicy exceptions revisionCounter revision
  use strict arg identifier, calendarId, label, classification, startDate, endDate, clockTime, frequency = 'WEEKLY', interval = 1, weekdays = 'MO,TU,WE,TH,FR', durationSeconds = 1800, gapPolicy = 'RECORD', foldPolicy = 'EARLIER', revision = 'original'
  numeric digits 30
  if identifier == '' | calendarId == '' | label == '' | classification == '' then raise syntax 93.900 array ('event identity, calendar, label, classification required')
  self~validateDate(startDate)
  self~validateDate(endDate)
  if startDate > endDate then raise syntax 93.900 array ('reversed event validity interval')
  self~validateClock(clockTime)
  if \datatype(durationSeconds,'W') | durationSeconds < 0 | durationSeconds > 604800 then raise syntax 93.900 array ('invalid elapsed event duration')
  exceptions=.table~new
  if revision == '' then raise syntax 93.900 array ('event revision required')
  revisionCounter=0
  /* Validation is delegated to the existing recurrence contract. */
  check=.TimeRecurrenceSpec~new(identifier,'VALIDATION',startDate || 'T' || clockTime,frequency,interval,weekdays,gapPolicy,foldPolicy)
::attribute authorityVersion get
  expose revision revisionCounter
  return revision || "/" || revisionCounter
::attribute identifier get
::attribute calendarId get
::attribute label get
::attribute classification get
::attribute startDate get
::attribute endDate get
::attribute clockTime get
::attribute frequency get
::attribute interval get
::attribute weekdays get
::attribute durationSeconds get
::attribute gapPolicy get
::attribute foldPolicy get
::method validateDate private
  use strict arg date
  if date~length \= 10 then raise syntax 93.900 array ('date must be YYYY-MM-DD')
  p=.IsoCivilClock~parseLocal(date || 'T00:00:00')
  return .true
::method validateClock private
  use strict arg value
  if value~length \= 8 then raise syntax 93.900 array ('clock must be HH:MM:SS')
  p=.IsoCivilClock~parseLocal('2026-01-01T' || value)
  return .true
::method cancelDate
  expose exceptions startDate endDate revisionCounter
  use strict arg date, reason
  self~validateDate(date)
  if date < startDate | date > endDate | reason == '' then raise syntax 93.900 array ('invalid event cancellation')
  entry=.directory~new
  entry['kind']='CANCEL'
  entry['reason']=reason
  exceptions[date]=entry
  revisionCounter+=1
  return self
::method moveDate
  expose exceptions startDate endDate revisionCounter
  use strict arg date, clockTime, reason
  self~validateDate(date)
  self~validateClock(clockTime)
  if date < startDate | date > endDate | reason == '' then raise syntax 93.900 array ('invalid event time override')
  entry=.directory~new
  entry['kind']='MOVE'
  entry['clockTime']=clockTime
  entry['reason']=reason
  exceptions[date]=entry
  revisionCounter+=1
  return self
::method exceptionAt
  expose exceptions
  use strict arg date
  if exceptions~hasIndex(date) then return exceptions[date]
  return .nil

/* Lookup scope = named institution/context, NOT the user's physical location.
 * Each alias may denote several meanings, in which case there is no silent
 * precedence: clients receive AMBIGUOUS with all candidate identifiers. */
::class 'TimeEventCatalog' public
::method init
  expose calendars events aliases mutationCounter
  mutationCounter=0
  calendars=.table~new
  events=.table~new
  aliases=.table~new
::method registerCalendar
  expose calendars mutationCounter
  use strict arg calendar
  if \calendar~isA(.TimeInstitutionCalendar) then raise syntax 93.900 array ('calendar object required')
  if calendars~hasIndex(calendar~identifier) then raise syntax 93.900 array ('calendar already registered')
  calendars[calendar~identifier]=calendar
  mutationCounter+=1
  return self
::method calendarFor
  expose calendars
  use strict arg identifier
  if \calendars~hasIndex(identifier) then raise syntax 93.900 array ('unknown calendar')
  return calendars[identifier]
::method registerEvent
  expose events calendars mutationCounter
  use strict arg event
  if \event~isA(.TimeNamedEvent) then raise syntax 93.900 array ('event object required')
  if events~hasIndex(event~identifier) then raise syntax 93.900 array ('event already registered')
  if \calendars~hasIndex(event~calendarId) then raise syntax 93.900 array ('event calendar not registered')
  events[event~identifier]=event
  mutationCounter+=1
  return self
/* Internal replay lookup. Publishing this on the mutable base catalog does not
 * make the ledger's catalog available to remote or management callers. */
::method authorityEventFor
  expose events
  use strict arg identifier
  if \events~hasIndex(identifier) then raise syntax 93.900 array ('unknown event for replay')
  return events[identifier]
::method bindPhrase
  expose aliases calendars events mutationCounter
  use strict arg context, phrase, eventId
  if \calendars~hasIndex(context) | \events~hasIndex(eventId) then raise syntax 93.900 array ('alias requires registered calendar and event')
  if events[eventId]~calendarId \= context then raise syntax 93.900 array ('alias cannot cross institution boundary')
  key=self~aliasKey(context,phrase)
  if aliases~hasIndex(key) then ids=aliases[key]
  else ids=.array~new
  do other over ids
    if other == eventId then raise syntax 93.900 array ('duplicate alias registration')
  end
  ids~append(eventId)
  aliases[key]=ids
  mutationCounter+=1
  return self
::method unbindPhrase
  expose aliases mutationCounter
  use strict arg context, phrase, eventId
  key=self~aliasKey(context,phrase)
  if \aliases~hasIndex(key) then raise syntax 93.900 array ('unknown alias')
  old=aliases[key]
  fresh=.array~new
  found=.false
  do other over old
    if other == eventId then found=.true
    else fresh~append(other)
  end
  if \found then raise syntax 93.900 array ('alias does not bind this event')
  if fresh~items = 0 then removed=aliases~remove(key)
  else aliases[key]=fresh
  mutationCounter+=1
  return self
::attribute catalogRevision get
  expose mutationCounter
  return mutationCounter
::method aliasKey private
  use strict arg context, phrase
  if context == '' | phrase == '' | phrase~length > 200 then raise syntax 93.900 array ('context and bounded phrase required')
  return context || '/' || space(phrase~translate)

/* All results are typed record maps suitable for Direct, RPC Core or JSON.
 * Caller MUST supply a date; no hidden TODAY default or locale inference.
 * A closed institution cannot be reopened by an event-level override. */
::method resolve
  expose aliases events calendars
  use strict arg context, phrase, date, timeService
  numeric digits 30
  key=self~aliasKey(context,phrase)
  if \calendars~hasIndex(context) then return self~unresolved(context,phrase,date,'UNKNOWN_CONTEXT')
  calendar=calendars[context]
  calendar~validateDate(date)
  if \aliases~hasIndex(key) then return self~unresolved(context,phrase,date,'UNKNOWN_EXPRESSION')
  ids=aliases[key]
  if ids~items > 1 then do
    answer=self~base(context,phrase,date,'AMBIGUOUS')
    candidates=.array~new
    do item over ids
      row=.directory~new
      row['eventId']=item
      row['label']=events[item]~label
      candidates~append(row)
    end
    answer['meanings']=candidates
    return answer
  end
  event=events[ids[1]]
  answer=self~base(context,phrase,date,'RESOLVED')
  answer['eventId']=event~identifier
  answer['label']=event~label
  answer['classification']=event~classification
  answer['zone']=calendar~zone
  answer['calendarRevision']=calendar~authorityVersion
  answer['eventRevision']=event~authorityVersion
  answer['catalogRevision']=self~catalogRevision
  answer['tzdbEdition']=timeService~rulesFor(calendar~zone)~edition
  answer['elapsedDurationSeconds']=event~durationSeconds
  answer['durationKind']='ELAPSED'
  answer['occurrences']=.array~new
  if date < event~startDate | date > event~endDate then do
    answer['status']='OUT_OF_SCOPE'
    return answer
  end
  reason=calendar~closureReason(date)
  if reason \== .nil then do
    answer['status']='CLOSED'
    answer['reason']=reason
    return answer
  end
  exception=event~exceptionAt(date)
  if exception \== .nil then do
    if exception['kind'] == 'CANCEL' then do
      answer['status']='CANCELLED'
      answer['reason']=exception['reason']
      return answer
    end
    answer['reason']=exception['reason']
    clock=exception['clockTime']
    answer['exception']='MOVE'
  end
  else clock=event~clockTime
  spec=.TimeRecurrenceSpec~new(event~identifier,calendar~zone,event~startDate || 'T' || clock,event~frequency,event~interval,event~weekdays,event~gapPolicy,event~foldPolicy)
  coordinate=.IsoCivilClock~parseLocal(date || 'T00:00:00')~coordinate
  day=coordinate % 86400
  if \spec~appliesToDay(day) then do
    answer['status']='NOT_SCHEDULED'
    return answer
  end
  engine=.TimeRecurrenceEngine~new(timeService)
  rows=engine~expand(spec,date || 'T00:00:00',date || 'T23:59:59',1,16)
  projections=.array~new
  hasGap=.false
  hasFold=.false
  do occurrence over rows
    projections~append(occurrence~asRecord)
    if occurrence~status == 'GAP' then hasGap=.true
    if occurrence~status == 'FOLD' then hasFold=.true
  end
  answer['occurrences']=projections
  select
    when hasGap then answer['status']='GAP'
    when hasFold then answer['status']='FOLD'
    when projections~items = 0 then answer['status']='NOT_SCHEDULED'
    otherwise answer['status']='RESOLVED'
  end
  return answer
::method base private
  use strict arg context, phrase, date, status
  answer=.directory~new
  answer['status']=status
  answer['context']=context
  answer['phrase']=phrase
  answer['date']=date
  answer['meanings']=.array~new
  answer['occurrences']=.array~new
  return answer
::method unresolved private
  use strict arg context, phrase, date, status
  return self~base(context,phrase,date,status)
