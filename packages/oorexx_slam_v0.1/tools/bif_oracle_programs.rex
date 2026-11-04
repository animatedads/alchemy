/* bif_oracle_programs.rex - one small ooRexx program per BIF case SLAM chose, for an interpreter-oracle
 * test: compile each program with rx2cpp, run it, and compare its stdout bytes and exit status with
 * the interpreter's. SLAM does not need to know the right answer; it only picks the inputs (the
 * contract cases: the lane's own case, one argument too few and too many, -1 / 0 / x for counts,
 * two-character pads, ...).
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Usage:  rexx bif_oracle_programs.rex <cases file> <output directory>
 *   cases file  from tests/bif/bif_compare.rex (ID|NAME|interp|native|why|n|arg1|...|argn)
 * Writes, in the output directory:
 *   slam_bif_<ID>.rex             the program: say c2x(NAME('a1', ..., 'an'))  (c2x: stdout is plain text)
 *   expected/slam_bif_<ID>.stdout the interpreter's stdout
 *   expected/slam_bif_<ID>.status the interpreter's exit status
 *   MANIFEST.txt                  one line per program: file, BIF, why, SLAM's predictions
 */
parse arg cases out
if cases == '' | out == '' then do
  say 'usage: rexx bif_oracle_programs.rex <cases file> <output directory>'
  exit 2
end
call SysMkDir out
call SysMkDir out || '/expected'
man = out || '/MANIFEST.txt'
call SysFileDelete man
n = 0
do while lines(cases) > 0
  parse value linein(cases) with id '|' name '|' ip '|' np '|' why '|' cnt '|' rest
  if id == '' then iterate
  args = .array~new
  do k = 1 to cnt
    parse var rest a '|' rest
    args~append(a)
  end
  call = name || '('
  do k = 1 to args~items
    if k > 1 then call = call || ', '
    call = call || literal(args[k])
  end
  call = call || ')'
  f = 'slam_bif_' || right(id, 3, '0') || '.rex'
  p = out || '/' || f
  call SysFileDelete p
  call lineout p, '/* SLAM-chosen BIF case' id || ':' name '-' why
  call lineout p, '   SLAM predicted: interpreter' ip || ', native pack' np || '.'
  call lineout p, '   Oracle: the interpreter''s stdout and exit status for this same file.'
  call lineout p, '   Architecture: Tom Dyer.  Code: Claude (Opus 5.5); cases chosen by SLAM. */'
  call lineout p, 'say c2x(' || call || ')'
  call stream p, 'C', 'CLOSE'
  e = out || '/expected/' || f
  address system 'rexx "' || p || '" > "' || e~changeStr('.rex', '.stdout') || '" 2>/dev/null; echo $? > "' || e~changeStr('.rex', '.status') || '"'
  call lineout man, f '|' name '|' why '| predicted interpreter' ip 'native' np
  n += 1
end
call stream man, 'C', 'CLOSE'
say n 'programs written to' out
exit 0

literal: procedure
  use arg s
  if s~verify(xrange('20'x, '7e'x)) > 0 then return "'" || s~c2x || "'x"
  return "'" || s~changeStr("'", "''") || "'"
