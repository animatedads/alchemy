/* v0.4: narrow semantic endpoint, independent of any connector dependency.
 * ConnectSelector's ConnectCallAdapter uses request(name,params) and notify().
 * RPC Service Core can explicitly publish individual methods on the same object.
 * No implicit system clock, no remote execution, no automatic enqueue.
 */
::requires 'TimeImpactAnalysis.cls'

::class 'TimeEndpointReply' public
::method init
  expose ok result fault
  use strict arg ok, result, fault = .nil
::attribute ok get
::attribute result get
::attribute fault get

::class 'TimeServiceEndpoint' public
::method init
  expose service engine catalog
  use strict arg service, catalog = .nil
  if \service~hasMethod('resolveIsoLocal') then raise syntax 93.900 array ('time service required')
  if catalog \== .nil then do
    if \catalog~isA(.TimeEventCatalog) & \catalog~isA(.TimeAuthorityLedger) then raise syntax 93.900 array ('TimeEventCatalog or TimeAuthorityLedger required')
  end
  engine = .TimeRecurrenceEngine~new(service)

/* RPC Service Core registration is opt-in; the consumer supplies its own
 * RpcServiceRegistry and controls freeze/authentication/lifecycle. */
::method publishTo
  use strict arg registry
  mapping=.table~new
  mapping['zone.resolve']='zoneResolve'
  mapping['zone.compare']='zoneCompare'
  mapping['recurrence.expand']='recurrenceExpand'
  mapping['event.resolve']='eventResolve'
  mapping['authority.info']='authorityInfo'
  mapping['impact.analyze']='impactAnalyze'
  registry~registerObject('time',self,mapping)
  return self

::method required private
  use strict arg args, key
  if \(args~isA(.Directory) | args~isA(.Table)) then raise syntax 93.900 array ('argument map required')
  if \args~hasIndex(key) then raise syntax 93.900 array ('missing required field' key)
  value = args[key]
  if value == .nil then raise syntax 93.900 array ('nil required field' key)
  return value
::method optional private
  use strict arg args, key, fallback
  if \(args~isA(.Directory) | args~isA(.Table)) then raise syntax 93.900 array ('argument map required')
  if \args~hasIndex(key) then return fallback
  return args[key]

::method zoneResolve
  expose service
  use strict arg args, context = .nil
  numeric digits 30
  zone=self~required(args,'zone')
  local=self~required(args,'local')
  r=service~resolveIsoLocal(zone,local)
  row=.directory~new
  row['status']=r~status
  row['zone']=zone
  row['local']=local
  row['tzdbEdition']=service~rulesFor(zone)~edition
  choices=.array~new
  do inst over r~candidates
    candidate=.directory~new
    candidate['instantPosixSeconds']=inst~ticks
    candidate['offsetSeconds']=service~offsetAt(zone,inst)
    candidate['abbreviation']=service~abbreviationAt(zone,inst)
    choices~append(candidate)
  end
  row['candidates']=choices
  return row

::method zoneCompare
  expose service
  use strict arg args, context = .nil
  numeric digits 30
  from=self~required(args,'fromZone')
  to=self~required(args,'toZone')
  instant=.TimeInstant~new(self~required(args,'instantPosixSeconds'))
  return service~explainDifferenceAt(from,to,instant)

::method recurrenceExpand
  expose engine
  use strict arg args, context = .nil
  identifier=self~required(args,'id')
  zone=self~required(args,'zone')
  anchor=self~required(args,'anchorLocal')
  from=self~required(args,'fromLocal')
  through=self~required(args,'throughLocal')
  frequency=self~optional(args,'frequency','DAILY')
  interval=self~optional(args,'interval',1)
  weekdays=self~optional(args,'weekdays','')
  gapPolicy=self~optional(args,'gapPolicy','SKIP')
  foldPolicy=self~optional(args,'foldPolicy','EARLIER')
  maxDays=self~optional(args,'maxDays',366)
  maxRecords=self~optional(args,'maxRecords',2000)
  spec=.TimeRecurrenceSpec~new(identifier,zone,anchor,frequency,interval,weekdays,gapPolicy,foldPolicy)
  projected=engine~expand(spec,from,through,maxDays,maxRecords)
  rows=.array~new
  do occurrence over projected
    rows~append(occurrence~asRecord)
  end
  reply=.directory~new
  reply['id']=identifier
  reply['zone']=zone
  reply['anchorLocal']=anchor
  reply['frequency']=spec~frequency
  reply['interval']=spec~interval
  reply['weekdays']=spec~weekdays
  reply['gapPolicy']=spec~gapPolicy
  reply['foldPolicy']=spec~foldPolicy
  reply['tzdbEdition']=engine~service~rulesFor(zone)~edition
  reply['occurrences']=rows
  reply['generatedCount']=rows~items
  return reply

/* Resolve a human-facing named intention within an explicit institution and date.
 * The catalog owns dynamic meaning registration, not RPC or the scheduler. */
::method eventResolve
  expose service catalog
  use strict arg args, context = .nil
  if catalog == .nil then raise syntax 93.900 array ('no institutional event catalog configured')
  institution=self~required(args,'institution')
  phrase=self~required(args,'phrase')
  onDate=self~required(args,'onDate')
  asOf=self~optional(args,'asOfRevision',.nil)
  if catalog~isA(.TimeAuthorityLedger) then do
    if asOf == .nil then return catalog~resolveCurrent(institution,phrase,onDate,service)
    return catalog~resolveAt(institution,phrase,onDate,service,asOf)
  end
  if asOf \== .nil then raise syntax 93.900 array ('historical revision requires an authority ledger')
  return catalog~resolve(institution,phrase,onDate,service)

/* Read-only metadata, intentionally excluding the local journal path. */
::method authorityInfo
  expose catalog
  use strict arg args, context = .nil
  if \(args~isA(.Directory) | args~isA(.Table)) then raise syntax 93.900 array ('argument map required')
  if catalog == .nil | \catalog~isA(.TimeAuthorityLedger) then raise syntax 93.900 array ('no journal authority')
  answer=.directory~new
  answer['revision']=catalog~revision
  answer['headChecksum']=catalog~headChecksum
  answer['integrity']='ACCIDENTAL_CORRUPTION_ONLY'
  answer['durability']='CLOSE_NO_FSYNC'
  answer['writerModel']='SINGLE_WRITER'
  return answer

/* Compare two committed definition snapshots. The endpoint uses one injected
 * timezone service for both: a different TZif dataset MUST be supplied to
 * TimeImpactAnalyzer explicitly by trusted local code, not remote paths. */
::method impactAnalyze
  expose catalog service
  use strict arg args, context = .nil
  if catalog == .nil | \catalog~isA(.TimeAuthorityLedger) then raise syntax 93.900 array ('authority journal required for impact analysis')
  institution=self~required(args,'institution')
  phrase=self~required(args,'phrase')
  fromDate=self~required(args,'fromDate')
  throughDate=self~required(args,'throughDate')
  fromRevision=self~required(args,'fromRevision')
  toRevision=self~required(args,'toRevision')
  maxDays=self~optional(args,'maxDays',31)
  analyzer=.TimeImpactAnalyzer~new(catalog,service)
  return analyzer~compare(institution,phrase,fromDate,throughDate,fromRevision,toRevision,maxDays)

/* This is the DIRECT adapter's bounded request contract; it does not
 * interpret remote-supplied class or ooRexx method names. */
::method request
  use strict arg operation, args
  signal on syntax name rejected
  select
    when operation == 'time.zone.resolve' then value=self~zoneResolve(args)
    when operation == 'time.zone.compare' then value=self~zoneCompare(args)
    when operation == 'time.recurrence.expand' then value=self~recurrenceExpand(args)
    when operation == 'time.event.resolve' then value=self~eventResolve(args)
    when operation == 'time.authority.info' then value=self~authorityInfo(args)
    when operation == 'time.impact.analyze' then value=self~impactAnalyze(args)
    otherwise return .TimeEndpointReply~new(.false,.nil,'NOT_FOUND')
  end
  signal off syntax
  return .TimeEndpointReply~new(.true,value)
rejected:
  signal off syntax
  /* Do not expose server implementation diagnostics via an endpoint. */
  return .TimeEndpointReply~new(.false,.nil,'INVALID_ARGUMENT_OR_RULE_COVERAGE')

::method notify
  use strict arg operation, args
  /* A notification is never proof of recurrence persistence or dispatch. */
  return .false
