/* Single Time Service — semantic core, v0.3.
   TZif rule providers are injected. POSIX future rules are not yet expanded.
   No global TZ/environment mutation and no Queue Fabric dependency. */

::class 'TimeInstant' public
::method init
  expose ticks scale
  use strict arg ticks, scale = 'POSIX'
  numeric digits 20
  if \datatype(ticks, 'W') then raise syntax 93.900 array ('integer second count required')
  if scale \= 'POSIX' then raise syntax 93.900 array ('unsupported timescale')
  self~ticks = ticks
  self~scale = scale
::attribute ticks
::attribute scale
::method elapsedSecondsTo
  use strict arg other
  numeric digits 20
  return other~ticks - self~ticks

::class 'TimeZonePeriod' public
::method init
  expose begins offset abbreviation
  use strict arg begins, offset, abbreviation
  numeric digits 20
  if \datatype(begins,'W') | \datatype(offset,'W') then raise syntax 93.900 array ('integer seconds required')
  self~begins = begins
  self~offset = offset
  self~abbreviation = abbreviation
::attribute begins
::attribute offset
::attribute abbreviation

::class 'TimeZoneRules' public
::method init
  expose identifier periods coverageEnd edition sourcePath posixTail
  use strict arg identifier
  numeric digits 20
  self~identifier = identifier
  periods = .array~new
  coverageEnd = .nil
  edition = 'UNKNOWN'
  sourcePath = 'INJECTED'
  posixTail = ''
::attribute identifier
::attribute coverageEnd
::attribute edition
::attribute sourcePath
::attribute posixTail
::method setAuthority
  expose edition sourcePath posixTail coverageEnd
  use strict arg edition, sourcePath, posixTail, coverageEnd
  return self
::method addPeriod
  expose periods
  use strict arg begins, offset, abbreviation
  numeric digits 20
  p = .TimeZonePeriod~new(begins, offset, abbreviation)
  if periods~items > 0 then do
    previous = periods[periods~items]
    if begins <= previous~begins then raise syntax 93.900 array ('periods must be added in ascending order')
  end
  periods~append(p)
  return self
::method periodAt
  expose periods identifier coverageEnd
  use strict arg instant
  numeric digits 30
  if periods~items = 0 then raise syntax 93.900 array ('no rules for' identifier)
  if coverageEnd \== .nil then do
    if instant~ticks >= coverageEnd then raise syntax 93.900 array ('instant outside documented future coverage for' identifier)
  end
  low = 1; high = periods~items
  if instant~ticks < periods[1]~begins then raise syntax 93.900 array ('instant outside rule coverage for' identifier)
  do while low < high
    mid = (low + high + 1) % 2
    if periods[mid]~begins <= instant~ticks then low = mid
    else high = mid - 1
  end
  return periods[low]

::method periodCount
  expose periods
  return periods~items
::method periodNumber
  expose periods
  use strict arg n
  return periods[n]
::method resolveLocal
  expose periods identifier coverageEnd
  use strict arg reading
  numeric digits 30
  coordinate = reading~coordinate
  candidates = .array~new
  /* Near an unexpanded POSIX future-rule boundary, resolution is unknown,
     not GAP. Protect both offsets of the final transition. */
  if coverageEnd \== .nil then do
    if coordinate >= coverageEnd - 86400 then raise syntax 93.900 array ('local reading beyond documented future coverage for' identifier)
  end
  do i = 1 to periods~items
    p = periods[i]
    candidate = coordinate - p~offset
    if candidate < p~begins then iterate
    if coverageEnd \== .nil then do
      if candidate >= coverageEnd then iterate
    end
    if i < periods~items then do
      nextPeriod = periods[i + 1]
      if candidate >= nextPeriod~begins then iterate
    end
    /* Insert-sort all candidates; historical rule data can have >2. */
    candidates~append(.TimeInstant~new(candidate))
    do j = candidates~items to 2 by -1
      if candidates[j - 1]~ticks <= candidates[j]~ticks then leave
      temp = candidates[j - 1]
      candidates[j - 1] = candidates[j]
      candidates[j] = temp
    end
  end
  return .TimeResolution~new(identifier,coordinate,candidates)

::class 'SingleTimeService' public
::method init
  expose zones
  zones = .directory~new
::method registerZone
  expose zones
  use strict arg rules
  numeric digits 20
  if zones~hasIndex(rules~identifier) then raise syntax 93.900 array ('already registered zone' rules~identifier)
  zones[rules~identifier] = rules
  return self
::method rulesFor
  expose zones
  use strict arg identifier
  numeric digits 20
  if \zones~hasIndex(identifier) then raise syntax 93.900 array ('unregistered zone' identifier)
  return zones[identifier]
::method zoneMetadata
  use strict arg identifier
  rules = self~rulesFor(identifier)
  info = .directory~new
  info['identifier'] = rules~identifier
  info['edition'] = rules~edition
  info['sourcePath'] = rules~sourcePath
  info['posixTail'] = rules~posixTail
  info['coverageEnd'] = rules~coverageEnd
  info['periodCount'] = rules~periodCount
  return info
::method offsetAt
  use strict arg identifier, instant
  numeric digits 20
  return (self~rulesFor(identifier)~periodAt(instant))~offset
::method abbreviationAt
  use strict arg identifier, instant
  numeric digits 20
  return (self~rulesFor(identifier)~periodAt(instant))~abbreviation
::method differenceAt
  use strict arg fromZone, toZone, instant
  numeric digits 20
  return self~offsetAt(toZone, instant) - self~offsetAt(fromZone, instant)
::method explainDifferenceAt
  use strict arg fromZone, toZone, instant
  numeric digits 30
  fromRules=self~rulesFor(fromZone)
  toRules=self~rulesFor(toZone)
  fromPeriod=fromRules~periodAt(instant)
  toPeriod=toRules~periodAt(instant)
  snapshot=.directory~new
  snapshot['instantPosixSeconds']=instant~ticks
  snapshot['fromZone']=fromZone
  snapshot['toZone']=toZone
  snapshot['fromLocal']=self~isoLocalAt(fromZone,instant)
  snapshot['toLocal']=self~isoLocalAt(toZone,instant)
  snapshot['fromOffsetSeconds']=fromPeriod~offset
  snapshot['toOffsetSeconds']=toPeriod~offset
  snapshot['fromAbbreviation']=fromPeriod~abbreviation
  snapshot['toAbbreviation']=toPeriod~abbreviation
  snapshot['fromEdition']=fromRules~edition
  snapshot['toEdition']=toRules~edition
  snapshot['differenceSeconds']=toPeriod~offset-fromPeriod~offset
  return snapshot
::method resolveLocal
  use strict arg identifier, reading
  return (self~rulesFor(identifier))~resolveLocal(reading)
::method resolveIsoLocal
  use strict arg identifier, isoLocal
  return self~resolveLocal(identifier,.IsoCivilClock~parseLocal(isoLocal))
::method isoLocalAt
  use strict arg identifier, instant
  return .IsoCivilClock~formatLocal(.TimeLocalReading~new(self~localEpochSecondAt(identifier, instant)))
::method transitionsBetween
  use strict arg identifier, startInstant, endInstant
  numeric digits 20
  rules = self~rulesFor(identifier)
  changes = .array~new
  if endInstant~ticks < startInstant~ticks then raise syntax 93.900 array ('invalid interval')
  if rules~coverageEnd \== .nil then do
    if endInstant~ticks > rules~coverageEnd then raise syntax 93.900 array ('transition interval outside documented future coverage')
  end
  do i = 2 to rules~periodCount
    p = rules~periodNumber(i)
    if p~begins >= startInstant~ticks & p~begins < endInstant~ticks then changes~append(p)
  end
  return changes

::method localEpochSecondAt
  use strict arg identifier, instant
  numeric digits 20
  return instant~ticks + self~offsetAt(identifier, instant)


/* A local civil reading expressed as a naive POSIX-like epoch count, with
   no assumed timezone. This is a coordinate, NOT an absolute instant. */
::class 'TimeLocalReading' public
::method init
  use strict arg coordinate
  numeric digits 20
  if \datatype(coordinate,'W') then raise syntax 93.900 array ('integer local coordinate required')
  self~coordinate = coordinate
::attribute coordinate

::class 'TimeResolution' public
::method init
  expose candidates status zone coordinate
  use strict arg zone, coordinate, candidates
  self~zone = zone
  self~coordinate = coordinate
  self~candidates = candidates
  select
    when candidates~items = 0 then status = 'GAP'
    when candidates~items = 1 then status = 'UNIQUE'
    otherwise status = 'FOLD'
  end
::attribute zone
::attribute coordinate
::attribute candidates
::attribute status
::method choose
  expose candidates status
  use strict arg policy
  if status = 'UNIQUE' then return candidates[1]
  if status = 'GAP' then raise syntax 93.900 array ('local civil time does not exist')
  select
    when policy = 'EARLIER' then return candidates[1]
    when policy = 'LATER' then return candidates[candidates~items]
    otherwise raise syntax 93.900 array ('ambiguous local time: choose EARLIER or LATER')
  end

/* ISO 8601 extended local date/time in the proleptic Gregorian calendar.
   Strict whole seconds only. This does not imply a timezone or an instant.
   Dates 0001-01-01 through 9999-12-31 are supported. */
::class 'IsoCivilClock' public
::method parseLocal class
  use strict arg value
  numeric digits 30
  if length(value) \= 19 then raise syntax 93.900 array ('local ISO time must be YYYY-MM-DDTHH:MM:SS')
  if substr(value,5,1) \= '-' | substr(value,8,1) \= '-' | substr(value,11,1) \= 'T' | substr(value,14,1) \= ':' | substr(value,17,1) \= ':' then raise syntax 93.900 array ('invalid local ISO separators')
  digits = substr(value,1,4)||substr(value,6,2)||substr(value,9,2)||substr(value,12,2)||substr(value,15,2)||substr(value,18,2)
  if verify(digits,'0123456789') \= 0 then raise syntax 93.900 array ('ISO date components must be decimal digits')
  yy=substr(value,1,4)+0; mm=substr(value,6,2)+0; dd=substr(value,9,2)+0
  hh=substr(value,12,2)+0; mi=substr(value,15,2)+0; ss=substr(value,18,2)+0
  if yy<1 | yy>9999 | mm<1 | mm>12 | hh>23 | mi>59 | ss>59 then raise syntax 93.900 array ('ISO date/time component out of range')
  monthDays=.array~of(31,28,31,30,31,30,31,31,30,31,30,31)
  maxDay=monthDays[mm]
  if mm=2 & ((yy//4=0 & yy//100\=0) | yy//400=0) then maxDay=29
  if dd<1 | dd>maxDay then raise syntax 93.900 array ('invalid Gregorian day')
  /* Howard Hinnant's Gregorian days-from-civil arithmetic,
     applied to positive years; days are relative to 1970-01-01. */
  y=yy
  if mm<=2 then y-=1
  era=y%400; yoe=y-era*400
  if mm>2 then mp=mm-3
  else mp=mm+9
  doy=(153*mp+2)%5 +dd-1
  doe=yoe*365 + yoe%4 -yoe%100 +doy
  days=era*146097 + doe - 719468
  return .TimeLocalReading~new(days*86400 +hh*3600 +mi*60 +ss)

::method formatLocal class
  use strict arg reading
  numeric digits 30
  if \datatype(reading~coordinate,'W') then raise syntax 93.900 array ('integer civil coordinate expected')
  t=reading~coordinate
  days=t%86400
  daySecond=t-days*86400
  if daySecond<0 then do
    days-=1; daySecond+=86400
  end
  z=days+719468
  if z<0 then raise syntax 93.900 array ('year outside Gregorian range')
  era=z%146097; doe=z-era*146097
  yoe=(doe-doe%1460+doe%36524-doe%146096)%365
  y=yoe+era*400
  doy=doe-(365*yoe+yoe%4-yoe%100)
  mp=(5*doy+2)%153
  d=doy-(153*mp+2)%5+1
  if mp<10 then m=mp+3
  else m=mp-9
  if m<=2 then y+=1
  if y<1 | y>9999 then raise syntax 93.900 array ('year outside Gregorian range')
  hh=daySecond%3600
  mi=(daySecond-hh*3600)%60
  ss=daySecond-hh*3600-mi*60
  return right('0000'||y,4)||'-'||right('00'||m,2)||'-'||right('00'||d,2)||'T'||right('00'||hh,2)||':'||right('00'||mi,2)||':'||right('00'||ss,2)
