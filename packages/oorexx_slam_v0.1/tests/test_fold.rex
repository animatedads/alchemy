/* Identical code folding, learned from BOLT's IdenticalCodeFolding and run on SLAM's stores.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: work | tests/fixtures | BOLT store | rx2cpp store (both ingested with literals)
 */
signal on syntax name onSyntax
parse arg work '|' fixtures '|' boltDb '|' rxDb
checks = 0
call check work \= '' & fixtures \= '' & boltDb \= '' & rxDb \= '', 'arguments'

say '== 1. the fixture: a fold that needs another fold first'
db = work || '/fold.db'
call SysFileDelete db
st = .SlamStore~new(db)
text = charin(fixtures || '/fold.cls', 1, chars(fixtures || '/fold.cls')); call stream fixtures || '/fold.cls', 'C', 'CLOSE'
seg = .SlamSegmenter~new
st~begin
do u over .SlamUnitSplitter~new~split(text)
  uid = st~ingestUnit(fixtures || '/fold.cls', u, seg~segmentUnit(u))
end
st~commit
f = .SlamFold~new(st)
f~load('%')
p = f~run(1)
call check p~makeString('L', ' ') == '1 1 0', 'folds per pass: 1, 1, 0 (areaB into areaA; then totalB into totalA, identical only once areaB is folded; then none)'
names = .directory~new
do child over f~foldedInto~allIndexes
  names[f~units[child]['SEL']] = f~units[f~foldedInto[child]]['SEL']
end
call check names['AREAB'] == 'AREAA' & names['TOTALB'] == 'TOTALA', 'areaB -> areaA, totalB -> totalA'
call check \names~hasIndex('NOTTHESAME'), 'notTheSame (y + 2, not y + 1) is not folded: literals are compared, as BOLT compares constants'
st~close

say '== 2. BOLT folded at source level'
f = .SlamFold~new(.SlamStore~new(boltDb))
f~load('%')
p = f~run(1)
say '      folds per pass' p~makeString('L', ' ')
call check p~makeString('L', ' ') == '392 8 0', 'BOLT''s source: 392 units fold in the first pass, 8 more in the second, then none (BOLT''s fixpoint, on BOLT)'
g = .SlamFold~new(.SlamStore~new(boltDb)); g~load('%')
second = 0
do child over f~foldedInto~allIndexes
  if g~resolved(child) \== g~resolved(f~foldedInto[child]) then second += 1
end
call check second = 8, 'the 8 second-pass folds are the ones whose calls differ until their callees are folded'
f5 = .SlamFold~new(.SlamStore~new(boltDb)); f5~load('%')
call check f5~run(5)~makeString('L', ' ') == '0', 'at 5 segments or more, nothing in BOLT folds: the folds are small accessors'

say '== 3. rx2cpp''s ooRexx: the same code under other names'
f = .SlamFold~new(.SlamStore~new(rxDb))
f~load('%.cls')
p = f~run(5)
pairs = ''
do child over f~foldedInto~allIndexes
  pairs = pairs f~units[child]['OWNER'] || '~' || f~units[child]['SEL'] || '->' || f~units[f~foldedInto[child]]['OWNER'] || '~' || f~units[f~foldedInto[child]]['SEL']
end
say '      ' pairs~strip
call check p~makeString('L', ' ') == '3 0', 'three folds of 5 segments or more'
call check pairs~pos('RXSTMTIF~BRANCH->RXSTMTSELECT~WHENBODY') > 0, 'StmtIf~branch and StmtSelect~whenBody are the same code (a bare DO block, else one statement), in two rule classes'
call check pairs~pos('BIFDEFINITION~JOINED->RXCPPEMITTER~BODY') > 0, 'BifDefinition~joined and RxCppEmitter~body are the same line-joining loop'

say 'FOLD TEST: PASS (' || checks || ' checks)'
exit 0

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

::requires 'SlamSegmenter.cls'
::requires 'SlamFold.cls'
