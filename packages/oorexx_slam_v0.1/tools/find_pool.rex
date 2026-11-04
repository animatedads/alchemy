/* find_pool.rex - the standalone ooRexx routines and methods under a tree: the ones SLAM can lift, run
 * alone, and so write unit tests for (pure, builtin classes only, at least one argument). A method
 * counts when it uses nothing of its object (no SELF, SUPER or EXPOSE): the rx2cpp lane's ask, so a
 * compiler written as classes gets tests of its own code.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Usage:  rexx find_pool.rex <root> <pool file> [ROUTINES|METHODS|BOTH]   (default BOTH)
 * Pool lines: <path under root> <NAME> [<CLASS>]   (the input of tests/unit/write_tests.rex)
 */
signal on syntax name onSyntax
parse arg root pool which .
if which == '' then which = 'BOTH'
which = which~upper
if root == '' | pool == '' then do
  say 'usage: rexx find_pool.rex <root> <pool file>'
  exit 2
end
root = root~strip('T', '/')
call SysFileDelete pool
call SysFileTree root || '/*', 'f.', 'FSO'
x = .SlamContractExtractor~new
seen = .directory~new
files = 0; found = 0; methods = 0
do i = 1 to f.0
  p = f.i
  if p~pos('/.git/') > 0 then iterate
  ext = p~substr(p~lastPos('.') + 1)~lower
  if wordpos(ext, 'rex cls rexx orx') == 0 then iterate
  files += 1
  r = scan(p, root, x, seen, pool, which)
  found += r[1]; methods += r[2]
end
call stream pool, 'C', 'CLOSE'
say 'files' files ' standalone routines' found ' methods that use nothing of their object' methods
exit 0

scan: procedure
  use arg p, root, x, seen, pool, which
  signal on syntax name scanFailed
  text = charin(p, 1, chars(p)); call stream p, 'C', 'CLOSE'
  lines = text~makeArray('0a'x)
  n = 0; m = 0
  do u over .SlamUnitSplitter~new~split(text)
    if u~kind == 'ROUTINE' then do
      if which == 'METHODS' then iterate
    end
    else if u~kind == 'METHOD' then do
      if which == 'ROUTINES' then iterate
      if \slamLiftableMethod(u, lines[u~line]) then iterate
    end
    else iterate
    sig = u~signature
    if seen~hasIndex(sig) then iterate
    seen[sig] = .true
    k = x~extract(u)
    if \k~standalone then iterate
    if k~args~items == 0 then iterate
    if u~kind == 'ROUTINE' then do
      call lineout pool, p~substr(root~length + 2) u~selector
      n += 1
    end
    else do
      call lineout pool, p~substr(root~length + 2) u~selector u~owner
      m += 1
    end
  end
  return .array~of(n, m)
scanFailed:
  return .array~of(0, 0)

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamContract.cls'
::requires 'SlamLift.cls'
