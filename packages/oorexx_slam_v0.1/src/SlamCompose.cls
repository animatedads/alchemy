/* SlamCompose.cls - make a path from code units, check it can work before it runs, run it, keep the result.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * The task is ChatGPT's second letter to SLAM: find nodes that can work together, what each needs and
 * gives, make a path that was not in the code, run it on new data, check the result a second way, break
 * one part so that it should fail, know why, and keep both results.
 *
 * A unit is lifted on its own: its body becomes a .Routine (Routine~new), so nothing else in its file
 * runs and none of its file's ::REQUIRES load. Only STANDALONE contracts (pure, builtin classes only)
 * are liftable.
 *
 * Feasibility comes first: before a path runs, every link is checked against the contracts (what the
 * earlier unit gives against what the later unit needs at that argument). A score never overrides it.
 */

::requires 'SlamContract.cls'
::requires 'SlamStore.cls'

::class SlamLifted public
::attribute alias
::attribute file
::attribute name
::attribute contract
::attribute routine
::method init
  expose alias file name contract routine
  use strict arg alias, file, name, contract, routine

::class SlamComposer public
::attribute units
::method init
  expose units
  units = .directory~new
/* Lift routine NAME from FILE under ALIAS. Raises when the unit is missing or not standalone. */
::method lift
  expose units
  use strict arg file, name, alias, unitList = .nil, text = .nil
  /* a caller lifting many routines from one file can pass its text and units, read once */
  if text == .nil then do
    text = charin(file, 1, chars(file))
    call stream file, 'C', 'CLOSE'
  end
  if unitList == .nil then unitList = .SlamUnitSplitter~new~split(text)
  unit = .nil
  do u over unitList
    if u~kind == 'ROUTINE' then if u~selector == name~upper then unit = u
  end
  if unit == .nil then raise syntax 93.900 array('no routine' name 'in' file)
  k = .SlamContractExtractor~new~extract(unit)
  if \k~standalone then raise syntax 93.900 array('routine' name 'is not standalone:' k~canonicalText)
  lines = text~makeArray('0a'x)
  lastLine = unit~line
  do t over unit~tokens
    if t~endLine > lastLine then lastLine = t~endLine
    if t~line > lastLine then lastLine = t~line
  end
  body = .array~new
  do i = unit~line + 1 to min(lastLine, lines~items)
    /* the next directive (a ::requires after the last routine) is not part of the body */
    if lines[i]~strip~left(2) == '::' then leave
    body~append(lines[i]~strip('T', '0d'x))
  end
  /* The directive line itself may carry the body after a ';' (::routine x; return 1). */
  first = lines[unit~line]~strip('T', '0d'x)
  semi = first~pos(';')
  if semi > 0 then body~insert(first~substr(semi + 1), .nil)
  /* the file's ::OPTIONS (digits, form, fuzz) come too, last, so the routine runs with its package's
     settings (found by the rx2cpp lane: a file's ::options digits 25 was lost) */
  do ln over lines
    if ln~strip~left(9)~upper == '::OPTIONS' then body~append(ln~strip('T', '0d'x))
  end
  r = .Routine~new(alias, body)
  lifted = .SlamLifted~new(alias, file, name, k, r)
  units[alias] = lifted
  return lifted
/* Can unit TO take what unit FROM gives, at argument position POS? */
::method canFollow
  expose units
  use strict arg fromAlias, toAlias, pos
  out = .directory~new
  f = units[fromAlias]~contract
  t = units[toAlias]~contract
  need = .nil
  do a over t~args
    if a['POS'] = pos then need = a
  end
  if need == .nil then do
    out['OK'] = .false
    out['REASON'] = toAlias 'has no argument' pos
    return out
  end
  do g over f~gives~allIndexes
    if \.SlamContract~satisfies(g, need['KINDS']) then do
      out['OK'] = .false
      out['REASON'] = toAlias 'argument' pos '(' || need['NAME']~lower || ') needs' .SlamContract~keys(need['KINDS']) || ',' fromAlias 'gives' g
      return out
    end
  end
  out['OK'] = .true
  out['REASON'] = fromAlias 'gives' .SlamContract~keys(f~gives) || ',' toAlias 'argument' pos 'needs' .SlamContract~keys(need['KINDS'])
  return out
/* A contract gate for use outside exploratory tests. The ordinary run method remains
   intentionally exploratory: it records a predicted failure AND tries the path.
   The admitted route never executes a path that its current contracts reject.
   It does not claim that all missing semantic requirements have been learned. */
::method admit
  expose units
  use strict arg steps
  gate = .directory~new
  gate['FEASIBLE'] = .false
  gate['FAILED_AT'] = ''
  gate['PREDICTION'] = 'will fail: empty path'
  if steps~items == 0 then return gate
  do i = 1 to steps~items
    alias = steps[i][1]
    if \units~hasIndex(alias) then do
      gate['FAILED_AT'] = alias
      gate['PREDICTION'] = 'will fail: no lifted unit' alias
      return gate
    end
    args = steps[i][2]
    do p = 1 to args~items
      if args[p] == 'PREV' then do
        if i == 1 then do
          gate['FAILED_AT'] = alias
          gate['PREDICTION'] = 'will fail: first unit has no prior result'
          return gate
        end
        c = self~canFollow(steps[i - 1][1], alias, p)
        if \c['OK'] then do
          gate['FAILED_AT'] = alias
          gate['PREDICTION'] = 'will fail: ' || c['REASON']
          return gate
        end
      end
    end
  end
  gate['FEASIBLE'] = .true
  gate['PREDICTION'] = 'can work'
  return gate
/* Production-style admission: a predicted bad path is BLOCKED before any routine executes.
   Exploration stays available as run(steps), which still runs predicted failures on purpose. */
::method runAdmitted
  use strict arg steps
  gate = self~admit(steps)
  if \gate['FEASIBLE'] then do
    gate['STATUS'] = 'BLOCKED'
    gate['TRACE'] = .array~new
    gate['ERROR'] = gate['PREDICTION']
    return gate
  end
  return self~run(steps)
/* Run a path. steps: Array of .array(alias, argArray); an argument 'PREV' is the previous result.
   Returns a Directory: FEASIBLE, PREDICTION, STATUS (OK|FAILED), RESULT, FAILED_AT, ERROR, TRACE. */
::method run
  expose units
  use strict arg steps
  out = .directory~new
  out['TRACE'] = .array~new
  out['FEASIBLE'] = .true
  out['PREDICTION'] = 'can work'
  do i = 2 to steps~items
    args = steps[i][2]
    do p = 1 to args~items
      if args[p] == 'PREV' then do
        c = self~canFollow(steps[i - 1][1], steps[i][1], p)
        if \c['OK'] then do
          out['FEASIBLE'] = .false
          out['PREDICTION'] = 'will fail: ' || c['REASON']
        end
      end
    end
  end
  prev = .nil
  do i = 1 to steps~items
    alias = steps[i][1]
    args = steps[i][2]~copy
    do p = 1 to args~items
      if args[p] == 'PREV' then args[p] = prev
    end
    r = self~callOne(units[alias]~routine, args)
    if r['STATUS'] \== 'OK' then do
      out['STATUS'] = 'FAILED'
      out['FAILED_AT'] = alias
      out['ERROR'] = r['ERROR']
      return out
    end
    prev = r['VALUE']
    out['TRACE']~append(alias '->' prev~string~left(40))
  end
  out['STATUS'] = 'OK'
  out['RESULT'] = prev
  return out
::method callOne
  use strict arg routine, args
  out = .directory~new
  signal on syntax name callFailed
  v = routine~callWith(args)
  out['STATUS'] = 'OK'
  out['VALUE'] = v
  return out
callFailed:
  c = condition('O')
  out['STATUS'] = 'FAILED'
  out['ERROR'] = c['CODE'] c['ERRORTEXT'] || ':' c['MESSAGE']
  return out
