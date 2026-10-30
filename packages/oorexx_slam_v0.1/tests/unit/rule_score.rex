/* Leg Drop, second step: score each rule (each source of cases) from the kill matrix.
 * Architecture: Tom Dyer (Leg Drop: proposed by the rx2cpp lane, Claude (Opus 5.5)). Code: Claude (Opus 5.5), 2026-10-30.
 * Args: groups directory | kill matrix (from kill_matrix.sh) | output file
 * A case's rule is the last word of its test method's name (test_007_edge: EDGE), in the order the group runs them.
 * For each rule:
 *   CASES   cases written by the rule
 *   CATCH   mutants some case of the rule catches
 *   ONLY    mutants only this rule catches (take the rule away and these survive)
 *   IDLE    cases that catch no mutant at all
 * Also: MUTANTS, KILLED, SURVIVED, TIMEOUT, NOCOMPILE over the suite.
 */
parse arg groups '|' matrix '|' out
kindOf = .directory~new          /* 'UNIT n' -> rule */
cases = .directory~new
call SysFileTree groups || '/SLAM_*.testGroup', 'g.', 'FO'
do i = 1 to g.0
  unit = filespec('N', g.i)
  unit = unit~substr(6, unit~length - 15)          /* SLAM_<unit>.testGroup */
  n = 0
  do while lines(g.i) > 0
    ln = linein(g.i)
    if ln~left(14) \== '::method test_' then iterate
    n += 1
    parse var ln '::method test_' . '_' rule .
    rule = rule~upper
    kindOf[unit n] = rule
    cases[rule] = (cases[rule]~isNil)~?(0, cases[rule]) + 1
  end
  call stream g.i, 'C', 'CLOSE'
end
catch = .directory~new; only = .directory~new; used = .directory~new; tally = .directory~new
do while lines(matrix) > 0
  parse value linein(matrix) with . '09'x mutant '09'x . '09'x status '09'x killers '09'x .
  tally[status] = (tally[status]~isNil)~?(0, tally[status]) + 1
  tally['MUTANTS'] = (tally['MUTANTS']~isNil)~?(0, tally['MUTANTS']) + 1
  unit = mutant~left(mutant~lastPos('_') - 1)
  rules = .set~new
  do k over killers~makeArray(' ')
    if k == '' then iterate
    used[unit k] = .true
    r = kindOf[unit k]
    if r~isNil then r = '?'
    rules~put(r)
  end
  do r over rules
    catch[r] = (catch[r]~isNil)~?(0, catch[r]) + 1
  end
  if rules~items == 1 then do r over rules
    only[r] = (only[r]~isNil)~?(0, only[r]) + 1
  end
end
call stream matrix, 'C', 'CLOSE'
idle = .directory~new
do key over kindOf~allIndexes
  if used~hasIndex(key) then iterate
  r = kindOf[key]
  idle[r] = (idle[r]~isNil)~?(0, idle[r]) + 1
end
call SysFileDelete out
do w over .array~of('MUTANTS', 'KILLED', 'SURVIVED', 'TIMEOUT', 'NOCOMPILE')
  call lineout out, w (tally[w]~isNil)~?(0, tally[w])
end
names = cases~allIndexes~sortWith(.CaselessComparator~new)
do r over names
  call lineout out, 'RULE' r~left(9) 'CASES' cases[r]~right(5) 'CATCH' ((catch[r]~isNil)~?(0, catch[r]))~right(5) ,
    'ONLY' ((only[r]~isNil)~?(0, only[r]))~right(5) 'IDLE' ((idle[r]~isNil)~?(0, idle[r]))~right(5)
end
call stream out, 'C', 'CLOSE'
exit 0
