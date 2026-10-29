/* find_pool.rex - the standalone ooRexx routines under a tree: the ones SLAM can lift, run alone, and
 * so write unit tests for (pure, builtin classes only, at least one argument).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Usage:  rexx find_pool.rex <root> <pool file>
 * Pool lines: <path under root> <ROUTINE NAME>   (the input of tests/unit/write_tests.rex)
 */
signal on syntax name onSyntax
parse arg root pool
if root == '' | pool == '' then do
  say 'usage: rexx find_pool.rex <root> <pool file>'
  exit 2
end
root = root~strip('T', '/')
call SysFileDelete pool
call SysFileTree root || '/*', 'f.', 'FSO'
x = .SlamContractExtractor~new
seen = .directory~new
files = 0; found = 0
do i = 1 to f.0
  p = f.i
  if p~pos('/.git/') > 0 then iterate
  ext = p~substr(p~lastPos('.') + 1)~lower
  if wordpos(ext, 'rex cls rexx orx') == 0 then iterate
  files += 1
  found += scan(p, root, x, seen, pool)
end
call stream pool, 'C', 'CLOSE'
say 'files' files ' standalone routines' found
exit 0

scan: procedure
  use arg p, root, x, seen, pool
  signal on syntax name scanFailed
  text = charin(p, 1, chars(p)); call stream p, 'C', 'CLOSE'
  n = 0
  do u over .SlamUnitSplitter~new~split(text)
    if u~kind \== 'ROUTINE' then iterate
    sig = u~signature
    if seen~hasIndex(sig) then iterate
    seen[sig] = .true
    k = x~extract(u)
    if \k~standalone then iterate
    if k~args~items == 0 then iterate
    call lineout pool, p~substr(root~length + 2) u~selector
    n += 1
  end
  return n
scanFailed:
  return 0

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamContract.cls'
