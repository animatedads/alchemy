/* Runtime libraries: LLVM's libc (C++ written as C) and libc++ (the C++ standard library), read whole,
 * predicted, and folded.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: libc store | libc++ store | next_node.rex summary (experiments LIBC, LIBCXX, LIBC_TO_LIBCXX, LIBCXX_TO_LIBC)
 */
signal on syntax name onSyntax
parse arg libcDb '|' cxxDb '|' summary
checks = 0
call check libcDb \= '' & cxxDb \= '' & summary \= '', 'arguments'

say '== 1. libc: functions made by a macro, and the same body under two names'
st = .SlamStore~new(libcDb)
units = st~scalar('SELECT count(*) AS n FROM unit')
aliases = st~scalar('SELECT count(*) AS n FROM alias')
fns = st~scalar("SELECT count(*) AS n FROM unit WHERE owner = 'LLVM_LIBC_FUNCTION'")
say '      units' units ' aliases' aliases ' LLVM_LIBC_FUNCTION units' fns
call check units = 5553 & aliases = 200, 'libc: 5553 units kept; 200 more are the text of a kept unit under another name (aliases)'
call check fns > 1000, 'LLVM_LIBC_FUNCTION(type, name, (params)) { } is unit name of owner LLVM_LIBC_FUNCTION (' || fns 'of them)'
kept = st~scalar("SELECT u.selector AS s FROM alias a JOIN unit u ON u.id = a.unit_id WHERE a.selector = 'putc' AND a.owner = 'LLVM_LIBC_FUNCTION'")
call check kept == 'fputc', 'putc is an alias of fputc: the same body, so it is skipped at ingest and kept by name (got' kept || ')'
st~close

r = .directory~new
do while lines(summary) > 0
  parse value linein(summary) with name level . total . model . base . seen .
  r[name level] = .array~of(total, model, base, seen)
end
call stream summary, 'C', 'CLOSE'

say '== 2. next-segment prediction: each library on its own held-out fifth, and each on the other'
do e over .array~of('LIBC', 'LIBCXX', 'LIBC_TO_LIBCXX', 'LIBCXX_TO_LIBC')
  call show e, 'KIND'; call show e, 'KIND+'; call show e, 'SKELETON+'
end
call check r['LIBC KIND+'][2] > r['LIBC KIND'][2] & r['LIBC KIND'][2] > r['LIBC KIND'][3], 'libc: edges beat the baseline, and the enclosing segment helps'
call check r['LIBCXX KIND+'][2] > r['LIBCXX KIND'][2] & r['LIBCXX KIND'][2] > r['LIBCXX KIND'][3], 'libc++: edges beat the baseline, and the enclosing segment helps'
call check r['LIBC_TO_LIBCXX KIND+'][2] > r['LIBC_TO_LIBCXX KIND+'][3] & r['LIBCXX_TO_LIBC KIND+'][2] > r['LIBCXX_TO_LIBC KIND+'][3], 'with context, each library predicts the other above the baseline'

say '== 3. identical code folding'
f = .SlamFold~new(.SlamStore~new(libcDb)); f~load('%')
p = f~run(5)
call check p~makeString('L', ' ') == '12 0', 'libc, 5 segments or more: 12 folds, then none'
pairs = foldPairs(f)
say '      ' pairs~left(400)
call check pairs~pos('Float80~operator T->Float128~operator T') > 0, 'Float80 and Float128 convert to an integer type with the same code (FE_INVALID on inf or NaN, then saturate)'
call check pairs~pos('LLVM_LIBC_FUNCTION~writev->LLVM_LIBC_FUNCTION~readv') > 0, 'readv and writev are the same system-call wrapper'
f = .SlamFold~new(.SlamStore~new(libcDb)); f~load('%')
call check f~run(1)~makeString('L', ' ') == '276 1 0', 'libc, every size: 276 folds, 1 in the second pass, then none'

f = .SlamFold~new(.SlamStore~new(cxxDb)); f~load('%')
p = f~run(5)
call check p~makeString('L', ' ') == '24 0', 'libc++, 5 segments or more: 24 folds, then none'
pairs = foldPairs(f)
n = 0
do w over pairs~makeArray(' ')
  if w~pos('distribution.h') > 0 then n += 1
end
call check n = 10, 'operator>> of the random distributions folds by parameter count: 6 into weibull, 2 into chi_squared, binomial into negative_binomial, geometric into poisson (' || n 'folded)'
call check pairs~pos('__to_gcc_failure_order->') > 0, '__to_gcc_failure_order folds into __to_gcc_order'
f = .SlamFold~new(.SlamStore~new(cxxDb)); f~load('%')
call check f~run(1)~makeString('L', ' ') == '695 10 0', 'libc++, every size: 695 folds, 10 in the second pass, then none'

say '== 4. congruent is not identical: libc''s one-line math wrappers'
f = .SlamFold~new(.SlamStore~new(libcDb)); f~load('%')
b = .directory~new
do id over f~units~allIndexes
  k = f~units[id]['FAMTEXT']
  if \b~hasIndex(k) then b[k] = .array~new
  b[k]~append(id)
end
biggest = 0
do k over b~allIndexes
  ids = b[k]
  has = 0
  do id over ids
    if f~units[id]['SEL'] == 'sqrtf' then has = 1
  end
  if has then biggest = max(biggest, ids~items)
end
f~run(1)
folded = 0
do k over b~allIndexes
  ids = b[k]
  has = 0
  do id over ids
    if f~units[id]['SEL'] == 'sqrtf' then has = 1
  end
  if has then if ids~items = biggest then do id over ids
    if f~foldedInto~hasIndex(id) then folded += 1
  end
end
say '      sqrtf''s congruent bucket:' biggest 'units,' folded 'folded'
call check biggest >= 20 & folded <= 3, 'sqrtf, sinf, logf, ... are congruent (one call on a float) but call different functions, so they are not identical and do not fold, as BOLT would not fold them'

say 'LIBC TEST: PASS (' || checks || ' checks)'
exit 0

foldPairs: procedure
  use arg f
  out = ''
  do child over f~foldedInto~allIndexes
    c = f~units[child]; q = f~units[f~foldedInto[child]]
    out = out c['OWNER'] || '~' || c['SEL'] || '->' || q['OWNER'] || '~' || q['SEL'] || '@' || c['PATH']~substr(c['PATH']~lastPos('/') + 1)
  end
  return out~strip

show: procedure expose r
  use arg name, level
  x = r[name level]
  say '     ' left(name level, 28) 'model' format(100 * x[2] / x[1], , 1) || '%  base' format(100 * x[3] / x[1], , 1) || '%  of' x[1]
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

::requires 'SlamFold.cls'
