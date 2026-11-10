/* OrderGate.cls -- every instruction an agent receives is handled as an order, in four steps:
 *
 *   1. Is it an order?         the recipient's READER says CLEAR, REQUIRES CLARIFICATION, NOT AN ORDER, or NOTED
 *                              (an order that only says what not to do: recorded, nothing to execute)
 *   2. Is the order lawful?    Legal Effect (ChatGPT's normative engine) evaluates the order's action against
 *                              the recipient's sealed rules of engagement: ADMISSIBLE, CONDITIONAL, BLOCKED or
 *                              REVIEW_REQUIRED (an unknown fact, or a rule that asks for review, goes up the chain)
 *   3. Execute                 only CLEAR and ADMISSIBLE; the recipient's EXECUTOR does the work
 *   4. Report                  both verdicts, the rules that decided, the decision-trace id, the result
 *
 * Architecture: Tom Dyer ("clarify the order is an order; clarify its legality; execute; report").
 * Coding: Claude (Opus 5.5), 9 November 2026.  Legal Effect v0.14: ChatGPT.
 *
 * Why: agents differ on how clear an instruction must be before they act (Claude Code and Codex disagree), and
 * guard rails applied ad hoc are inconsistent.  One gate, one reader and one rule set per recipient make the
 * threshold the same every time, and every decision carries a trace saying which rule decided it.
 *
 * Plug-ins (one object each, registered with the gate):
 *   reader    ~read(order)            -> .directory: verdict, reasons (.array), action (LegalAction),
 *                                        facts (.directory of fact name -> .true/.false/value)
 *   rules     ~generation             -> a SEALED LegalRuleGeneration (the recipient's rules of engagement)
 *   executor  ~execute(order, reading, gate) -> .directory: ok (.true/.false), lines (.array)
 * The gate's ~assess(actionCode, facts, eventId) is public, so an executor can re-check a changed situation
 * mid-task (ALCHEMYFETCH re-checks every redirect: a new target is a new engagement).
 */

::class GateOrder public
::attribute id get
::attribute issuer get
::attribute recipient get
::attribute text get
::method init
  expose id issuer recipient text
  use strict arg id, issuer, recipient, text

::class GateAssessment public
::attribute status get
::attribute deciding get
::attribute open get
::attribute traceId get
::attribute traceFile get
::method init
  expose status deciding open traceId traceFile
  use strict arg status, deciding, open, traceId, traceFile

::class OrderGate public
::attribute name get
::method init
  expose name reader rules executor log traceDir
  use strict arg name, reader, rules, executor, log, traceDir
  address system 'mkdir -p' gateQ(traceDir) '&& chmod 700' gateQ(traceDir)

/* Step 2, also used mid-task: evaluate an action with the given facts against the rules. */
::method assess
  expose name rules traceDir log
  use strict arg actionCode, facts, eventId
  fs=.LegalFactSet~new
  do k over facts~allIndexes
    x=fs~putKnown(k, facts[k])
  end
  today=date('S')
  day=today~left(4)'-'today~substr(5, 2)'-'today~right(2)
  ctx=.LegalContext~new(eventId, day, day, fs)
  act=.LegalAction~new(actionCode, name 'order' eventId)
  r=.LegalEffectEngine~new~evaluate(act, rules~generation, ctx)
  if \r~ok then return .GateAssessment~new('REVIEW_REQUIRED', .array~new, .array~of('the rules could not be evaluated:' r~code r~message), '', '')
  a=r~value
  deciding=.array~new
  do m over a~effectiveMatches
    deciding~append(m~norm~normId '('m~norm~disposition'):' m~norm~rationale)
  end
  open=.array~new
  do m over a~unresolved
    open~append(m~norm~normId':' m~reasons~makeString('L', '; '))
  end
  /* the full decision trace is kept; its sha256 is the id quoted in reports and the ledger */
  safe=eventId~translate('_', '/\:*?"<>| ')
  file=traceDir'/'safe'-'actionCode'-'time('L')~changeStr(':', '')~changeStr('.', '')'.trace'
  call lineout file, a~decisionTrace~traceIdentity
  call lineout file
  address system 'sha256sum' gateQ(file) with output stem o.
  tid=''
  if o.0>0 then tid=o.1~word(1)~left(16)
  log~info(name 'rules of engagement:' actionCode 'is' a~status 'trace' tid)
  return .GateAssessment~new(a~status, deciding, open, tid, file)

/* All four steps.  Returns the report as an .array of lines (the text that goes back to the issuer). */
::method process
  expose name reader rules executor log
  use strict arg order
  rep=.array~new
  rep~append(name 'order' order~id 'from' order~issuer)
  log~info(name 'order' order~id 'from' order~issuer': reading')
  /* 1. is it an order? */
  reading=reader~read(order)
  rep~append('1. Order:' reading['verdict'])
  do l over reading['reasons']
    rep~append('   'l)
  end
  if reading['verdict']=='NOTED' then do
    rep~append('Noted; nothing to execute.')
    log~info(name 'order' order~id': noted')
    return rep
  end
  if reading['verdict']<>'CLEAR' then do
    rep~append('Not executed: the order needs clarification first.')
    log~info(name 'order' order~id':' reading['verdict'])
    return rep
  end
  /* 2. is it lawful? */
  g=self~assess(reading['action']~actionCode, reading['facts'], order~id)
  rep~append('2. Rules of engagement:' g~status '(decision trace' g~traceId')')
  do l over g~deciding
    rep~append('   'l)
  end
  do l over g~open
    rep~append('   unresolved' l)
  end
  select
    when g~status=='ADMISSIBLE' then nop
    when g~status=='REVIEW_REQUIRED' then do
      rep~append('Not executed: referred up the chain for review (TOM).')
      return rep
    end
    otherwise do
      rep~append('Not executed.')
      return rep
    end
  end
  /* 3. execute */
  log~info(name 'order' order~id': executing')
  res=executor~execute(order, reading, self)
  if res['ok'] then rep~append('3. Executed.')
  else rep~append('3. Execution stopped.')
  do l over res['lines']
    rep~append('   'l)
  end
  /* 4. report: this array */
  log~info(name 'order' order~id': reported (' || rep~items 'lines)')
  return rep

::routine gateQ public
  use strict arg s
  return "'"s~changeStr("'", "'\''")"'"

::requires 'LegalEffect.cls'
