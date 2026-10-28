/* SlamContract.cls - what a code unit NEEDS before it can run, and what it GIVES after.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Asked for by ChatGPT's second letter to SLAM: "learn what must be true before one piece of work can
 * follow another".
 *
 * Lexical inference over the rx2cpp lexer's tokens (no new parser), so every fact here is DOCUMENTARY
 * tier: read from the code, not proven by running it.
 *
 *   needs    per argument: position, name, kinds implied by use (NUMBER, STRING, COLLECTION, OBJECT),
 *            messages sent to it, and guard conditions it must pass (from "if c then raise/return")
 *   gives    the kinds the unit can return (NUMBER, STRING, BOOLEAN, ARRAY, DIRECTORY, OBJECT:<class>,
 *            ARG<n> when it returns an argument, FIELD, SELF, NIL, NONE, UNKNOWN)
 *   effects  SAY, STREAM, COMMAND, ENV, DYNAMIC, STATE_WRITE, MUTATES_ARG, RAISES, CREATES, CALLS
 *   pure     no SAY/STREAM/COMMAND/ENV/DYNAMIC/STATE_WRITE/MUTATES_ARG and no calls to unknown routines
 *   standalone  pure and uses no user class: a lifted copy of the unit runs on its own
 */

::requires 'SlamSegmenter.cls'

::class SlamContract public
::attribute owner
::attribute selector
::attribute kind
::attribute args
::attribute gives
::attribute effects
::attribute fieldsRead
::attribute fieldsWritten
::attribute calls
::attribute classesUsed
::method init
  expose owner selector kind args gives effects fieldsRead fieldsWritten calls classesUsed
  use strict arg owner, selector, kind
  args = .array~new
  gives = .directory~new
  effects = .directory~new
  fieldsRead = .directory~new
  fieldsWritten = .directory~new
  calls = .directory~new
  classesUsed = .directory~new
/* Runnable on its own: pure, and it uses no user class (so a lifted copy needs nothing else). */
::method standalone
  expose classesUsed
  return self~pure & classesUsed~items == 0
::method arg
  expose args
  use strict arg name
  do a over args
    if a['NAME'] == name then return a
  end
  return .nil
::method pure
  expose effects calls
  do e over .array~of('SAY', 'STREAM', 'COMMAND', 'ENV', 'DYNAMIC', 'STATE_WRITE', 'MUTATES_ARG')
    if effects~hasIndex(e) then return .false
  end
  return calls~items == 0
::method keys class
  use strict arg d
  return d~allIndexes~sort~makeString('L', ',')
::method needsText
  expose args
  out = .array~new
  do a over args
    t = 'A' || a['POS'] || '=' || a['NAME']~lower || ':' || .SlamContract~keys(a['KINDS'])
    if a['MESSAGES']~items > 0 then t = t || '~' || .SlamContract~keys(a['MESSAGES'])~lower
    do c over a['CONSTRAINTS']
      t = t || ' [' || c || ']'
    end
    out~append(t)
  end
  return out~makeString('L', ' ; ')
::method canonicalText
  expose owner selector kind gives effects
  pureText = 'IMPURE'
  if self~pure then pureText = 'PURE'
  return kind owner || '~' || selector '| NEEDS' self~needsText '| GIVES' .SlamContract~keys(gives) '| EFFECTS' .SlamContract~keys(effects) '|' pureText
/* Kind compatibility: can a value of kind GIVEN satisfy a need with kinds NEEDED? */
::method satisfies class
  use strict arg given, needed
  if needed~items == 0 then return .true
  g = given
  if g~left(7) == 'OBJECT:' then g = 'OBJECT'
  if needed~hasIndex(g) then return .true
  if g == 'ARRAY' then if needed~hasIndex('COLLECTION') then return .true
  if g == 'DIRECTORY' then if needed~hasIndex('COLLECTION') then return .true
  if g == 'ARRAY' | g == 'DIRECTORY' then if needed~hasIndex('OBJECT') then return .true
  if g == 'NUMBER' then if needed~hasIndex('STRING') then return .true
  return .false

::class SlamContractExtractor public
::attribute shaper
::constant ARITH '+ - * / // % **'
::constant COMPARE '= == \= \== < > <= >= <> >< << >> <<= >>= \< \> \<< \>>'
::constant LOGIC '& | && \'
::constant COLLECTION_MSGS 'ITEMS APPEND AT PUT SECTION MAKEARRAY ALLITEMS ALLINDEXES SUPPLIER HASINDEX HASITEM SORT SORTWITH FIRST LAST SIZE REMOVE DELETE INSERT ITEM INDEX FIRSTITEM LASTITEM DIMENSION EMPTY ISEMPTY'
::constant MUTATING_MSGS 'APPEND PUT DELETE REMOVE INSERT SORT SORTWITH EMPTY SETENTRY SETMETHOD'
::constant STREAM_FUNCS 'CHAROUT LINEOUT LINEIN CHARIN CHARS LINES STREAM SYSFILEDELETE SYSFILETREE SYSMKDIR SYSRMDIR SYSFILEMOVE SYSFILECOPY QUALIFY'
::constant NUMBER_FUNCS 'LENGTH POS LASTPOS ABS MAX MIN WORDS TRUNC FORMAT X2D C2D COMPARE VERIFY WORDPOS WORDINDEX WORDLENGTH COUNTSTR SIGN RANDOM'
::constant STRING_FUNCS 'SUBSTR LEFT RIGHT STRIP TRANSLATE COPIES REVERSE CHANGESTR D2X C2X X2C D2C SPACE WORD SUBWORD LOWER UPPER CENTER CENTRE INSERT OVERLAY DELSTR DELWORD B2X X2B DATATYPE DATE TIME'
::constant BUILTIN_CLASSES 'TRUE FALSE NIL ARRAY LIST QUEUE DIRECTORY TABLE RELATION SET BAG STEM STRINGTABLE IDENTITYTABLE MUTABLEBUFFER STRING OBJECT NUMERICCOMPARATOR CASELESSCOMPARATOR COMPARATOR SUPPLIER ENDOFLINE CONTEXT METHODS RS LINE LOCAL ENVIRONMENT STREAM FILE INPUT OUTPUT ERROR STDIN STDOUT STDERR TRACEOUTPUT DEBUGINPUT'
::constant BIFS 'ABBREV ABS ADDRESS ARG B2X BITAND BITOR BITXOR C2D C2X CENTER CENTRE CHANGESTR CHARIN CHAROUT CHARS COMPARE CONDITION COPIES COUNTSTR D2C D2X DATATYPE DATE DELSTR DELWORD DIGITS ERRORTEXT FORM FORMAT FUZZ INSERT LASTPOS LEFT LENGTH LINEIN LINEOUT LINES LOWER MAX MIN OVERLAY POS QUALIFY QUEUED RANDOM REVERSE RIGHT RXFUNCADD RXFUNCQUERY SIGN SOURCELINE SPACE STREAM STRIP SUBSTR SUBWORD SYMBOL TIME TRACE TRANSLATE TRUNC UPPER VALUE VAR VERIFY WORD WORDINDEX WORDLENGTH WORDPOS WORDS X2B X2C X2D XRANGE'
::method init
  expose shaper
  shaper = .SlamShaper~new
::method opText
  use strict arg t
  if t~kind == 'OP' then return t~text
  return ''
/* Kind of an expression (tokens), given local kinds and the argument table. */
::method exprKind
  expose shaper
  use strict arg toks, locals, argTable
  if toks~items == 0 then return 'NONE'
  if toks~items == 1 then return self~atomKind(toks[1], locals, argTable)
  depth = 0
  hasArith = .false; hasConcat = .false; hasCompare = .false
  do i = 1 to toks~items
    t = toks[i]
    op = self~opText(t)
    if op == '(' | op == '[' then depth += 1
    if op == ')' | op == ']' then depth -= 1
    if depth \= 0 then iterate
    if op == '' then iterate
    if wordpos(op, self~ARITH) > 0 then if i > 1 then hasArith = .true
    if op == '||' then hasConcat = .true
    if wordpos(op, self~COMPARE) > 0 | wordpos(op, self~LOGIC) > 0 then hasCompare = .true
  end
  if hasCompare then return 'BOOLEAN'
  if hasConcat then return 'STRING'
  if hasArith then return 'NUMBER'
  first = toks[1]
  if first~kind == 'DOTIDENT' then if toks~items >= 3 then if self~opText(toks[2]) == '~' then do
    m = toks[3]~text
    cls = first~text
    if m == 'NEW' | m == 'OF' then do
      if wordpos(cls, 'ARRAY LIST QUEUE') > 0 then return 'ARRAY'
      if wordpos(cls, 'DIRECTORY STEM TABLE RELATION SET BAG STRINGTABLE IDENTITYTABLE') > 0 then return 'DIRECTORY'
      if cls == 'MUTABLEBUFFER' then return 'STRING'
      return 'OBJECT:' || cls~lower
    end
  end
  if first~kind == 'IDENT' then if toks~items >= 2 then if self~opText(toks[2]) == '(' then do
    if wordpos(first~text, self~NUMBER_FUNCS) > 0 then return 'NUMBER'
    if wordpos(first~text, self~STRING_FUNCS) > 0 then return 'STRING'
  end
  if first~kind == 'IDENT' then if first~text == 'SELF' then if toks~items == 1 then return 'SELF'
  if first~kind == 'IDENT' then if first~text == 'SELF' then if toks~items >= 3 then if self~opText(toks[2]) == '~' then if toks[3]~text == 'NEW' then return 'OBJECT:SELF'
  return 'UNKNOWN'
::method atomKind
  use strict arg t, locals, argTable
  select
    when t~kind == 'STRING' then return 'STRING'
    when t~kind == 'NUMBER' then return 'NUMBER'
    when t~kind == 'DOTIDENT' then do
      if t~text == 'TRUE' | t~text == 'FALSE' then return 'BOOLEAN'
      if t~text == 'NIL' then return 'NIL'
      return 'OBJECT:' || t~text~lower
    end
    when t~kind == 'IDENT' then do
      if t~text == 'SELF' then return 'SELF'
      if argTable~hasIndex(t~text) then return 'ARG' || argTable[t~text]
      if locals~hasIndex(t~text) then return locals[t~text]
      return 'UNKNOWN'
    end
    otherwise return 'UNKNOWN'
  end
::method extract
  expose shaper
  use strict arg unit
  k = .SlamContract~new(unit~owner, unit~selector, unit~kind)
  clauses = .SlamClauses~build(unit~tokens)
  ctx = shaper~unitContext(clauses)
  fields = ctx['FIELDS']
  /* argument positions, from the first clause that binds arguments */
  argTable = .directory~new
  do c over clauses
    instr = shaper~instructionOf(c)
    if wordpos(instr, 'USE ARG PARSE') == 0 then iterate
    if shaper~clauseClass(c) \== 'ENTRY' then iterate
    argAt = 0
    if instr == 'ARG' then argAt = 1
    else do i = 2 to c~items
      if c[i]~kind == 'IDENT' then if c[i]~text == 'ARG' then do
        argAt = i
        leave
      end
    end
    pos = 1; depth = 0; expectName = .true
    do i = argAt + 1 to c~items
      t = c[i]
      op = self~opText(t)
      if op == '(' then depth += 1
      if op == ')' then depth -= 1
      if depth > 0 then iterate
      if op == ',' then do
        pos += 1
        expectName = .true
        iterate
      end
      if t~kind == 'IDENT' then if expectName | instr == 'PARSE' | instr == 'ARG' then do
        name = shaper~pieces(t~text)[1]
        if \argTable~hasIndex(name) then do
          argTable[name] = pos
          a = .directory~new
          a['POS'] = pos; a['NAME'] = name
          a['KINDS'] = .directory~new; a['MESSAGES'] = .directory~new; a['CONSTRAINTS'] = .array~new
          k~args~append(a)
        end
        if instr == 'USE' then expectName = .false
      end
    end
    leave
  end
  locals = .directory~new
  do ci = 1 to clauses~items
    c = clauses[ci]
    instr = shaper~instructionOf(c)
    subs = shaper~subkeywords(instr)
    /* effects by instruction */
    select
      when instr == 'SAY' then k~effects['SAY'] = .true
      when instr == 'ADDRESS' then k~effects['COMMAND'] = .true
      when instr == 'INTERPRET' then k~effects['DYNAMIC'] = .true
      when instr == 'RAISE' then k~effects['RAISES'] = .true
      otherwise nop
    end
    /* assignment: track local kinds; field writes */
    if c~items >= 2 then if c[1]~kind == 'IDENT' then if self~opText(c[2]) == '=' then do
      target = shaper~pieces(c[1]~text)[1]
      rhs = c~section(3)
      if fields~hasIndex(target) then do
        k~effects['STATE_WRITE'] = .true
        k~fieldsWritten[target] = .true
      end
      else if \argTable~hasIndex(target) then locals[target] = self~exprKind(rhs, locals, argTable)
    end
    /* self~attr = v */
    if c~items >= 4 then if c[1]~kind == 'IDENT' then if c[1]~text == 'SELF' then if self~opText(c[2]) == '~' then if self~opText(c[4]) == '=' then k~effects['STATE_WRITE'] = .true
    /* guards: "if cond then raise|return|signal|exit" constrains the arguments it mentions */
    if instr == 'IF' then if ci < clauses~items then do
      nxt = shaper~instructionOf(clauses[ci + 1])
      isGuard = wordpos(nxt, 'RAISE RETURN SIGNAL EXIT') > 0
      if isGuard then if ci + 2 <= clauses~items then if shaper~instructionOf(clauses[ci + 2]) == 'ELSE' then isGuard = .false
      if isGuard then do
        cond = .array~new
        mentioned = .directory~new
        do i = 2 to c~items - 1
          t = c[i]
          if t~kind == 'IDENT' then if argTable~hasIndex(t~text) then mentioned[t~text] = .true
          select
            when t~kind == 'STRING' then cond~append("'" || t~text || "'")
            when t~kind == 'IDENT' then cond~append(t~text~lower)
            when t~kind == 'DOTIDENT' then cond~append('.' || t~text~lower)
            otherwise cond~append(t~text)
          end
        end
        do name over mentioned~allIndexes
          k~arg(name)['CONSTRAINTS']~append('not(' || cond~makeString('L', ' ') || ')')
        end
      end
    end
    /* per token: argument kinds, messages, effects */
    do i = 1 to c~items
      t = c[i]
      r = shaper~tokenRole(c, i, instr, subs)
      if r == 'FUNCTION' then do
        fname = t~text
        if wordpos(fname, self~STREAM_FUNCS) > 0 then k~effects['STREAM'] = .true
        else if wordpos(fname, self~BIFS) == 0 then do
          if fname~left(3) \== 'SYS' then k~calls[fname~lower] = .true
          else k~effects['STREAM'] = .true
        end
      end
      if t~kind == 'DOTIDENT' then do
        if wordpos(t~text, 'LOCAL ENVIRONMENT') > 0 then k~effects['ENV'] = .true
        if wordpos(t~text, 'STREAM FILE INPUT OUTPUT ERROR STDIN STDOUT STDERR TRACEOUTPUT DEBUGINPUT') > 0 then k~effects['STREAM'] = .true
        if wordpos(t~text, self~BUILTIN_CLASSES) == 0 then k~classesUsed[t~text~lower] = .true
        if i + 2 <= c~items then if self~opText(c[i + 1]) == '~' then if c[i + 2]~text == 'NEW' then k~effects['CREATES'] = .true
      end
      if r \== 'VAR' then iterate
      name = shaper~pieces(t~text)[1]
      if fields~hasIndex(name) then k~fieldsRead[name] = .true
      if \argTable~hasIndex(name) then iterate
      /* A value shown in an error or a message is not a need: 'raise ... array("bad" a)' does not make
         a a STRING (found when the fixed rx_mod_inverse let a STRING through the gate). */
      if instr == 'RAISE' | instr == 'SAY' then iterate
      a = k~arg(name)
      nxt = ''
      if i < c~items then nxt = self~opText(c[i + 1])
      prv = ''
      if i > 1 then prv = self~opText(c[i - 1])
      if wordpos(nxt, self~ARITH) > 0 then a['KINDS']['NUMBER'] = .true
      if wordpos(prv, '+ * / // % **') > 0 then a['KINDS']['NUMBER'] = .true
      if prv == '-' then if i > 2 then if c[i - 2]~kind \== 'OP' then a['KINDS']['NUMBER'] = .true
      if nxt == '||' | prv == '||' then a['KINDS']['STRING'] = .true
      if nxt == '[' then a['KINDS']['COLLECTION'] = .true
      if wordpos(nxt, self~COMPARE) > 0 then if i + 2 <= c~items then if c[i + 2]~kind == 'NUMBER' then a['KINDS']['NUMBER'] = .true
      if wordpos(prv, self~COMPARE) > 0 then if i > 2 then if c[i - 2]~kind == 'NUMBER' then a['KINDS']['NUMBER'] = .true
      if prv == '' then if i > 1 then if c[i - 1]~kind == 'IDENT' then if c[i - 1]~text == 'OVER' then a['KINDS']['COLLECTION'] = .true
      if nxt == '~' | nxt == '~~' then if i + 2 <= c~items then do
        m = c[i + 2]~text
        a['MESSAGES'][m] = .true
        if wordpos(m, self~COLLECTION_MSGS) > 0 then a['KINDS']['COLLECTION'] = .true
        else a['KINDS']['OBJECT'] = .true
        if wordpos(m, self~MUTATING_MSGS) > 0 then k~effects['MUTATES_ARG'] = .true
      end
    end
    /* what it gives */
    if instr == 'RETURN' then do
      if c~items == 1 then k~gives['NONE'] = .true
      else do
        gk = self~exprKind(c~section(2), locals, argTable)
        if gk == 'UNKNOWN' then if c~items == 2 then if c[2]~kind == 'IDENT' then if fields~hasIndex(shaper~pieces(c[2]~text)[1]) then gk = 'FIELD'
        k~gives[gk] = .true
      end
    end
  end
  if k~gives~items == 0 then k~gives['NONE'] = .true
  return k
