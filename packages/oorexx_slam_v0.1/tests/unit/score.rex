/* Mutation score of SLAM's tests against random tests of the same size.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: verdicts file (unit, mutant, SLAM|RAND, verdict, change; tab-separated) | summary file to write
 * A mutant counts once per suite: KILLED or TIMEOUT is killed, SURVIVED is not; STILLBORN is not counted.
 * Summary lines: MUTANTS n | KILLED suite n | TIMEOUT suite n | ONLY suite n (killed by this suite and
 * not the other) | UNITS n | UNIT_BETTER suite n (units where this suite kills more)
 */
parse arg verdicts '|' summary
v = .directory~new                  /* mutant -> directory suite -> verdict */
unitOf = .directory~new
do while lines(verdicts) > 0
  parse value linein(verdicts) with unit '09'x m '09'x suite '09'x verdict '09'x .
  if m == '' then iterate
  verdict = verdict~word(1)
  if verdict == 'STILLBORN' then iterate
  if \v~hasIndex(m) then v[m] = .directory~new
  v[m][suite] = verdict
  unitOf[m] = unit
end
call stream verdicts, 'C', 'CLOSE'
n = 0
killed = .directory~new; killed['SLAM'] = 0; killed['RAND'] = 0
timeout = .directory~new; timeout['SLAM'] = 0; timeout['RAND'] = 0
only = .directory~new; only['SLAM'] = 0; only['RAND'] = 0
perUnit = .directory~new
do m over v~allIndexes
  d = v[m]
  if \d~hasIndex('SLAM') | \d~hasIndex('RAND') then iterate
  n += 1
  u = unitOf[m]
  if \perUnit~hasIndex(u) then perUnit[u] = .array~of(0, 0, 0)
  perUnit[u][3] += 1
  ks = (wordpos(d['SLAM'], 'KILLED TIMEOUT') > 0)
  kr = (wordpos(d['RAND'], 'KILLED TIMEOUT') > 0)
  if ks then do; killed['SLAM'] += 1; perUnit[u][1] += 1; end
  if kr then do; killed['RAND'] += 1; perUnit[u][2] += 1; end
  if d['SLAM'] == 'TIMEOUT' then timeout['SLAM'] += 1
  if d['RAND'] == 'TIMEOUT' then timeout['RAND'] += 1
  if ks then if \kr then only['SLAM'] += 1
  if kr then if \ks then only['RAND'] += 1
end
better = .directory~new; better['SLAM'] = 0; better['RAND'] = 0; better['SAME'] = 0
do u over perUnit~allIndexes
  p = perUnit[u]
  select
    when p[1] > p[2] then better['SLAM'] += 1
    when p[2] > p[1] then better['RAND'] += 1
    otherwise better['SAME'] += 1
  end
end
call SysFileDelete summary
call lineout summary, 'MUTANTS' n
do s over .array~of('SLAM', 'RAND')
  call lineout summary, 'KILLED' s killed[s]
  call lineout summary, 'TIMEOUT' s timeout[s]
  call lineout summary, 'ONLY' s only[s]
  call lineout summary, 'UNIT_BETTER' s better[s]
end
call lineout summary, 'UNIT_BETTER SAME' better['SAME']
call lineout summary, 'UNITS' perUnit~items
call stream summary, 'C', 'CLOSE'
if n > 0 then say 'mutants' n ' SLAM kills' killed['SLAM'] '(' || format(100 * killed['SLAM'] / n, , 1) || '%)  random kills' killed['RAND'] '(' || format(100 * killed['RAND'] / n, , 1) || '%)  only SLAM' only['SLAM'] ' only random' only['RAND'] ' units where SLAM kills more' better['SLAM'] 'random more' better['RAND'] 'same' better['SAME']
exit 0
