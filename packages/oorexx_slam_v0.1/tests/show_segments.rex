/* Print the segment tree of chosen units. Code: Claude (Opus 5.5), 2026-10-28. Architecture: Tom Dyer. */
signal on syntax name onSyntax
parse arg file '|' wanted
text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
units = .SlamUnitSplitter~new~split(text)
seg = .SlamSegmenter~new
say units~items 'units in' file
do u over units
  id = u~owner || '~' || u~selector
  if wanted \= '' then if wordpos(id~upper, wanted~upper) == 0 then iterate
  say '==' u~kind id '(line' u~line || ')'
  call show seg~segmentUnit(u), 1
end
exit 0
show: procedure
  use arg segs, depth
  do s over segs
    rep = ''; if s~repeat > 1 then rep = ' x' || s~repeat
    say copies('  ', depth) || s~fine || rep
    say copies('  ', depth) || '   binding:' s~binding
    do sq over s~sequences
      say copies('  ', depth + 1) || '[' || sq[1] || ']'
      call show sq[2], depth + 2
    end
  end
  return
onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeString
  exit 1
::requires 'SlamSegmenter.cls'
