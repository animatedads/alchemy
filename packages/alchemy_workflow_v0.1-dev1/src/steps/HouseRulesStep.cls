/* HouseRulesStep.cls - Alchemy Workflow v0.1-dev1 step "HouseRules" (stage inspect): Tom's ooRexx house
 * rules, checked on code with comments and strings already blanked (WorkflowSource), never on raw text.
 *
 * Architecture: Tom Dyer (the rules). Code: Claude (Opus 5.5), 2026-11-11.
 *
 * Rules:
 *   HR-PRIVATE       FAIL  a private ::method or ::attribute (private methods fail across Message
 *                          activity boundaries: none in any class)
 *   HR-EXPOSE-FIRST  FAIL  a method's expose is not its first statement
 *   HR-RESULT        FAIL  result used as a variable (assigned, or a loop control variable); ~result, the
 *                          Message method, is not this
 *   HR-PLUS-ZERO     FAIL  "+ 0" used to coerce a number
 *   HR-LITERAL-CALL  FAIL  a string followed at once by "(": a call of the routine named by the string
 *   HR-LITERAL-HEX   FAIL  a string followed at once by x or b that is not a hex or binary string
 *   HR-COMMENT       FAIL  a comment never closed, nearly always a slash-asterisk inside a comment (a path
 *                          or glob) opening a nested one (hit twice by Claude, 10 and 11 Nov)
 *   HR-INDEX-LOOP    WARN  do i = 1 to coll~items: loop over the collection instead
 *   HR-CREDITS       WARN  no README says who did the architecture
 *
 * Each rule can be switched per layer in the rule book (HouseRules.HR-INDEX-LOOP | off, say), and the
 * receipt shows which layer did it.
 */
::requires 'AlchemyWorkflow.cls'

::class HouseRulesStep public subclass WorkflowStep
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'

::method id
  return 'HouseRules'

::method stage
  return 'inspect'

::method describe
  return 'check the ooRexx house rules: no private methods, expose first, no result variable, no + 0, no literal traps, collections over index loops, credits'

::method skipReason
  use strict arg ctx
  if ctx~sourceFiles~items = 0 then return 'no ooRexx files'
  return ''

::method intends
  use strict arg ctx
  return 'read' ctx~sourceFiles~items 'ooRexx file(s) and the README; report each house-rule breach with its line'

::method run
  use strict arg ctx, res
  do rel over ctx~sourceFiles
    src = ctx~source(rel)
    self~directives(res, rel, src)
    self~bodies(res, rel, src)
    self~lines(res, rel, src)
    self~traps(res, rel, src)
  end
  self~credits(ctx, res)

::method directives
  use strict arg res, rel, src
  do d over src~directives
    if wordpos(d['KIND'], 'METHOD ATTRIBUTE') = 0 then iterate
    if wordpos('PRIVATE', d['OPTIONS']) = 0 then iterate
    res~add(self~finding('HR-PRIVATE', 'FAIL', rel, d['LINE'], '::' || d['KIND']~lower d['NAME'] 'is private' '(class' d['OWNER'] || ')', 'remove private from the directive: no private methods in any class'))
  end

/* expose must be the first statement of a method */
::method bodies
  use strict arg res, rel, src
  code = src~code
  do d over src~ofKind('METHOD')
    first = ''
    do n = d['LINE'] + 1 to d['LAST']
      do stmt over code[n]~makeArray(';')
        w = stmt~word(1)~upper
        if w == '' then iterate
        if first == '' then do
          first = w
          iterate
        end
        if w == 'EXPOSE' then res~add(self~finding('HR-EXPOSE-FIRST', 'FAIL', rel, n, 'method' d['NAME'] '(class' d['OWNER'] || ') has expose after its first statement (' || first~lower || ')', 'move expose to be the first statement of the method'))
      end
    end
  end

::method lines
  use strict arg res, rel, src
  n = 0
  do line over src~code
    n += 1
    if line~strip == '' then iterate
    u = line~upper
    self~resultVariable(res, rel, n, u)
    self~plusZero(res, rel, n, line)
    self~indexLoop(res, rel, n, u)
  end

/* RESULT as a whole name, not after ~ or . (so ~result, the Message method, is fine) */
::method resultVariable
  use strict arg res, rel, n, u
  p = 0
  do forever
    p = u~pos('RESULT', p + 1)
    if p = 0 then return
    before = ''
    if p > 1 then before = u~subchar(p - 1)
    after = u~subchar(p + 6)
    if before \== '' then if verify(before, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.!?~') = 0 then iterate
    if after \== '' then if verify(after, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.!?') = 0 then iterate
    rest = u~substr(p + 6)~strip('L')
    lead = ''
    if p > 1 then lead = u~left(p - 1)~strip
    assigned = rest~left(1) == '=' & rest~left(2) \== '=='
    looped = .false
    if lead~words = 1 then looped = wordpos(lead, 'DO LOOP') > 0
    if assigned | looped then do
      res~add(self~finding('HR-RESULT', 'FAIL', rel, n, 'result is used as a variable', 'rename it (out, answer, value): result is set by every call that returns a value'))
      return
    end
  end

::method plusZero
  use strict arg res, rel, n, line
  p = 0
  do forever
    p = line~pos('+', p + 1)
    if p = 0 then return
    rest = line~substr(p + 1)~strip('L')
    if rest~left(1) \== '0' then iterate
    nxt = rest~subchar(2)
    if nxt \== '' then if verify(nxt, '0123456789.Ee') = 0 then iterate
    res~add(self~finding('HR-PLUS-ZERO', 'FAIL', rel, n, '"+ 0" used to make a number', 'drop it: ooRexx compares and computes numbers as they are; use datatype() to test, format() to normalise'))
    return
  end

::method indexLoop
  use strict arg res, rel, n, u
  t = u~space
  if wordpos(t~word(1), 'DO LOOP') = 0 then return
  if t~word(3) \== '=' then return
  if t~word(5) \== 'TO' then return
  limit = t~word(6)
  if limit~right(6) \== '~ITEMS' then return
  res~add(self~finding('HR-INDEX-LOOP', 'WARN', rel, n, 'an index loop up to' limit~lower, 'loop over the collection: do thing over' limit~left(limit~length - 6)~lower))

::method traps
  use strict arg res, rel, src
  do t over src~traps
    select
      when t['KIND'] == 'COMMENT' then res~add(self~finding('HR-COMMENT', 'FAIL', rel, t['LINE'], t['TEXT'] || ': the opener on line' t['LINE'] 'is inside a comment and opens a nested one; ooRexx refuses the file (Error 6.1)', 'reword the comment so no slash is followed by an asterisk (a path or glob such as dir/*.json)'))
      when t['KIND'] == 'CALL' then res~add(self~finding('HR-LITERAL-CALL', 'FAIL', rel, t['LINE'], 'the string ''' || t['TEXT'] || ''' is followed at once by "(", which calls a routine named by the string', 'join with ||, or put a blank before the ('))
      otherwise res~add(self~finding('HR-LITERAL-HEX', 'FAIL', rel, t['LINE'], 'the string ''' || t['TEXT'] || ''' is followed at once by' t['KIND']~left(1)~lower || ', which makes it a' t['KIND']~lower 'literal it is not', 'join with ||, or rename the variable that starts with' t['KIND']~left(1)~lower))
    end
  end

/* who did the architecture, said in a README (house rule: every update credits the architect) */
::method credits
  use strict arg ctx, res
  call SysFileTree ctx~pkgDir || '/README*', 'r.', 'FO'
  do i = 1 to r.0
    s = .stream~new(r.i)
    s~open('read shareread')
    body = s~charIn(1, s~chars)
    s~close
    if body~caselessPos('Architecture') > 0 then return
  end
  res~add(self~finding('HR-CREDITS', 'WARN', 'README.md', 0, 'no README in the package says who did the architecture', 'add: Architecture: Tom Dyer, and who did the coding'))
