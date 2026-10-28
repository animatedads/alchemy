/* SLAM's second language: the Java reader, qualified.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: scratch directory | tests/fixtures/Shapes.java | Federation Bank Java ATM directory | FederationBankAtmGateway.cls
 */
signal on syntax name onSyntax
parse arg work '|' fixture '|' atmDir '|' engineCls
checks = 0
call check work \= '' & fixture \= '' & atmDir \= '' & engineCls \= '', 'arguments: work | fixture | atmDir | engineCls'

say '== 1. lexer: comments, text blocks, escapes, numbers, annotations, generics, lambdas'
src = '@Override /* a; */ x = """' || '0a'x || 'a "q"; b' || '0a'x || '""" + ''\'''' + "a\"b" // c' || '0a'x || ,
      'long n = 1_000L + 0x1F + 1e-5 + .5f; List<List<String>> m; f(a -> a::b);'
toks = .SlamJavaLexer~new(src)~scan
kinds = ''
do t over toks; kinds = kinds t~kind~left(1); end
texts = ''
do t over toks; texts = texts t~text; end
call check toks[1]~kind == 'ANNOT' & toks[1]~text == '@Override', 'annotation is one token: @Override'
call check toks[4]~kind == 'STRING' & toks[4]~text~countStr('0a'x) == 2 & toks[4]~text~pos(';') > 0, 'text block is one STRING with its lines and its ;'
call check toks[6]~kind == 'STRING' & toks[6]~text == "'\''" & toks[8]~text == '"a\"b"', 'escaped char and string literals end at the right quote'
call check toks[9]~line == 4, 'line numbers count the text block and the comment (got' toks[9]~line || ')'
nums = .array~new
do t over toks; if t~kind == 'NUMBER' then nums~append(t~text); end
call check nums~makeString('L', ' ') == '1_000L 0x1F 1e-5 .5f', 'numbers: 1_000L 0x1F 1e-5 .5f (got' nums~makeString('L', ' ') || ')'
call check texts~pos('List < List < String > > m') > 0 & texts~pos('a -> a :: b') > 0, 'generics close as two > tokens; -> and :: are one token each'

say '== 2. fixture (compiled by javac): units, kinds, roles'
text = charin(fixture, 1, chars(fixture)); call stream fixture, 'C', 'CLOSE'
units = .SlamJavaSplitter~new~split(text)
seg = .SlamJavaSegmenter~new
call check units~items = 9, 'Shapes.java: 9 units (got' units~items || ')'
names = ''
do u over units; names = names u~kind || ':' || u~owner || '~' || u~selector; end
call check names~strip == 'CTOR:Shapes~Shapes METHOD:Shapes~clamp METHOD:Shapes~kind METHOD:Shapes~arrow METHOD:Shapes~sum METHOD:Shapes~read CTOR:Shapes.Mode~Mode METHOD:Shapes.Mode~label METHOD:Shapes.Pair~size', 'owners nest (Shapes.Mode, Shapes.Pair); constructors are CTOR'
call check units[1]~fields~hasIndex('count') & units[1]~fields~hasIndex('limit') & units[1]~fields~hasIndex('r') & \units[1]~fields~hasIndex('Runnable'), 'fields: two in one declaration, and a lambda-valued one'
ctor = seg~segmentUnit(units[1])
call check kindsOf(ctor) == 'ENTRY GUARD RUN', 'constructor: ENTRY GUARD RUN (got' kindsOf(ctor) || ')'
call check ctor[2]~repeat = 2, 'range guard on mutationRate and crossoverRate is one node (the one in { } too)'
call check ctor[2]~fine == 'GUARD: if ( A1 < N || A1 > N ) ; throw new .illegalargumentexception ( S )', 'guard shape:' ctor[2]~fine
call check ctor[3]~fine == 'RUN: this . M = A1 +', 'two field setters collapse to one clause marked +'
clamp = seg~segmentUnit(units[2])
call check clamp[2]~fine == 'GUARD: if ( F1 > A1 ) ; return A1' & clamp[2]~binding~pos('A1=limit') > 0, 'parameter limit hides field limit: A1, not F'
sel = seg~segmentUnit(units[3])[2]
call check sel~kind == 'SELECT' & sel~sequences[1][2]~items = 4, 'switch is a SELECT with 4 ARMs (case 2: falls through, empty)'
sum = seg~segmentUnit(units[5])
call check kindsOf(sum) == 'ENTRY RUN LABEL LOOP RUN LOOP BLOCK EXIT', 'label, for-each, do-while, synchronized: ENTRY RUN LABEL LOOP RUN LOOP BLOCK EXIT (got' kindsOf(sum) || ')'
call check sum[4]~sequences[1][2][2]~fine == 'GUARD: if ( L1 > N ) ; break L2', 'break with a label is a GUARD'
rd = seg~segmentUnit(units[6])
call check rd[2]~kind == 'TRY' & rd[2]~fine~pos('{TRY=RUN,GUARD,EXIT CATCH=EXIT FINALLY=RUN}') > 0, 'try / multi-catch / finally: one TRY with three sequences'
call check rd[2]~sequences[1][2][2]~fine == 'GUARD: if ( L1 == .nil ) ; return .nil', 'null is .nil, as in ooRexx'
pair = seg~segmentUnit(units[9])
call check pair[1]~fine == 'EXIT: return F1 . size ( ) + F2 . length ( )', 'record components are fields (F roles)'

say '== 3. real estate code: the Federation Bank Java ATM'
atm = atmDir || '/src/main/java/com/federationbank/atm/AtmService.java'
text = charin(atm, 1, chars(atm)); call stream atm, 'C', 'CLOSE'
units = .SlamJavaSplitter~new~split(text)
call check units~items = 46, 'AtmService.java: 46 units (got' units~items || ')'
wo = findUnit(units, 'AtmService', 'withdrawOffline')
segs = seg~segmentUnit(wo)
call check kindsOf(segs) == 'ENTRY GUARD RUN LOOP GUARD RUN RUN RUN BRANCH RUN RUN GUARD EXIT', 'withdrawOffline: ENTRY GUARD RUN LOOP ... GUARD EXIT (got' kindsOf(segs) || ')'
loop = segs[4]
try = loop~sequences[1][2][3]
call check try~kind == 'TRY', 'the authority checks sit in a TRY inside the LOOP'
inner = try~sequences[1][2]
call check kindsOf(inner) == 'GUARD GUARD GUARD GUARD GUARD GUARD RUN GUARD RUN EXIT', 'seven checks: six GUARDs, expiry parsed, the expiry GUARD, then take it and break'
call check inner[1]~binding~pos('F1=terminalId') > 0 & inner[1]~binding~pos('A1=session') > 0, 'terminalId is a field of AtmService (F1); session is an argument (A1)'

say '== 4. one store, two languages; Task runs on Java nodes'
db = work || '/java.db'
call SysFileDelete db
store = .SlamStore~new(db)
r1 = ingestTree(store, atmDir, 'JAVA')
r2 = ingestFile(store, engineCls, 'REXX')
call check r1[1] > 0 & r2[1] > 0, 'ingested' r1[1] 'Java units and' r2[1] 'ooRexx units into one store'
again = ingestTree(store, atmDir, 'JAVA')
call check again[1] = 0, 're-ingest adds no Java unit'
javaNodes = store~scalar("SELECT count(DISTINCT i.shape_id) AS n FROM instance i JOIN unit u ON u.id = i.unit_id WHERE u.path LIKE '%.java'")
rexxNodes = store~scalar("SELECT count(DISTINCT i.shape_id) AS n FROM instance i JOIN unit u ON u.id = i.unit_id WHERE u.path NOT LIKE '%.java'")
both = store~scalar("SELECT count(*) AS n FROM (SELECT i.shape_id FROM instance i JOIN unit u ON u.id = i.unit_id GROUP BY i.shape_id HAVING sum(u.path LIKE '%.java') > 0 AND sum(u.path NOT LIKE '%.java') > 0)")
say '      Java nodes' javaNodes '  ooRexx nodes' rexxNodes '  nodes in both' both
shared = store~q("SELECT s.canon AS c FROM instance i JOIN unit u ON u.id = i.unit_id JOIN shape s ON s.id = i.shape_id GROUP BY i.shape_id HAVING sum(u.path LIKE '%.java') > 0 AND sum(u.path NOT LIKE '%.java') > 0 ORDER BY 1")~rows
sharedText = ''
do row over shared; sharedText = sharedText || row['C'] || '|'; end
call check sharedText == 'EXIT: return A1|EXIT: return F1|EXIT: return L1|', 'with no translation, the languages share 3 nodes: return an argument, a field, a local (an accessor is one node in both)'
g1 = store~findShape(inner[1]~fine)
brk = store~findShape(inner[10]~fine)
call check g1 \== '' & brk \== '', 'the first check and the break are stored nodes'
t = .Task~new('reach the break of the offline authority search', store)
t~requirement('reach break', g1, brk, 'PRIOR', 12)
rep = t~run(100)
call check t~state == 'DONE' & t~nodeMap[1]~items = 10, 'Task finds the 9-edge path through the checks (PRIOR, from the code)'
t2 = .Task~new('same, TESTED only', store)
t2~requirement('reach break', g1, brk, 'TESTED', 12)
rep = t2~run(100)
call check t2~state == 'BLOCKED', 'with no recorded test on Java edges, a TESTED search is BLOCKED'
p = t~nodeMap[1]
store~begin
do k = 1 to p~items - 1
  do 3; store~record(p[k], p[k + 1], .true); end
end
store~commit
t3 = .Task~new('same, after tests', store)
t3~requirement('reach break', g1, brk, 'TESTED', 12)
rep = t3~run(100)
call check t3~state == 'DONE', 'after outcomes are recorded on the Java edges, the TESTED search is DONE'
store~close

say 'JAVA READER TEST: PASS (' || checks || ' checks)'
exit 0

kindsOf: procedure
  use arg segs
  out = ''
  do s over segs; out = out s~kind; end
  return out~strip

findUnit: procedure
  use arg units, owner, sel
  do u over units
    if u~owner == owner then if u~selector == sel then return u
  end
  raise syntax 93.900 array('no unit' owner || '~' || sel)

ingestTree: procedure
  use arg store, dir, lang
  call SysFileTree dir || '/*.java', 'f.', 'FSO'
  added = 0; dup = 0
  do i = 1 to f.0
    r = ingestFile(store, f.i, lang)
    added += r[1]; dup += r[2]
  end
  return .array~of(added, dup)

ingestFile: procedure
  use arg store, file, lang
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  splitter = .SlamLanguages~splitter(lang); seg = .SlamLanguages~segmenter(lang)
  store~begin
  added = 0; dup = 0
  do u over splitter~split(text)
    segs = seg~segmentUnit(u)
    if segs~items == 0 then iterate
    if store~ingestUnit(file, u, segs) == 0 then dup += 1
    else added += 1
  end
  store~flushEdges
  store~commit
  return .array~of(added, dup)

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
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamSegmenter.cls'
::requires 'SlamLanguages.cls'
::requires 'SlamStore.cls'
::requires 'SlamTask.cls'
