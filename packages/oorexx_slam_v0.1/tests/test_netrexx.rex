/* SLAM's fourth language: NetRexx, the other object-oriented Rexx, beside ooRexx.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: work | NetRexx qtime.nrx | ooRexx samples/qtime.rex | sysutils.nrx | NetRexx run outputs | ooRexx run outputs |
 *       NetRexx -> Java translation summary (tests/netrexx/translate_pairs.rex)
 */
signal on syntax name onSyntax
parse arg work '|' nrxQtime '|' rexxQtime '|' sysutils '|' nrxOut '|' rexxOut '|' transSummary
checks = 0
call check work \= '' & nrxQtime \= '' & rexxQtime \= '' & sysutils \= '' & nrxOut \= '' & rexxOut \= '' & transSummary \= '', 'arguments'

say '== 1. lexer: NetRexx written the ooRexx way'
src = 'x = s.length() -- a comment' || '0a'x || 'y = ''it''''s'' -' || '0a'x || '  || this.z /* a /* nested */ comment */' || '0a'x || 'if q = null then nop'
toks = .SlamNrxLexer~new(src)~scan
txt = ''
do t over toks; txt = txt t~text; end
call check txt~strip == 'X = S ~ LENGTH ( ) ; Y = it''s || SELF ~ Z ; IF Q = NIL THEN NOP ; <eof>', 'a.b() is a~b(); this is SELF; null is .nil; -- and nested /* */ are comments; a trailing - joins the next line (got' txt~strip || ')'
call check toks[5]~kind == 'IDENT' & toks[5]~text == 'LENGTH' & toks[20]~kind == 'DOTIDENT', 'symbols are upper case, as Rexx''s are; null is a DOTIDENT, as .nil is'

say '== 2. a NetRexx class: sysutils.nrx (NetRexx''s RexxUtil)'
text = charin(sysutils, 1, chars(sysutils)); call stream sysutils, 'C', 'CLOSE'
units = .SlamNrxSplitter~new~split(text)
seg = .SlamNrxSegmenter~new
call check units~items = 36 & units[1]~owner == 'SYSUTILS', 'sysutils.nrx: 36 methods of class SYSUTILS (got' units~items || ')'
ctor = findUnit(units, 'SYSUTILS')
call check ctor~fields~hasIndex('SEMMUTEXVECTOR') & ctor~fields~hasIndex('RXSTDOUT'), 'properties private ... are the class''s fields'
s1 = seg~segmentUnit(ctor)
call check s1[2]~fine == 'RUN: F1 = vector ( N )' & s1[2]~repeat = 2, 'in the constructor, two properties set the same way: F roles, one node twice'
rq = seg~segmentUnit(findUnit(units, 'SYSREQUESTMUTEXSEM'))
call check rq[1]~fine == 'ENTRY: use arg A1 , A2 = - N', 'method SysRequestMutexSem(handle, timeout = -1) enters as ooRexx''s use arg handle, timeout = -1 does'
call check rq[2]~kind == 'BLOCK' & rq[2]~sequences[1][2][1]~kind == 'LOOP', 'do ... end is a BLOCK, and loop i = 0 to ... is a LOOP'

say '== 3. the same program in both: QTIME (NetRexx''s, and ooRexx''s object-oriented rewrite)'
db = work || '/qtime.db'
call SysFileDelete db
store = .SlamStore~new(db)
call ingest store, nrxQtime, 'NETREXX'
call ingest store, rexxQtime, 'REXX'
rows = store~q("SELECT s.canon AS c FROM instance i JOIN unit u ON u.id = i.unit_id JOIN shape s ON s.id = i.shape_id GROUP BY i.shape_id HAVING sum(u.path LIKE '%.nrx') > 0 AND sum(u.path LIKE '%.rex') > 0")~rows
shared = .directory~new
do r over rows; shared[r['C']] = .true; end
nrxNodes = store~scalar("SELECT count(DISTINCT shape_id) AS n FROM instance i JOIN unit u ON u.id = i.unit_id WHERE u.path LIKE '%.nrx'")
say '      NetRexx nodes' nrxNodes ', shared with ooRexx' rows~items
call check rows~items = 11, '11 of NetRexx QTIME''s' nrxNodes 'nodes are nodes of the ooRexx one, under other names (hour/min/out against hr/mn/ot)'
call check shared~hasIndex('SELECT: select ; when L1 = N then + {SELECT=ARM+}') & shared~hasIndex('BRANCH: if L1 > N then {THEN=RUN ELSE=BRANCH}'), 'among them the 13-arm minutes SELECT and the hour fix-up (if ... else if ...)'
text = charin(rexxQtime, 1, chars(rexxQtime)); call stream rexxQtime, 'C', 'CLOSE'
ru = .SlamUnitSplitter~new~split(text)
rseg = .SlamSegmenter~new
et = rseg~segmentUnit(findUnit(ru, 'ENGLISHTIME'))
call check kindAt(et, 'GUARD')~pos('if L1 // N = N & L2 // N <= N then ; return') > 0, 'ooRexx: "if ... <newline> then return ..." is a GUARD (SLAM''s ooRexx reader read the THEN line as a clause of its own until now)'
ch = rseg~segmentUnit(findUnit(ru, 'CHIME'))
call check kindAt(ch, 'LOOP')~left(17) == 'LOOP: do <loop> L' & kindAt(s1b(), 'LOOP') \== '', 'loop is written as the rx2cpp lexer writes ooRexx 5''s LOOP: DO <loop>, in both languages'
store~close

say '== 4. run: both programs at 206 times through a day'
n = .array~new; r = .array~new
do while lines(nrxOut) > 0; n~append(linein(nrxOut)); end
do while lines(rexxOut) > 0; r~append(linein(rexxOut)); end
call stream nrxOut, 'C', 'CLOSE'; call stream rexxOut, 'C', 'CLOSE'
same = 0; chimes = 0
do k = 1 to min(n~items, r~items)
  parse value n[k] with tn sn
  parse value r[k] with tr sr
  core = sr
  if sr~pos(' (') > 0 then do
    core = sr~left(sr~pos(' (') - 1)
    chimes += 1
  end
  if tn == tr then if core == sn then same += 1
end
say '      times' n~items ' same sentence' same ' ooRexx chimes added' chimes
call check n~items = 206 & r~items = 206 & same = 206, 'the two programs say the same sentence at all 206 times'
call check chimes > 0, 'ooRexx''s rewrite adds chimes on the quarter hours (' || chimes || ' times), from its chime method, which has no NetRexx counterpart'

say '== 5. NetRexx -> Java: translation edges learned from NetRexxC''s own output, predicted on files not seen'
t = .directory~new
do while lines(transSummary) > 0
  parse value linein(transSummary) with k v
  t[k] = v
end
call stream transSummary, 'C', 'CLOSE'
say '      files' t['FILES'] '(' || t['TRAIN_FILES'] 'learned from,' t['TEST_FILES'] 'held out)  edges' t['EDGES'] ' tested edges' t['TESTED_EDGES']
call check t['FILES'] = 288 & t['FAILED'] = 0, '288 NetRexx files translated by NetRexxC and paired line by line with their Java (none unreadable)'
call check t['LOOP_LINE'] == 'BLOCK RUN RUN LABEL LOOP' & t['SELECT_LINE'] == 'BLOCK', 'learned, not told: a loop line becomes BLOCK RUN RUN LABEL LOOP in Java (the for is wrapped with its loop variable), a select becomes a BLOCK'
call check t['KIND_RIGHT'] = 1195 & t['TEST_PAIRS'] = 1273 & t['KIND_RIGHT'] > t['TEST_PAIRS'] - t['KIND_CHANGED'], 'held-out segments: the Java kind predicted right 1195 of 1273 times, above the 1151 of "same kind as NetRexx"'
call check t['LINE_RIGHT'] = 837 & t['LINE_SEEN'] = 1197 & t['LINE_RIGHT'] > t['LINE_SAME'], 'held-out lines: the whole line''s Java kinds predicted right 837 of 1197 times, above the' t['LINE_SAME'] 'of "same kinds as NetRexx"'
call check t['FINE_RIGHT'] = 356 & t['SEEN'] = 642 & t['TESTED_EDGES'] = 189, 'exact Java shape, where the NetRexx shape was seen: 356 of 642; each prediction kept as a test on its edge (189 edges now TESTED)'

say 'NETREXX TEST: PASS (' || checks || ' checks)'
exit 0

s1b: procedure expose rq
  return rq[2]~sequences[1][2]

kindAt: procedure
  use arg segs, kind
  do s over segs
    if s~kind == kind then return s~fine
  end
  return ''

findUnit: procedure
  use arg units, sel
  do u over units
    if u~selector == sel then return u
  end
  raise syntax 93.900 array('no unit' sel)

ingest: procedure
  use arg store, file, lang
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  seg = .SlamLanguages~segmenter(lang)
  store~begin
  do u over .SlamLanguages~splitter(lang)~split(text)
    segs = seg~segmentUnit(u)
    if segs~items > 0 then uid = store~ingestUnit(file, u, segs)
  end
  store~commit
  return

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok then say 'PASS ' label
  else do
    say 'FAIL ' label
    exit 1
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamLanguages.cls'
::requires 'SlamStore.cls'
