/* SLAM's third language: C++. The reader, the ooRexx interpreter's own source, and the built-in
 * function contracts read from two C++ codebases (the interpreter and the rx2cpp native pack),
 * predicted, then run on both.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: work | tests/fixtures/shapes.cpp | interpreter dir | rx2cpp external/bif dir | Java fixture |
 *       cases file | interpreter outcomes | native outcomes
 */
signal on syntax name onSyntax
parse arg work '|' fixture '|' interpDir '|' bifDir '|' javaFixture '|' casesFile '|' interpOut '|' nativeOut
checks = 0
call check work \= '' & fixture \= '' & interpDir \= '' & bifDir \= '' & javaFixture \= '' & casesFile \= '' & interpOut \= '' & nativeOut \= '', 'arguments'

say '== 1. lexer: preprocessor lines, raw strings, ::, ->, nullptr, if constexpr'
src = '#define A(x) \' || '0a'x || '  (x)' || '0a'x || 'auto s = R"q(one "two"; {' || '0a'x || 'three)q";' || '0a'x || 'if constexpr (a::b->c == nullptr) f();'
toks = .SlamCppLexer~new(src)~scan
txt = ''
do t over toks; txt = txt t~text; end
call check toks[1]~text == 'auto' & toks[1]~line == 3, 'a #define and its \ continuation are dropped; line numbers stay right (auto on line 3)'
call check toks[4]~kind == 'STRING' & toks[5]~text == ';' & toks[5]~line == 4, 'a raw string with quotes, ; and { is one STRING, and keeps its line break'
call check txt~strip == 'auto s = "R" ; if ( a :: b -> c == nullptr ) f ( ) ;', 'if constexpr reads as if; :: and -> are one token each (got' txt~strip || ')'

say '== 2. fixture (checked by g++): units, owners, kinds, roles'
text = charin(fixture, 1, chars(fixture)); call stream fixture, 'C', 'CLOSE'
units = .SlamCppSplitter~new~split(text)
seg = .SlamCppSegmenter~new
names = ''
do u over units; names = names u~kind || ':' || u~owner || '~' || u~selector; end
call check names~strip == 'CTOR:Rate~Rate METHOD:Rate~clamp FUNCTION:~total FUNCTION:~pick', 'units: Rate::Rate and Rate::clamp take their class as owner; free functions none (got' names~strip || ')'
call check units[1]~fields~hasIndex('mutationRate') & units[1]~fields~hasIndex('limit'), 'a method defined outside its class sees the class''s fields, a brace-initialised one too'
ctor = seg~segmentUnit(units[1])
call check kindsOf(ctor) == 'ENTRY GUARD RUN' & ctor[2]~repeat = 2, 'constructor: ENTRY GUARD RUN; the range guard on two parameters is one node (the one in { } too)'
call check ctor[3]~fine == 'RUN: this -> M = A1 +', 'two this->field setters collapse to one clause marked +'
clamp = seg~segmentUnit(units[2])
call check clamp[2]~binding~pos('A1=limit') > 0, 'parameter limit hides field limit: A1'
tot = seg~segmentUnit(units[3])
call check kindsOf(tot) == 'ENTRY RUN LOOP EXIT' & tot[3]~sequences[1][2][1]~kind == 'GUARD', 'template function: range-for LOOP with an if constexpr GUARD'
pk = seg~segmentUnit(units[4])
call check kindsOf(pk) == 'ENTRY GUARD SELECT RUN LOOP TRY' & pk[2]~fine == 'GUARD: if ( A1 == .nil ) ; return - N', 'nullptr is .nil; switch, do-while, try / catch (...)'

say '== 3. the ooRexx interpreter''s own source'
bfFile = interpDir || '/expression/BuiltinFunctions.cpp'
text = charin(bfFile, 1, chars(bfFile)); call stream bfFile, 'C', 'CLOSE'
bf = .SlamCppSplitter~new~split(text)
builtins = 0
do u over bf
  if u~owner == 'BUILTIN' then builtins += 1
end
call check builtins = 81, 'BuiltinFunctions.cpp: 81 BUILTIN(X) units, each named X (got' builtins || ')'
center = findUnit(bf, 'BUILTIN', 'CENTER'); substr = findUnit(bf, 'BUILTIN', 'SUBSTR')
sc = seg~segmentUnit(center); ss = seg~segmentUnit(substr)
call check kindsOf(sc) == 'RUN RUN EXIT' & sc[2]~fine == ss[2]~fine, 'CENTER and SUBSTR share their argument-reading node:' sc[2]~fine

say '== 4. three languages, one store'
db = work || '/cpp.db'
call SysFileDelete db
store = .SlamStore~new(db)
call ingest store, fixture, 'CPP'
call ingest store, javaFixture, 'JAVA'
call ingest store, interpDir || '/expression/BuiltinFunctions.cpp', 'CPP'
rows = store~q("SELECT s.canon AS c FROM instance i JOIN unit u ON u.id = i.unit_id JOIN shape s ON s.id = i.shape_id GROUP BY i.shape_id HAVING sum(u.path LIKE '%.cpp') > 0 AND sum(u.path LIKE '%.java') > 0")~rows
sharedSet = .directory~new
do r over rows; sharedSet[r['C']] = .true; end
say '      nodes shared by C++ and Java, no translation:' rows~items
call check rows~items = 10, 'C++ and Java share 10 nodes with no translation (they share a statement grammar)'
call check sharedSet~hasIndex('LOOP: do while ( L1 < N ) {LOOP=RUN}') & sharedSet~hasIndex('ARM: case N : {ARM=EXIT}') & sharedSet~hasIndex('ENTRY: double A1 , double A2'), 'whole structures among them: the do-while LOOP, a case ARM, the two-double ENTRY'
store~close

say '== 5. BIF contracts read from two C++ codebases'
ip = .BifInterpreter~new
do f over .array~of('classes/StringClass.cpp', 'classes/StringClassSub.cpp', 'classes/StringClassMisc.cpp', 'classes/StringClassWord.cpp', 'classes/StringClassBit.cpp', 'classes/StringClassConversion.cpp', 'classes/support/StringUtil.cpp')
  ip~addMethods(interpDir || '/' || f)
end
interp = ip~read(bfFile)
native = .BifNative~new~read(bifDir || '/native/rxbif.cpp')
both = 0; arity = 0; same = 0
do nm over native~allIndexes
  if \interp~hasIndex(nm) then iterate
  both += 1
  a = interp[nm]; b = native[nm]
  if a~min = b~min & a~max = b~max then arity += 1
  s = .true
  do p = 1 to max(a~max, b~max)
    if \sameKind(a~kindAt(p), b~kindAt(p)) then s = .false
  end
  if s then same += 1
end
call check native~items = 37 & both = 36, 'native pack: 37 BIFs in kSpecs, 36 also in the interpreter (got' native~items both || ')'
call check arity = 36, 'arity (X_Min..X_Max against kSpecs) is the same for all 36'
call check same = 34, 'argument kinds are the same for 34 of 36; DATE and TIME read option letters inside the BIF body, which SLAM does not read'
cp = interp['COPIES']
call check cp~kindAt(2) == 'LENGTH' & cp~notes~makeString('L', ' ')~pos('RexxString::copies: nonNegativeArgument') > 0, 'COPIES count: required_integer at the BIF, nonNegativeArgument in RexxString::copies, so LENGTH (>= 0)'
sb = interp['SUBSTR']
call check sb~kindAt(2) == 'POSITION' & sb~notes~makeString('L', ' ')~pos('StringUtil::substr') > 0, 'SUBSTR start: followed two calls, BUILTIN -> RexxString::substr -> StringUtil::substr, so POSITION (>= 1)'

say '== 6. predicted, then run on both'
pred = .directory~new
n = 0
do while lines(casesFile) > 0
  parse value linein(casesFile) with id '|' nm '|' pa '|' pb '|' .
  pred[id] = .array~of(nm, pa, pb)
  n += 1
end
call stream casesFile, 'C', 'CLOSE'
io = outcomes(interpOut); no = outcomes(nativeOut)
rightI = 0; wrongI = 0; rightN = 0; wrongN = 0; agree = 0; acc = 0
do id over pred~allIndexes
  p = pred[id]
  if p[2] \== '?' then do
    if p[2] == io[id][1] then rightI += 1
    else wrongI += 1
  end
  if p[3] \== '?' then if no[id][1] \== 'DEFER' then do
    if p[3] == no[id][1] then rightN += 1
    else wrongN += 1
  end
  if io[id][1] == no[id][1] then do
    if io[id][1] \== 'ACCEPT' then agree += 1          /* both refuse: the interpreter's error code has no native twin */
    else if io[id][2] == no[id][2] then agree += 1
  end
  if io[id][1] == 'ACCEPT' then acc += 1
end
say '      cases' n ' interpreter predictions' rightI 'right' wrongI 'wrong   native' rightN 'right' wrongN 'wrong   both sides the same' agree ' accepted' acc
call check n = 201, '201 cases chosen from the two contracts: the lane''s own case, one argument too few and too many, -1 / 0 / x for counts, two-character pads'
call check wrongI = 0 & rightI = 200, 'every interpreter prediction SLAM made held (200 of 200)'
call check wrongN = 0 & rightN = 198, 'every native prediction SLAM made held (198 of 198)'
call check agree = 201, 'the interpreter and the native pack agree on all 201 cases (accept or reject, and the value)'

say 'C++ TEST: PASS (' || checks || ' checks)'
exit 0

outcomes: procedure
  use arg file
  d = .directory~new
  do while lines(file) > 0
    parse value linein(file) with id state val .
    d[id] = .array~of(state, val)
  end
  call stream file, 'C', 'CLOSE'
  return d

sameKind: procedure
  use arg a, b
  if a == b then return .true
  if a == 'LENGTH' then if b == 'COUNT:0' then return .true
  if a == 'POSITION' then if b == 'COUNT:1' then return .true
  return .false

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
::requires 'BifContracts.cls'
