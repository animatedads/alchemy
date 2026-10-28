/* Print the contract of chosen units. Code: Claude (Opus 5.5), 2026-10-28. Architecture: Tom Dyer. */
signal on syntax name onSyntax
parse arg file '|' wanted
text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
x = .SlamContractExtractor~new
do u over .SlamUnitSplitter~new~split(text)
  id = u~owner || '~' || u~selector
  if wanted \= '' then if wordpos(id~upper, wanted~upper) == 0 then iterate
  say x~extract(u)~canonicalText
end
exit 0
onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1
::requires 'SlamContract.cls'
