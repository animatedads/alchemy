/* Human-only adapter for the exact estate dev7r1 controller. No referee
   objects or canonical journals cross the task boundary. Host creates an
   exclusive private run directory before binding an instance. */
::requires 'DiplomacyGame.cls'
::requires 'DiplomacyHumanTasks.cls'

::class DiplomacyHumanWorker public
::method init
  expose root filename config seed seconds started clock
  use strict arg root,filename,config,seed,seconds,clock=.nil
  if \seconds~datatype('W') | seconds<1 | seconds>604800 then raise syntax 93.900 array('Bad task duration')
  if .DiplomacyGame~module_version\=='0.1-dev7r1' then raise syntax 93.900 array('Unqualified controller')
  if stream(filename,'C','QUERY EXISTS')\=='' | stream(filename'.operator.log','C','QUERY EXISTS')\=='' then raise syntax 93.900 array('Journal already exists')
  if clock==.nil then clock=.DiplomacyTaskClock~new
  started=.false
::method makeTasks
  expose clock seconds
  use strict arg owners,gameId
  return .DiplomacyHumanTasks~new(owners,clock,seconds,gameId||'-')
::method launch
  expose root filename config seed seconds started
  use strict arg web,broker
  if started then raise syntax 93.900 array('Worker already consumed')
  started=.true
  /* Reply immediately; the activity retains the worker guard, not the web
     game's guard. HTTP/Wire and human submissions remain responsive. */
  reply 'LAUNCHED'
  signal on any name failed
  if stream(filename,'C','QUERY EXISTS')\=='' | stream(filename'.operator.log','C','QUERY EXISTS')\=='' then raise syntax 93.900 array('Journal already exists')
  board=.DiplomacyBoard~new(root'/data/standard.source')
  judge=.DiplomacyAdjudicator~new(board,root'/data/rules.conf')
  units=diplomacyInitialUnits(board,root'/data/initial-1901.source')
  journal=.DiplomacyWebJournal~new(filename,web)
  engine=.DiplomacyGame~new(board,judge,config,units,judge~initialOwnership,.DiplomacyHumanSource~new(broker,seconds),journal,seed)
  result=engine~run
  web~workerFinished(result)
  return
failed:
  signal off any
  if symbol('JOURNAL')=='VAR' then journal~close
  web~workerFinished('FAILED')
  return

::class DiplomacyHumanSource public
::method init
  expose broker seconds
  use strict arg broker,seconds
::method press
  use strict arg view
  return self~awaitTask(view,'')
::method orders
  use strict arg view
  return self~awaitTask(view,.array~new)
::method awaitTask
  expose broker seconds
  use strict arg view,empty
  id=broker~issue(view)
  if id==.nil then return .array~of('ERROR',empty)
  power=view['POWER']
  call time 'R'
  do forever
    answer=broker~take(power,id)
    if answer\==.nil then return answer
    if time('E')>=seconds then do
      /* Seal/expire race: if an accepted response won, consume it. */
      if broker~expire(power,id) then return .array~of('TIMEOUT',empty)
      answer=broker~take(power,id)
      if answer\==.nil then return answer
      return .array~of('ERROR',empty)
    end
    call sysSleep 0.05
  end
::method complete
  return

::class DiplomacyWebJournal
::method init
  expose journal web
  use strict arg filename,web
  journal=.DiplomacyGameJournal~new(filename)
::method record
  expose journal web
  use strict arg line
  journal~record(line)
  web~record(line)
::method diagnostic
  expose journal
  use strict arg location,code,line,kind,detail
  journal~diagnostic(location,code,line,kind,detail)
::method audit
  expose journal
  use strict arg payload
  journal~audit(payload)
::method close
  expose journal
  journal~close
