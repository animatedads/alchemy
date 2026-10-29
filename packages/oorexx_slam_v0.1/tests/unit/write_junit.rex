/* SLAM writes JUnit 4 tests for static methods of Java classes or NetRexx classes (NetRexx compiles to
 * Java classes, so JUnit tests it the same way), and a random-input class of the same size for each.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: NRX|JAVA | source files (blank-separated) | classpath of the compiled classes and their runtime |
 *       output directory | summary file
 * The signature of each method (static or not, parameter and return types) is read from the compiled
 * class with javap, so the tests call what the compiler made. SLAM runs each case once through a small
 * observer program to record what the code does now, and checks its own predictions against that.
 * Summary lines: UNIT lang class method arity cases written random right wrong  |  SKIP class.method reason
 */
signal on syntax name onSyntax
parse arg lang '|' files '|' cp '|' outDir '|' summary
call SysMkDir outDir
call SysMkDir outDir || '/obs'
call SysMkDir outDir || '/test'
w = .SlamTestWriter~new
rr = .SlamRuleReader~new
x = .SlamContractExtractor~new
call SysFileDelete summary
testClasses = .array~new
do file over files~makeArray(' ')
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  pkg = packageOf(text, lang)
  if lang == 'NRX' then do
    units = .SlamNrxSplitter~new~split(text)
    cls = file~substr(file~lastPos('/') + 1)
    cls = cls~left(cls~lastPos('.') - 1)
  end
  else do
    units = .SlamJavaSplitter~new~split(text)
    rr~findReaders(units)
    cls = ''
  end
  sigs = .directory~new
  do u over units
    if u~kind \== 'METHOD' then iterate
    owner = cls
    if lang == 'JAVA' then owner = u~owner
    fqn = owner
    if pkg \== '' then fqn = pkg || '.' || owner
    if \sigs~hasIndex(fqn) then sigs[fqn] = javap(cp, fqn, outDir)
    if lang == 'NRX' then do
      rules = rr~rexxUnit(u, file)
      k = x~extract(u)
      names = .array~new
      kinds = .array~new
      do a over k~args
        names~append(a['NAME']~lower)
        kinds~append(a['KINDS']~hasIndex('NUMBER'))
      end
    end
    else do
      rules = rr~javaUnit(u, file)
      names = javaParamNames(u~params)
      kinds = .array~new
      do n over names; kinds~append(.false); end
    end
    sig = findSig(sigs[fqn], u~selector, names~items)
    label = owner || '.' || u~selector
    if sig == .nil then do
      call lineout summary, 'SKIP' label 'no static method with' names~items 'arguments in the compiled class'
      iterate
    end
    if sig['RET'] == 'void' then do
      call lineout summary, 'SKIP' label 'returns nothing'
      iterate
    end
    if names~items == 0 then do
      call lineout summary, 'SKIP' label 'no arguments'
      iterate
    end
    types = sig['TYPES']
    args = .array~new
    usable = .true
    lengthArgs = .array~new
    primitiveNumbers = .true
    do p = 1 to types~items
      t = types[p]~substr(types[p]~lastPos('.') + 1)
      if wordpos(t, 'Rexx String int long short byte double float boolean char') == 0 then usable = .false
      d = .directory~new
      d['POS'] = p
      d['NAME'] = names[p]
      d['TYPE'] = t
      d['NUMBER'] = (wordpos(t, 'int long short byte double float') > 0)
      if t == 'Rexx' then if kinds[p] then do
        d['NUMBER'] = .true
        primitiveNumbers = .false
      end
      args~append(d)
    end
    if \usable then do
      call lineout summary, 'SKIP' label 'an argument of a type SLAM cannot make'
      iterate
    end
    nd = w~nondeterministic(u~tokens)
    if nd \== '' then do
      call lineout summary, 'SKIP' label 'reads random numbers or the clock (' || nd || ')'
      iterate
    end
    kn = w~knobsWith(label, args, lengthArgs, rules)
    if kn == .nil then do
      call lineout summary, 'SKIP' label w~notes[label]
      iterate
    end
    kn['LITERALS'] = w~literalsOf(u~tokens)
    kn['NUMBERS'] = w~numbersOf(u~tokens)
    kn['NOKIND'] = primitiveNumbers
    cases = w~cases(label, kn)
    sel = sig['NAME']
    base = owner || '_' || sel || '_' || types~items
    pr = observe(w, outDir, cp, pkg, fqn, sel, types, cases, 'SlamObs_' || base)
    n = w~countWritten(cases)
    rnd = w~randomCases(kn, n, 20261029)
    prr = observe(w, outDir, cp, pkg, fqn, sel, types, rnd, 'SlamObsR_' || base)
    dir = outDir || '/test'
    if pkg \== '' then do
      dir = dir || '/' || pkg~changeStr('.', '/')
      call mkdirs dir
    end
    tn = 'SLAM_' || base || 'Test'
    jc = w~junitClass(tn, pkg, fqn, sel, types, cases, 'SLAM-chosen cases for' label)
    if jc == .nil then do
      call lineout summary, 'SKIP' label 'no case gives the same outcome twice'
      iterate
    end
    call writeLines dir || '/' || tn || '.java', jc
    rn = 'RAND_' || base || 'Test'
    jc = w~junitClass(rn, pkg, fqn, sel, types, rnd, 'Random cases (the comparison) for' label)
    if jc == .nil then rn = '-'
    else call writeLines dir || '/' || rn || '.java', jc
    q = pkg
    if q \== '' then q = q || '.'
    rq = q || rn
    if rn == '-' then rq = '-'
    call lineout summary, 'UNIT' lang fqn sel types~items file u~line cases~items w~countWritten(cases) w~countWritten(rnd) pr[1] pr[2] q || tn rq
    say left(label, 36) 'cases' cases~items ' written' w~countWritten(cases) ' random' w~countWritten(rnd) ' predicted right' pr[1] ' wrong' pr[2]
  end
end
call stream summary, 'C', 'CLOSE'
exit 0

packageOf: procedure
  use arg text, lang
  do ln over text~makeArray('0a'x)
    s = ln~strip('B', '0d'x)~strip
    if s~word(1)~lower == 'package' then return s~word(2)~strip('T', ';')
    if s~word(1)~lower == 'class' then return ''
  end
  return ''

/* Parameter names of a Java unit: the last identifier before each top-level comma. */
javaParamNames: procedure
  use arg params
  out = .array~new
  last = ''
  depth = 0
  do t over params
    if t~text == '<' then depth += 1
    if t~text == '>' then depth -= 1
    if t~text == ',' then if depth == 0 then do
      out~append(last~lower)
      last = ''
      iterate
    end
    if t~kind == 'IDENT' then last = t~text
  end
  if last \== '' then out~append(last~lower)
  return out

/* Static methods of a compiled class, from javap: an array of directories NAME RET TYPES. */
javap: procedure
  use arg cp, fqn, outDir
  f = outDir || '/javap.txt'
  call SysFileDelete f
  cmd = 'javap -p -cp "' || cp || '"' fqn '>' f '2>/dev/null'
  address system cmd
  if rc \= 0 then say 'javap failed (' || rc || '):' cmd
  out = .array~new
  do while lines(f) > 0
    ln = linein(f)~strip
    if wordpos('static', ln) == 0 then iterate
    if ln~pos('(') == 0 then iterate
    if wordpos('private', ln) > 0 then iterate
    parse var ln head '(' params ')' .
    nm = head~word(head~words)
    ret = head~word(head~words - 1)
    d = .directory~new
    d['NAME'] = nm
    d['RET'] = ret
    t = .array~new
    do p over params~makeArray(',')
      if p~strip \== '' then t~append(p~strip)
    end
    d['TYPES'] = t
    out~append(d)
  end
  call stream f, 'C', 'CLOSE'
  return out

findSig: procedure
  use arg sigs, name, arity
  do s over sigs
    if s['NAME']~upper == name~upper then if s['TYPES']~items == arity then return s
  end
  return .nil

/* Run the cases once through an observer program and read what happened into them. */
observe: procedure
  use arg w, outDir, cp, pkg, fqn, sel, types, cases, obsName
  dir = outDir || '/obs/src'
  if pkg \== '' then dir = dir || '/' || pkg~changeStr('.', '/')
  call mkdirs dir
  call writeLines dir || '/' || obsName || '.java', w~javaObserver(obsName, pkg, fqn, sel, types, cases)
  cls = outDir || '/obs/classes'
  call mkdirs cls
  out = outDir || '/obs/' || obsName || '.out'
  call SysFileDelete out
  fq = obsName
  if pkg \== '' then fq = pkg || '.' || obsName
  address system 'javac -nowarn -cp "' || cp || '" -d "' || cls || '" "' || dir || '/' || obsName || '.java" > "' || out || '.javac" 2>&1'
  /* run it twice, the whole way each time: what differs between the two runs is not written */
  lines = runAll(cls, cp, fq, out, cases~items)
  again = runAll(cls, cp, fq, out, cases~items)
  return w~readObserved(lines, cases, again)

/* Run the observer from case 1; a case that ends the program reports nothing, so it is marked EXIT
   and the run starts again after it. */
runAll: procedure
  use arg cls, cp, fq, out, n
  lines = .array~new
  start = 1
  do while start <= n
    call SysFileDelete out
    address system 'timeout -s KILL 60 java -cp "' || cls || ':' || cp || '"' fq start '>' out '2>/dev/null'
    last = start - 1
    do while lines(out) > 0
      ln = linein(out)
      if ln~word(1) \== '@@SLAM' then iterate
      lines~append(ln)
      last = ln~word(2)
    end
    call stream out, 'C', 'CLOSE'
    if last >= n then leave
    lines~append('@@SLAM' (last + 1) 'EXIT')
    start = last + 2
  end
  return lines

writeLines: procedure
  use arg f, lines
  call SysFileDelete f
  do l over lines; call lineout f, l; end
  call stream f, 'C', 'CLOSE'
  return

mkdirs: procedure
  use arg d
  address system 'mkdir -p "' || d || '"'
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamTestWriter.cls'
::requires 'SlamNetRexx.cls'
::requires 'SlamJava.cls'
