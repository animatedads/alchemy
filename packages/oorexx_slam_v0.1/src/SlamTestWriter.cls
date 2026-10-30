/* SlamTestWriter.cls - SLAM writes unit tests: ooRexxUnit (ooTest) for ooRexx, JUnit 4 for Java.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 *
 * A unit test is inputs and an expected outcome. SLAM already reads what a unit checks (SlamRules: each
 * GUARD is a rule that MUST hold to go on, and the clause that stops when it does not) and what each
 * argument must be (SlamContract: kinds, messages sent to it). From those it chooses the inputs:
 *   HAPPY     every rule SLAM can work out holds: the way through
 *   BOUNDARY  for a rule on one input (an argument, or an argument's length) against a constant c:
 *             c - 1, c and c + 1 for numbers (and lengths), c and another string for strings; one input
 *             changes, the others stay at their HAPPY value
 *   KIND      a NUMBER argument given a word: the contract says it is used as a number
 * and, before running anything, predicts the outcome: it walks the rules in source order with the case's
 * values, and the first rule that does not hold stops the unit there. When that rule's stopping clause
 * is a constant (return 0, return '', return .nil, return .false) or a raise syntax n, the outcome is
 * PREDICTED; otherwise SLAM does not know the value and the case's expectation is OBSERVED: the unit is
 * run once now and what it does is recorded (a characterisation test). Every predicted outcome is then
 * checked against that run, and a wrong prediction is kept and counted, not hidden.
 * A rule SLAM cannot evaluate before the one that stops (a call, a computed value) makes the prediction
 * unknown: it says so rather than guess.
 *
 * Outcomes: VALUE v (a string; compared with ==, ooTest's assertSame), NIL, ERROR n (syntax n; ooTest's
 * expectSyntax), OTHER c (an object of class c: not written as a test, counted).
 *
 * Alchemy rules kept: no private methods, expose first, no variable named result, nested IF instead of
 * relying on & short-circuit, no labels inside loops.
 */

::requires 'SlamRules.cls'
::requires 'SlamContract.cls'
::requires 'SlamCompose.cls'

::class SlamTestCase public
::attribute name
::attribute args          /* array of argument values (strings) */
::attribute source        /* HAPPY BOUNDARY KIND RANDOM */
::attribute why           /* the rule and value that chose it */
::attribute predicted     /* 'VALUE v' 'NIL' 'ERROR n', or '' when SLAM does not know */
::attribute kind          /* the outcome the test expects: VALUE NIL ERROR OTHER */
::attribute expected
::attribute hex16         /* a Java value: its chars as 4 hex digits each (for the Java literal) */
::attribute message       /* for an ERROR: the condition's message, which the test reads too */
::method init
  expose name args source why predicted kind expected hex16 message
  use strict arg name, args, source, why
  hex16 = ''
  message = ''
  predicted = ''
  kind = ''
  expected = ''
::method expectation
  expose kind expected
  if kind == 'NIL' then return 'NIL'
  return kind expected

/* ------------------------------------------------------------------------------------------------ */
::class SlamTestWriter public
::attribute notes         /* why a unit got no tests, per unit name */
/* An argument left out: the call has nothing at that place (f('a', , 'c')). */
::constant OMITTED 'SLAM:OMITTED'
::method init
  expose notes
  notes = .directory~new

/* The messages a value can take and still be a plain string: arguments that need any other message
 * (items, ok, x, open, ...) are objects SLAM cannot make, so their unit gets no tests. */
::constant STRINGMSGS 'length substr lower upper string pos lastpos changestr reverse abs left right strip verify translate word words space countstr caselesspos caselessabbrev datatype c2d d2c c2x x2c b2x x2b x2d d2x subchar'

/* Inputs a unit can be given: one knob per argument (its value) and one per argument sent ~length.
 * Returns a directory: ARGS (array of directories POS NAME NUMBER), RULES (array of directories RULE
 * KNOB), or .nil with notes[name] set when the unit takes an argument SLAM cannot make. */
::method knobs
  expose notes
  use strict arg name, contract, rules
  args = .array~new
  lengthArgs = .array~new
  do a over contract~args
    d = .directory~new
    d['POS'] = a['POS']
    d['NAME'] = a['NAME']~lower
    d['NUMBER'] = a['KINDS']~hasIndex('NUMBER')
    if a['KINDS']~hasIndex('COLLECTION') then do
      notes[name] = 'argument' d['NAME'] 'is a collection'
      return .nil
    end
    do m over a['MESSAGES']~allIndexes
      if wordpos(m~lower, self~STRINGMSGS) == 0 then do
        notes[name] = 'argument' d['NAME'] 'is sent ~' || m~lower
        return .nil
      end
    end
    if a['MESSAGES']~hasIndex('LENGTH') then lengthArgs~append(d['POS'])
    args~append(d)
  end
  return self~knobsWith(name, args, lengthArgs, rules)
/* The same, from arguments already known (a Java or NetRexx signature): args is an array of
 * directories POS NAME NUMBER (and TYPE). */
::method knobsWith
  expose notes
  use strict arg name, args, lengthArgs, rules
  out = .directory~new
  if args~items == 0 then do
    notes[name] = 'no arguments'
    return .nil
  end
  out['ARGS'] = args
  rl = .array~new
  do r over rules
    k = self~knobOf(r, args, lengthArgs)
    d = .directory~new
    d['RULE'] = r
    d['KNOB'] = k
    rl~append(d)
  end
  out['RULES'] = rl
  return out
/* The knob a rule is about: 'n' (argument n), 'n.LENGTH', or '' (not one SLAM can set). */
::method knobOf
  use strict arg r, args, lengthArgs
  parse value r~must with op l rest
  if wordpos(op, 'EQ NE LT LE GT GE') == 0 then return ''
  if l \== 'V' then return ''
  if rest~words \= 1 then return ''
  c = rest~word(1)
  if c~left(2) \== 'N:' then if c~left(2) \== 'S:' then if c \== 'NIL' then return ''
  if r~names~words \= 1 then return ''
  nm = r~names~lower
  do a over args
    if a['NAME'] == nm then return a['POS']
  end
  if nm == 'length' then do
    if lengthArgs~items == 1 then return lengthArgs[1] || '.LENGTH'
    /* length(x), or the length of a value made from the one string argument: that argument's length
       (a guess the predictions check) */
    strs = .array~new
    do a over args
      if \a['NUMBER'] then strs~append(a['POS'])
    end
    if strs~items == 1 then return strs[1] || '.LENGTH'
  end
  return ''
/* The constant a rule compares with: .array(type, value), type N S NIL. */
::method constOf
  use strict arg r
  c = r~must~word(3)
  if c == 'NIL' then return .array~of('NIL', '')
  return .array~of(c~left(1), c~substr(3))

/* Does the rule hold for these knob values? .true / .false / '' (cannot tell). */
::method holdsOn
  use strict arg rk, values
  k = rk['KNOB']
  if k == '' then return ''
  parse var k pos '.' part
  v = values[pos]
  if v == .nil then return ''
  if part == 'LENGTH' then v = v~length
  r = rk['RULE']
  if r~must~word(3) == 'NIL' then do
    /* NE V NIL: a string is never .nil */
    if r~must~word(1) == 'NE' then return .true
    return .false
  end
  return r~holds('', v)

/* Walk the rules in order on these values: the first that does not hold stops the unit. Returns
 * .array(state, rule) with state PASS (every rule holds), STOP (rule stops it), UNKNOWN (a rule
 * before any stop cannot be worked out). Rules under an IF (when \== '') and rules that skip or stop a
 * loop are not on the straight path, so they are not walked. */
::method walk
  use strict arg rules, values
  do rk over rules
    r = rk['RULE']
    if r~when \== '' then iterate
    if wordpos(r~stop, 'SKIP STOP') > 0 then iterate
    h = self~holdsOn(rk, values)
    if h == '' then return .array~of('UNKNOWN', r)
    if \h then return .array~of('STOP', r)
  end
  return .array~of('PASS', .nil)
/* What a stopping clause gives, when it is a constant: 'VALUE v', 'NIL', 'ERROR n', else ''. */
::method stopOutcome
  use strict arg r
  t = r~stopToks
  if t~items < 1 then return ''
  w = t[1]~text~lower
  if w == 'return' then do
    if t~items == 1 then return ''
    if t~items == 2 then do
      x = t[2]
      if x~kind == 'NUM' | x~kind == 'STR' then return 'VALUE' x~text
      if x~kind == 'DOT' then do
        d = x~text~lower~strip('L', '.')
        if d == 'nil' then return 'NIL'
        if d == 'true' then return 'VALUE 1'
        if d == 'false' then return 'VALUE 0'
      end
    end
    return ''
  end
  if w == 'raise' then if t~items >= 3 then if t[2]~text~lower == 'syntax' then if t[3]~kind == 'NUM' then return 'ERROR' t[3]~text
  return ''

/* A value for one argument where every rule on it holds; .nil when none of the candidates does. */
::method happyValue
  use strict arg a, rules
  cands = .array~new
  lengths = .array~new
  do rk over rules
    k = rk['KNOB']
    if k == '' then iterate
    parse var k pos '.' part
    if pos \= a['POS'] then iterate
    c = self~constOf(rk['RULE'])
    if part == 'LENGTH' then do
      if c[1] == 'N' then do n over .array~of(c[2], c[2] + 1, c[2] - 1); lengths~append(n); end
      iterate
    end
    if c[1] == 'N' then do n over .array~of(c[2] + 1, c[2], c[2] - 1); cands~append(n); end
    if c[1] == 'S' then do
      cands~append(c[2])
      cands~append(c[2] || 'x')
    end
  end
  if a['NUMBER'] then do n over .array~of(7, 1, 10, 0, 100); cands~append(n); end
  else do s over .array~of('abc', 'a', 'A1', '7'); cands~append(s); end
  do n over lengths
    if n >= 0 then if n < 1000 then cands~append(copies('a', n))
  end
  do v over cands
    values = .array~new
    values[a['POS']] = v
    ok = .true
    do rk over rules
      k = rk['KNOB']
      if k == '' then iterate
      parse var k pos '.' .
      if pos \= a['POS'] then iterate
      if rk['RULE']~when \== '' then iterate
      h = self~holdsOn(rk, values)
      if h == '' then iterate
      if \h then do
        ok = .false
        leave
      end
    end
    if ok then return v
  end
  return .nil

/* The cases for one unit, with predictions. kn from knobs. */
::method cases
  use strict arg name, kn
  args = kn['ARGS']
  rules = kn['RULES']
  self~predictWith(rules)
  happy = .array~new
  do a over args
    v = self~happyValue(a, rules)
    if v == .nil then do
      if a['NUMBER'] then v = 7
      else v = 'abc'
    end
    happy[a['POS']] = v
  end
  out = .array~new
  seen = .directory~new
  call add self, out, seen, happy, 'HAPPY', 'every rule holds'
  do rk over rules
    k = rk['KNOB']
    if k == '' then iterate
    parse var k pos '.' part
    c = self~constOf(rk['RULE'])
    vals = .array~new
    if part == 'LENGTH' then do
      if c[1] \== 'N' then iterate
      if \datatype(c[2], 'W') then iterate
      base = happy[pos]
      do n over .array~of(c[2] - 1, c[2], c[2] + 1)
        if n < 0 then iterate
        if n > 1000 then iterate
        vals~append(left(base || copies('a', n), n))
      end
    end
    else do
      if c[1] == 'N' then do
        if datatype(c[2], 'W') then do n over .array~of(c[2] - 1, c[2], c[2] + 1); vals~append(n); end
        else vals~append(c[2])
      end
      if c[1] == 'S' then do
        vals~append(c[2])
        if c[2] == '' then vals~append('x')
        else vals~append(c[2] || 'x')
      end
    end
    do v over vals
      vs = happy~copy
      vs[pos] = v
      call add self, out, seen, vs, 'BOUNDARY', rk['RULE']~must '  [' || rk['RULE']~names || ']' 'at' v~left(20)
    end
  end
  /* LITERAL: the strings the unit compares with or looks for, given to each string argument */
  lits = kn['LITERALS']
  if lits \== .nil then do a over args
    if a['NUMBER'] then iterate
    n = 0
    do v over lits
      n += 1
      if n > 8 then leave
      vs = happy~copy
      vs[a['POS']] = v
      call add self, out, seen, vs, 'LITERAL', 'a string the unit uses, as' a['NAME']
    end
  end
  /* NUMBER: the numbers the unit's code holds (a SELECT's WHEN n = 3, a mask, a modulus), and the
     edges of the machine widths integer code is written around */
  nums = kn['NUMBERS']
  if nums == .nil then nums = .array~new
  edges = .array~of(0, 1, -1, 255, 256, 65535, 65536, 4294967295, 4294967296)
  do a over args
    if \a['NUMBER'] then iterate
    n = 0
    do v over nums
      n += 1
      if n > 8 then leave
      vs = happy~copy
      vs[a['POS']] = v
      call add self, out, seen, vs, 'NUMBER', 'a number the unit uses, as' a['NAME']
    end
    do v over edges
      vs = happy~copy
      vs[a['POS']] = v
      call add self, out, seen, vs, 'EDGE', 'a machine-width edge, as' a['NAME']
    end
  end
  if kn['NOKIND'] \== .true then do a over args
    if \a['NUMBER'] then iterate
    vs = happy~copy
    vs[a['POS']] = 'abc'
    call add self, out, seen, vs, 'KIND', 'argument' a['NAME'] 'is used as a number: given a word'
  end
  /* FRACTION: a number that is not whole, beside each whole constant the unit compares with, and
     0.5 and -2.5 (asked for by the rx2cpp lane's note to SLAM) */
  do a over args
    if \a['NUMBER'] then iterate
    fr = .array~of(0.5, -2.5)
    do rk over rules
      k = rk['KNOB']
      if k == '' then iterate
      parse var k pos '.' part
      if pos \= a['POS'] then iterate
      if part \== '' then iterate
      c = self~constOf(rk['RULE'])
      if c[1] == 'N' then if datatype(c[2], 'W') then do
        fr~append(c[2] + 0.5)
        fr~append(c[2] - 0.5)
      end
    end
    do v over fr
      vs = happy~copy
      vs[a['POS']] = v
      call add self, out, seen, vs, 'FRACTION', 'a number that is not whole, as' a['NAME']
    end
  end
  /* OMIT: each argument left out in turn (the rx2cpp lane: "a test with no second value") */
  do a over args
    vs = happy~copy
    vs[a['POS']] = self~OMITTED
    call add self, out, seen, vs, 'OMIT', 'argument' a['NAME'] 'left out'
  end
  return out

add: procedure
  use arg w, out, seen, values, source, why
  key = values~makeString('L', '0e'x)
  if seen~hasIndex(key) then return
  seen[key] = .true
  c = .SlamTestCase~new('', values~copy, source, why)
  c~predicted = w~predict(c, .nil)
  out~append(c)
  return

/* SLAM's prediction for a case, made before running it. rules: the unit's knob rules (set by the
 * caller through predictWith); '' when SLAM does not know. */
::method predict
  expose currentRules
  use strict arg c, rules
  if rules == .nil then rules = currentRules
  if rules == .nil then return ''
  values = .array~new
  do p = 1 to c~args~items
    if c~args[p] == self~OMITTED then return ''      /* what an omitted argument does is the unit's business */
    values[p] = c~args[p]
  end
  w = self~walk(rules, values)
  if w[1] \== 'STOP' then return ''
  return self~stopOutcome(w[2])
::method predictWith
  expose currentRules
  use strict arg rules
  currentRules = rules

/* Run a case on a routine (a lifted .Routine): the outcome, as kind and value. */
::method outcome
  use strict arg routine, args
  signal on syntax name failed
  v = routine~callWith(args)
  if v == .nil then return .array~of('NIL', '')
  if \v~isA(.String) then return .array~of('OTHER', v~class~id)
  return .array~of('VALUE', v)
failed:
  c = condition('O')
  return .array~of('ERROR', c['CODE'])

/* Fill each case's expectation from a run; returns .array(predicted right, predicted wrong). */
::method observe
  use strict arg routine, cases
  right = 0
  wrong = 0
  do c over cases
    o = self~outcome(routine, c~args)
    /* run twice: a case that does not give the same outcome both times (random, time) is not a unit
       test, so it is not written */
    o2 = self~outcome(routine, c~args)
    if o[1] \== o2[1] | o[2] \== o2[2] then do
      c~kind = 'OTHER'
      c~expected = 'NOT THE SAME TWICE'
      iterate
    end
    c~kind = o[1]
    c~expected = o[2]
    if c~predicted \== '' then do
      if self~sameOutcome(c~predicted, o) then right += 1
      else wrong += 1
    end
  end
  return .array~of(right, wrong)
::method sameOutcome
  use strict arg p, o
  parse var p k v
  if k \== o[1] then return .false
  if k == 'NIL' then return .true
  if k == 'ERROR' then return v = o[2]
  return v == o[2]

/* Random inputs of the same kinds, for comparison: n cases, values from a fixed seed. */
::method randomCases
  use strict arg kn, n, seed
  out = .array~new
  seen = .directory~new
  call random , , seed
  tries = 0
  do while out~items < n
    tries += 1
    if tries > n * 20 then leave
    vs = .array~new
    do a over kn['ARGS']
      if a['TYPE'] == 'boolean' then vs[a['POS']] = random(0, 1)
      else if a['NUMBER'] then vs[a['POS']] = random(0, 2000) - 1000
      else do
        len = random(0, 12)
        s = ''
        do i = 1 to len; s = s || substr('abcdefghij0123456789 _-', random(1, 23), 1); end
        vs[a['POS']] = s
      end
    end
    key = vs~makeString('L', '0e'x)
    if seen~hasIndex(key) then iterate
    seen[key] = .true
    out~append(.SlamTestCase~new('', vs, 'RANDOM', 'random input'))
  end
  return out

/* ---- writing: ooRexxUnit (ooTest) ---- */
/* A Rexx literal for a string: '...' with ' doubled, or 'hex'x when it holds a character below blank. */
::method rexxLiteral
  use strict arg s
  if s~verify(xrange('20'x, '7e'x)) > 0 then return "'" || s~c2x || "'x"
  return "'" || s~changeStr("'", "''") || "'"
/* One ooTest group for routine NAME of FILE. The group lifts the routine from the file each time it
 * runs (SLAM_UNDER_TEST overrides the file, for mutants), so it tests the code as it is now. */
::method ooTestGroup
  use strict arg className, file, name, cases, header, owner = ''
  b = .array~new
  b~append('#!/usr/bin/env rexx')
  b~append('/*' header)
  b~append('   Written by SLAM (SlamTestWriter): Architecture: Tom Dyer.  Code: Claude (Opus 5.5).')
  if owner == '' then b~append('   Unit under test: routine' name 'in' file)
  else b~append('   Unit under test: method' name 'of class' owner 'in' file '(it uses nothing of its object, so it is lifted and run alone)')
  b~append('   Run: rexx' className '(with ooTest.frm and framework/ on REXX_PATH) */')
  b~append('parse source . . sourceFile')
  b~append('group = .TestGroup~new(sourceFile)')
  b~append('group~add(.' || className || ')')
  b~append('if group~isAutomatedTest then return group')
  b~append('testRun = group~suite~execute')
  b~append('testRun~print')
  b~append('return testRun')
  b~append('')
  b~append("::requires 'ooTest.frm'")
  b~append("::class '" || className || "' public subclass ooTestCase")
  b~append('')
  b~append('::method underTest')
  b~append("  file = value('SLAM_UNDER_TEST', , 'ENVIRONMENT')")
  b~append("  if file == '' then file =" self~rexxLiteral(file))
  if owner == '' then b~append('  return slamLift(file,' self~rexxLiteral(name) || ')')
  else b~append('  return slamLift(file,' self~rexxLiteral(name) || ',' self~rexxLiteral(owner) || ')')
  b~append('')
  b~append('/* The error a call raises, read from its condition: code and message (expectSyntax reads the')
  b~append('   code only). */')
  b~append('::method errorOf')
  b~append('  signal on syntax name failed')
  b~append("  v = self~underTest~callWith(arg(1, 'A'))")
  b~append("  return 'NO ERROR'")
  b~append('failed:')
  b~append("  c = condition('O')")
  b~append("  return c['CODE'] c['MESSAGE']")
  b~append('')
  b~append('/* Another condition a call raises (USER, NOTREADY ...): its name, description and additional. */')
  b~append('::method conditionOf')
  b~append('  signal on any name other')
  b~append("  v = self~underTest~callWith(arg(1, 'A'))")
  b~append("  return 'NO CONDITION'")
  b~append('other:')
  b~append("  c = condition('O')")
  b~append("  t = ''")
  b~append("  add = c['ADDITIONAL']")
  b~append("  if add \== .nil then do x over add; t = t || ',' || x~string; end")
  b~append("  return c['CONDITION'] c['DESCRIPTION'] '[' || t~substr(2) || ']'")
  k = 0
  do c over cases
    if c~kind == 'OTHER' then iterate
    k += 1
    b~append('')
    b~append('/*' c~source || ':' c~why~changeStr('*/', '* /'))
    if c~predicted \== '' then b~append('   predicted by SLAM before running:' c~predicted '*/')
    else b~append('   observed: SLAM could not predict it */')
    b~append('::method test_' || right(k, 3, '0') || '_' || c~source~lower)
    call = 'self~underTest~call(' || self~argList(c~args) || ')'
    select
      when c~kind == 'ERROR' then b~append('  self~assertSame(' || self~rexxLiteral(c~expected c~message) || ', self~errorOf(' || self~argList(c~args) || '))')
      when c~kind == 'CONDITION' then b~append('  self~assertSame(' || self~rexxLiteral(c~expected) || ', self~conditionOf(' || self~argList(c~args) || '))')
      when c~kind == 'NIL' then b~append('  self~assertNull(' || call || ')')
      otherwise b~append('  self~assertSame(' || self~rexxLiteral(c~expected) || ',' call || ')')
    end
  end
  if k == 0 then return .nil
  b~append('')
  b~append('/* The unit, lifted from its file as SLAM lifts a standalone unit: the lines after its')
  b~append('   ::routine directive (or its class''s ::method directive), up to the next directive. */')
  b~append('::routine slamLift')
  b~append('  use strict arg file, name, owner = ''''')
  b~append('  lines = .array~new')
  b~append('  call stream file, ''C'', ''OPEN READ''')
  b~append('  do while lines(file) > 0; lines~append(linein(file)); end')
  b~append('  call stream file, ''C'', ''CLOSE''')
  b~append('  body = .array~new')
  b~append('  inside = .false')
  b~append('  cls = ''''')
  b~append('  do ln over lines')
  b~append('    s = ln~strip')
  b~append('    if s~left(2) == ''::'' then do')
  b~append('      if inside then leave')
  b~append('      parse upper value s with d nm rest')
  b~append('      nm = nm~strip(''B'', '';'')~strip(''B'', "''")~strip(''B'', ''"'')')
  b~append('      if d == ''::CLASS'' then cls = nm')
  b~append('      if owner == '''' then do')
  b~append('        if d == ''::ROUTINE'' then if nm == name~upper then inside = .true')
  b~append('      end')
  b~append('      else if d == ''::METHOD'' then if nm == name~upper then if cls == owner~upper then inside = .true')
  b~append('      if inside then do')
  b~append('        semi = s~pos('';'')')
  b~append('        if semi > 0 then body~append(s~substr(semi + 1))')
  b~append('      end')
  b~append('      iterate')
  b~append('    end')
  b~append('    if inside then body~append(ln)')
  b~append('  end')
  b~append('  body~insert("address ''SLAMNOCMD''", .nil)   /* a command goes nowhere, not to the shell */')
  b~append('  return .Routine~new(name, body)')
  return b
::method argList
  use strict arg args
  out = .array~new
  do v over args
    if v == self~OMITTED then out~append('')
    else out~append(self~rexxLiteral(v))
  end
  return out~makeString('L', ', ')~strip('T')
::method countWritten
  use strict arg cases
  n = 0
  do c over cases
    if c~kind \== 'OTHER' then n += 1
  end
  return n

/* The distinct whole numbers a unit's code holds, in order, without 0 and 1 (the edges have them). */
::method numbersOf
  use strict arg tokens
  out = .array~new
  seen = .directory~new
  do t over tokens
    if t~kind \== 'NUMBER' then iterate
    v = t~text
    if \datatype(v, 'W') then iterate
    if v = 0 | v = 1 then iterate
    if seen~hasIndex(v) then iterate
    seen[v] = .true
    out~append(v)
  end
  return out
/* The distinct strings a unit's code holds (its literals), in order, without the empty one. */
::method literalsOf
  use strict arg tokens
  out = .array~new
  seen = .directory~new
  do t over tokens
    if t~kind \== 'STRING' then iterate
    v = t~text
    if v == '' then iterate
    if v~length > 40 then iterate
    if seen~hasIndex(v) then iterate
    seen[v] = .true
    out~append(v)
  end
  return out

/* ---- writing: JUnit 4 ---- */
/* A Java string literal: "..." with \ " and characters outside printable ASCII as escapes. */
::method javaLiteral
  use strict arg s
  out = '"'
  do i = 1 to s~length
    ch = s~subchar(i)
    select
      when ch == '\' then out = out || '\\'
      when ch == '"' then out = out || '\"'
      when ch << '20'x then out = out || '\' || right(self~octal(ch~c2d), 3, '0')   /* not \u000A: Java reads \u escapes before strings */
      when ch~verify(xrange('20'x, '7e'x)) > 0 then out = out || '\u' || right(ch~c2x, 4, '0')
      otherwise out = out || ch
    end
  end
  return out || '"'
::method octal
  use strict arg n
  out = ''
  do while n > 0
    out = (n // 8) || out
    n = n % 8
  end
  if out == '' then out = '0'
  return out
/* A Java string literal from chars given as 4 hex digits each. */
::method javaLiteral16
  use strict arg hex
  out = '"'
  do j = 1 to hex~length by 4
    u = hex~substr(j, 4)
    n = u~x2d
    select
      when n == 92 then out = out || '\\'
      when n == 34 then out = out || '\"'
      when n >= 32 & n <= 126 then out = out || d2c(n)
      when n < 32 then out = out || '\' || right(self~octal(n), 3, '0')
      otherwise out = out || '\u' || u
    end
  end
  return out || '"'
/* An argument in Java for a declared type; .nil when the value cannot be one (a word for an int). */
::method javaArg
  use strict arg v, type
  if v == self~OMITTED then return .nil                 /* Java has no omitted argument */
  t = type~substr(type~lastPos('.') + 1)
  select
    when t == 'Rexx' then return 'new netrexx.lang.Rexx(' || self~javaLiteral(v) || ')'
    when t == 'String' then return self~javaLiteral(v)
    when wordpos(t, 'int long short byte') > 0 then do
      if \datatype(v, 'W') then return .nil
      if t == 'long' then return v || 'L'
      if t == 'int' then if abs(v) > 2147483647 then return .nil
      if t == 'short' | t == 'byte' then return '(' || t || ') ' || v
      return v
    end
    when t == 'double' | t == 'float' then do
      if \datatype(v, 'N') then return .nil
      if t == 'float' then return v || 'f'
      return v || 'd'
    end
    when t == 'boolean' then do
      if v == '1' then return 'true'
      if v == '0' then return 'false'
      return .nil
    end
    when t == 'char' then do
      if v~length \= 1 then return .nil
      return "'" || self~javaLiteral(v)~strip('B', '"') || "'"
    end
    otherwise return .nil
  end
/* The Java call for a case, or .nil when an argument cannot be written for its type. */
::method javaCall
  use strict arg target, method, types, args
  out = .array~new
  do p = 1 to types~items
    a = self~javaArg(args[p], types[p])
    if a == .nil then return .nil
    out~append(a)
  end
  return target || '.' || method || '(' || out~makeString('L', ', ') || ')'
/* A Java program that runs each case once and prints its outcome on a line of its own, @@SLAM i then
 * VALUE <hex of the value's string>, NIL, ERROR <exception class>, or SKIP (an argument it cannot write).
 * Its argument is the case to start at: a case that ends the program (System.exit, a NetRexx exit)
 * prints nothing, and the caller starts again after it. */
::method javaObserver
  use strict arg className, pkg, target, method, types, cases
  b = .array~new
  if pkg \== '' then b~append('package' pkg || ';')
  b~append('public final class' className '{')
  b~append('  static final java.io.PrintStream OUT = System.out;')
  b~append('  static void out(int i, Object v) {')
  b~append('    if (v == null) { OUT.println("@@SLAM " + i + " NIL"); return; }')
  b~append('    StringBuilder h = new StringBuilder();')
  b~append('    for (char x : String.valueOf(v).toCharArray()) h.append(String.format("%04X", (int) x));')
  b~append('    OUT.println("@@SLAM " + i + " VALUE " + h + ".");')
  b~append('  }')
  b~append('  static String hex(String v) {')
  b~append('    StringBuilder h = new StringBuilder();')
  b~append('    for (char x : v.toCharArray()) h.append(String.format("%04X", (int) x));')
  b~append('    return h + ".";')
  b~append('  }')
  b~append('  public static void main(String[] args) {')
  b~append('    int start = args.length > 0 ? Integer.parseInt(args[0]) : 1;')
  b~append('    System.setOut(new java.io.PrintStream(java.io.OutputStream.nullOutputStream()));')
  i = 0
  do c over cases
    i += 1
    call = self~javaCall(target, method, types, c~args)
    if call == .nil then b~append('    if (start <=' i || ') OUT.println("@@SLAM' i 'SKIP");')
    else b~append('    if (start <=' i || ') try { out(' || i || ', (Object)' call || '); } catch (Throwable e) { OUT.println("@@SLAM' i 'ERROR " + e.getClass().getName() + " " + hex(String.valueOf(e.getMessage()))); }')
  end
  b~append('  }')
  b~append('}')
  return b
/* Read the observer's lines into the cases; returns .array(predicted right, wrong). A case it could
 * not write becomes OTHER (not written as a test). */
::method readObserved
  use strict arg lines, cases, again = (.array~new)
  right = 0
  wrong = 0
  got = .directory~new
  do ln over lines
    parse var ln tag i rest
    if tag == '@@SLAM' then got[i] = rest
  end
  /* a second run: a case whose outcome differs (random, time) is not a unit test */
  got2 = .directory~new
  do ln over again
    parse var ln tag i rest
    if tag == '@@SLAM' then got2[i] = rest
  end
  if again~items > 0 then do i over got~allIndexes
    if got2[i] \== got[i] then got[i] = 'TWICE'
  end
  do i = 1 to cases~items
    c = cases[i]
    ln = got[i]
    if ln == .nil then ln = 'SKIP'
    parse var ln k v
    select
      when k == 'VALUE' then do
        /* Java chars as 4 hex digits each: kept as they are for the Java literal, and as a Rexx
           string when every char is below 256 (for comparing with SLAM's prediction) */
        c~kind = 'VALUE'
        c~hex16 = v~strip('T', '.')
        c~expected = ''
        do j = 1 to c~hex16~length by 4
          u = c~hex16~substr(j, 4)~x2d
          if u < 256 then c~expected = c~expected || d2c(u)
          else c~expected = c~expected || '?'
        end
      end
      when k == 'NIL' then do
        c~kind = 'NIL'
        c~expected = ''
      end
      when k == 'ERROR' then do
        /* the exception class, and its message as chars (4 hex digits each), which the test reads too */
        c~kind = 'ERROR'
        parse var v cls msg
        c~expected = cls
        c~hex16 = msg~strip('T', '.')
      end
      otherwise do
        c~kind = 'OTHER'
        c~expected = ''
      end
    end
    if c~kind == 'OTHER' then iterate
    if c~predicted == '' then iterate
    parse value c~predicted with pk pv
    ok = (pk == c~kind)
    if ok then if pk == 'VALUE' then ok = (pv == c~expected)
    if ok then right += 1
    else wrong += 1
  end
  return .array~of(right, wrong)
/* One JUnit 4 test class. Each test is one case: assertEquals(message, expected, actual) on the
 * value's string, assertNull, or assertThrows. */
::method junitClass
  use strict arg className, pkg, target, method, types, cases, header
  b = .array~new
  b~append('/*' header)
  b~append('   Written by SLAM (SlamTestWriter): Architecture: Tom Dyer.  Code: Claude (Opus 5.5). */')
  if pkg \== '' then b~append('package' pkg || ';')
  b~append('')
  b~append('import org.junit.Test;')
  b~append('import static org.junit.Assert.*;')
  b~append('')
  b~append('public class' className '{')
  k = 0
  do c over cases
    if c~kind == 'OTHER' then iterate
    call = self~javaCall(target, method, types, c~args)
    if call == .nil then iterate
    k += 1
    b~append('')
    b~append('    /*' c~source || ':' c~why~changeStr('*/', '* /'))
    if c~predicted \== '' then b~append('       predicted by SLAM before running:' c~predicted '*/')
    else b~append('       observed: SLAM could not predict it */')
    b~append('    @Test public void test_' || right(k, 3, '0') || '_' || c~source~lower || '() {')
    select
      when c~kind == 'ERROR' then do
        b~append('        Throwable e = assertThrows(' || c~expected || '.class, () ->' call || ');')
        b~append('        assertEquals(' || self~javaLiteral(c~source 'message') || ',' self~javaLiteral16(c~hex16) || ', String.valueOf(e.getMessage()));')
      end
      when c~kind == 'NIL' then b~append('        assertNull(' || call || ');')
      otherwise do
        lit = self~javaLiteral(c~expected)
        if c~hex16 \== '' then lit = self~javaLiteral16(c~hex16)
        b~append('        assertEquals(' || self~javaLiteral(c~source c~why~left(40)) || ',' lit || ', String.valueOf(' || call || '));')
      end
    end
    b~append('    }')
  end
  b~append('}')
  if k == 0 then return .nil
  return b

/* Outcomes of ooRexx cases run in a child process (tests/unit/observe_runner.rex), twice: lines
 * '@@SLAM i VALUE hex.', 'NIL', 'ERROR code', 'OTHER class', or 'TIMEOUT' (set by the caller when a
 * case did not finish). A case whose two runs differ, or that timed out, is not written. Returns
 * .array(predicted right, predicted wrong). */
::method observeLines
  use strict arg cases, first, second
  a = .directory~new
  b = .directory~new
  do ln over first
    parse var ln tag i rest
    if tag == '@@SLAM' then a[i] = rest
  end
  do ln over second
    parse var ln tag i rest
    if tag == '@@SLAM' then b[i] = rest
  end
  right = 0
  wrong = 0
  do i = 1 to cases~items
    c = cases[i]
    x = a[i]
    if x == .nil then x = 'TIMEOUT'
    if b[i] \== x then x = 'OTHER NOT THE SAME TWICE'
    parse var x k v
    select
      when k == 'VALUE' then do
        c~kind = 'VALUE'
        c~expected = v~strip('T', '.')~x2c
      end
      when k == 'NIL' then do
        c~kind = 'NIL'
        c~expected = ''
      end
      when k == 'CONDITION' then do
        c~kind = 'CONDITION'
        c~expected = v~strip('T', '.')~x2c
      end
      when k == 'ERROR' then do
        c~kind = 'ERROR'
        parse var v code msg
        c~expected = code
        c~message = msg~strip('T', '.')~x2c
      end
      otherwise do
        c~kind = 'OTHER'
        c~expected = x
      end
    end
    if c~kind == 'OTHER' then iterate
    if c~predicted == '' then iterate
    o = .array~of(c~kind, c~expected)
    if self~sameOutcome(c~predicted, o) then right += 1
    else wrong += 1
  end
  return .array~of(right, wrong)

/* Does the unit read random numbers or the clock? Its outcome then is not the same run to run, so it
 * gets no unit test (two equal runs can still be chance: random(0, 1) agrees half the time). Returns
 * the word it found, or ''. */
::method nondeterministic
  use strict arg tokens
  words = 'RANDOM TIME DATE CURRENTTIMEMILLIS NANOTIME NOW'
  do i = 1 to tokens~items - 1
    t = tokens[i]
    if t~kind \== 'IDENT' then iterate
    if wordpos(t~text~upper, words) == 0 then iterate
    if tokens[i + 1]~text == '(' then return t~text
  end
  return ''
