/* Single Time Service v0.4: bounded, transport-neutral civil recurrence.
 * A local wall-time intention is kept independently from its UTC projections.
 * No side effects, scheduler, network or Queue Fabric dependency.
 */
::requires 'SingleTime.cls'

::class 'TimeRecurrenceSpec' public
::method init
  expose identifier zone anchorIso frequency interval weekdays gapPolicy foldPolicy anchorCoord anchorDay anchorWeek weekdayMask
  use strict arg identifier, zone, anchorIso, frequency = 'DAILY', interval = 1, weekdays = '', gapPolicy = 'SKIP', foldPolicy = 'EARLIER'
  numeric digits 30
  if identifier == '' | zone == '' then raise syntax 93.900 array ('recurrence identity and zone required')
  if \datatype(interval,'W') then raise syntax 93.900 array ('recurrence interval must be integer')
  if interval < 1 | interval > 366 then raise syntax 93.900 array ('recurrence interval outside bound 1..366')
  frequency = frequency~translate
  gapPolicy = gapPolicy~translate
  foldPolicy = foldPolicy~translate
  if frequency \= 'DAILY' & frequency \= 'WEEKLY' then raise syntax 93.900 array ('only DAILY and WEEKLY recurrence supported')
  if gapPolicy \= 'SKIP' & gapPolicy \= 'RECORD' & gapPolicy \= 'REJECT' then raise syntax 93.900 array ('gap policy must be SKIP, RECORD or REJECT')
  if foldPolicy \= 'EARLIER' & foldPolicy \= 'LATER' & foldPolicy \= 'BOTH' & foldPolicy \= 'REJECT' then raise syntax 93.900 array ('fold policy must be EARLIER, LATER, BOTH or REJECT')
  anchorCoord = .IsoCivilClock~parseLocal(anchorIso)~coordinate
  anchorDay = anchorCoord % 86400
  anchorWeek = anchorDay - self~weekdayNumber(anchorDay) + 1
  if frequency == 'DAILY' & weekdays \== '' then raise syntax 93.900 array ('weekday mask is only supported for WEEKLY')
  mask = .table~new
  if weekdays == '' & frequency == 'WEEKLY' then do
    mask[self~weekdayNumber(anchorDay)] = .true
  end
  else if weekdays \== '' then do
    remains = weekdays~translate
    do while remains \== ''
      parse var remains token ',' remains
      if token == '' then raise syntax 93.900 array ('empty weekday token')
      select
        when token == 'MO' then day = 1
        when token == 'TU' then day = 2
        when token == 'WE' then day = 3
        when token == 'TH' then day = 4
        when token == 'FR' then day = 5
        when token == 'SA' then day = 6
        when token == 'SU' then day = 7
        otherwise raise syntax 93.900 array ('invalid weekday token')
      end
      if mask~hasIndex(day) then raise syntax 93.900 array ('duplicate weekday token')
      mask[day] = .true
    end
    if right(weekdays,1) == ',' then raise syntax 93.900 array ('trailing weekday separator')
  end
  weekdayMask = mask
::attribute identifier get
::attribute zone get
::attribute anchorIso get
::attribute frequency get
::attribute interval get
::attribute weekdays get
::attribute gapPolicy get
::attribute foldPolicy get
::attribute anchorCoord get
::attribute anchorDay get
::attribute anchorWeek get
::attribute weekdayMask get

::method weekdayNumber private
  use strict arg dayIndex
  numeric digits 30
  /* ISO 1..7, 1970-01-01 was Thursday (4). Normalise negative mod. */
  x = (dayIndex + 3) // 7
  if x < 0 then x += 7
  return x + 1

::method appliesToDay
  expose frequency anchorDay anchorWeek interval weekdayMask
  use strict arg day
  numeric digits 30
  if day < anchorDay then return .false
  if frequency == 'DAILY' then return ((day-anchorDay) // interval) = 0
  monday = day - self~weekdayNumber(day) + 1
  weekDistance = (monday-anchorWeek) % 7
  if weekDistance < 0 then return .false
  if (weekDistance // interval) \= 0 then return .false
  return weekdayMask~hasIndex(self~weekdayNumber(day))

/* Each projected occurrence is evidence of a recurrence decision, not a job.
 * A GAP/RECORD entry has NO instant and must not be dispatched. */
::class 'TimeOccurrence' public
::method init
  expose recurrenceId zone localIso status instant edition offsetSeconds abbreviation selection
  use strict arg recurrenceId, zone, localIso, status, instant, edition, offsetSeconds, abbreviation, selection
::attribute recurrenceId get
::attribute zone get
::attribute localIso get
::attribute status get
::attribute instant get
::attribute edition get
::attribute offsetSeconds get
::attribute abbreviation get
::attribute selection get
::method asRecord
  expose recurrenceId zone localIso status instant edition offsetSeconds abbreviation selection
  row = .directory~new
  row['recurrenceId'] = recurrenceId
  row['zone'] = zone
  row['local'] = localIso
  row['status'] = status
  row['selection'] = selection
  row['tzdbEdition'] = edition
  row['instantPosixSeconds'] = .nil
  row['offsetSeconds'] = .nil
  row['abbreviation'] = ''
  if instant \== .nil then do
    row['instantPosixSeconds'] = instant~ticks
    row['offsetSeconds'] = offsetSeconds
    row['abbreviation'] = abbreviation
  end
  return row

::class 'TimeRecurrenceEngine' public
::attribute service get
::method init
  expose service
  use strict arg service
  if \service~hasMethod('resolveIsoLocal') then raise syntax 93.900 array ('SingleTimeService required')

/* Inclusive local civil window [fromIso,throughIso], bounded by maxDays.
 * No system clock consulted. Failure across incomplete tzdb coverage propagates.
 * maxRecords is an output safety ceiling; reaching it raises, never truncates. */
::method expand
  expose service
  use strict arg spec, fromIso, throughIso, maxDays = 366, maxRecords = 2000
  numeric digits 30
  if \spec~isA(.TimeRecurrenceSpec) then raise syntax 93.900 array ('TimeRecurrenceSpec required')
  if \datatype(maxDays,'W') | \datatype(maxRecords,'W') then raise syntax 93.900 array ('integer expansion limits required')
  if maxDays < 1 | maxDays > 3660 | maxRecords < 1 | maxRecords > 10000 then raise syntax 93.900 array ('recurrence expansion limits exceeded')
  first = .IsoCivilClock~parseLocal(fromIso)~coordinate
  last = .IsoCivilClock~parseLocal(throughIso)~coordinate
  if last < first then raise syntax 93.900 array ('recurrence window reversed')
  startDay = first % 86400
  endDay = last % 86400
  if endDay - startDay + 1 > maxDays then raise syntax 93.900 array ('recurrence window exceeds maxDays')
  occurrences = .array~new
  baseSeconds = spec~anchorCoord - spec~anchorDay*86400
  edition = service~rulesFor(spec~zone)~edition
  do day = startDay to endDay
    if \spec~appliesToDay(day) then iterate
    coordinate = day*86400+baseSeconds
    if coordinate < first | coordinate > last | coordinate < spec~anchorCoord then iterate
    local = .IsoCivilClock~formatLocal(.TimeLocalReading~new(coordinate))
    resolution = service~resolveIsoLocal(spec~zone, local)
    select
      when resolution~status == 'GAP' then do
        select
          when spec~gapPolicy == 'REJECT' then raise syntax 93.900 array ('recurrence encountered nonexistent local time' local)
          when spec~gapPolicy == 'RECORD' then do
            occurrences~append(.TimeOccurrence~new(spec~identifier,spec~zone,local,'GAP',.nil,edition,.nil,'','NONE'))
          end
          otherwise nop
        end
      end
      when resolution~status == 'FOLD' then do
        if spec~foldPolicy == 'REJECT' then raise syntax 93.900 array ('recurrence encountered ambiguous local time' local)
        if spec~foldPolicy == 'BOTH' then do
          do i=1 to resolution~candidates~items
            inst=resolution~candidates[i]
            occurrences~append(self~occurrence(spec,local,'FOLD',inst,edition,'CANDIDATE:' || i))
          end
        end
        else do
          inst = resolution~choose(spec~foldPolicy)
          occurrences~append(self~occurrence(spec,local,'FOLD',inst,edition,spec~foldPolicy))
        end
      end
      otherwise do
        inst = resolution~choose('ONLY')
        occurrences~append(self~occurrence(spec,local,'UNIQUE',inst,edition,'ONLY'))
      end
    end
    if occurrences~items > maxRecords then raise syntax 93.900 array ('recurrence results exceed maxRecords')
  end
  return occurrences

::method occurrence private
  expose service
  use strict arg spec, local, status, inst, edition, selection
  return .TimeOccurrence~new(spec~identifier,spec~zone,local,status,inst,edition,service~offsetAt(spec~zone,inst),service~abbreviationAt(spec~zone,inst),selection)
