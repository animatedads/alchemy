/* Which words of a sentence are outside SLAM's words? Code: Claude (Opus 5.5), 2026-10-28. Corpus: Tom Dyer.
 * Usage:  rexx speak_check.rex <list>|<sentence>
 *   list: one or more word files joined by +, read in order:
 *     a .csv (word,category,definition): the base corpus, the communications corpus
 *     a .md: the "words i add" section of SLAM's README (lines "word: definition")
 *   e.g. corpus/circular_corpus_v2.csv+corpus/communications_corpus.csv+README_SLAM.md
 * A number (210, 4.5) counts as known: SLAM reads numbers as values.
 */
parse arg files '|' sentence
known = .directory~new
do file over files~makeArray('+')
  if file~right(3)~lower == '.md' then call readmeWords file, known
  else do
    call linein file
    do while lines(file) > 0
      parse value linein(file) with word ',' .
      if word \= '' then known[word~lower] = .true
    end
    call stream file, 'C', 'CLOSE'
  end
end
clean = sentence~lower~translate('         ', ';:,.()"''?!')~changestr("'", ' ')
unknown = .array~new; n = clean~words
do i = 1 to n
  w = clean~word(i)
  if datatype(w, 'N') then iterate
  if \known~hasIndex(w) then unknown~append(w)
end
say n 'words,' unknown~items 'outside the corpus'
if unknown~items > 0 then say '  ' unknown~makeString('L', ' ')
exit 0

readmeWords: procedure
  use arg file, known
  inside = .false
  do while lines(file) > 0
    ln = linein(file)~strip
    if ln~left(3) == '## ' then inside = (ln~lower == '## words i add')
    if \inside then iterate
    parse var ln w ':' rest
    if rest \== '' then if w~words == 1 then known[w~lower] = .true
  end
  call stream file, 'C', 'CLOSE'
  return
