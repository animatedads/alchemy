/* Find standalone routines (pure, builtin classes only) with known kinds: each can be lifted and run alone.
 * Code: Claude (Opus 5.5), 2026-10-28. Architecture: Tom Dyer. Arg: file listing paths. */
signal on syntax name onSyntax
parse arg listFile
x = .SlamContractExtractor~new
seen = .directory~new
found = 0; files = 0; safeFiles = 0; routines = 0
do while lines(listFile) > 0
  file = linein(listFile)
  files += 1
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  r = scan(file, text, x, seen)
  if r == .nil then iterate
  safeFiles += r[1]
  routines += r[2]
  found += r[3]
end
say 'files' files ' safe files' safeFiles ' routines in them' routines ' pure with known kinds' found
exit 0
scan: procedure
  use arg file, text, x, seen
  signal on syntax name scanFailed
  units = .SlamUnitSplitter~new~split(text)
  n = 0; f = 0
  do u over units
    if u~kind \== 'ROUTINE' then iterate
    n += 1
    sig = u~signature
    if seen~hasIndex(sig) then iterate
    seen[sig] = .true
    k = x~extract(u)
    if \k~standalone then iterate
    if k~args~items == 0 then iterate
    known = .true
    do a over k~args
      if a['KINDS']~items == 0 then known = .false
    end
    g = .SlamContract~keys(k~gives)
    if wordpos(g, 'NUMBER STRING BOOLEAN ARRAY') == 0 then known = .false
    if \known then iterate
    f += 1
    say file~substr(file~pos('packages/') + 9) || ' :: ' || k~canonicalText
  end
  return .array~of(1, n, f)
scanFailed:
  return .nil
onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1
::requires 'SlamContract.cls'
