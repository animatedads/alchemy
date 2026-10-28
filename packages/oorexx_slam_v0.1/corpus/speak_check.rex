/* Which words of a sentence are outside the corpus? Code: Claude (Opus 5.5), 2026-10-28. Corpus: Tom Dyer. */
parse arg file '|' sentence
known = .directory~new
call linein file
do while lines(file) > 0
  parse value linein(file) with word ',' .
  if word \= '' then known[word~lower] = .true
end
call stream file, 'C', 'CLOSE'
clean = sentence~lower~translate('         ', ';:,.()"''?!')~changestr("'", ' ')
unknown = .array~new; n = clean~words
do i = 1 to n
  w = clean~word(i)
  if \known~hasIndex(w) then unknown~append(w)
end
say n 'words,' unknown~items 'outside the corpus'
if unknown~items > 0 then say '  ' unknown~makeString('L', ' ')
