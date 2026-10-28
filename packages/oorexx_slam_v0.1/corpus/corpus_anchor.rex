/* Hops from each word to an executable anchor (maths + statistics words, whose definitions are procedures).
 * Code: Claude (Opus 5.5), 2026-10-28. Corpus and architecture: Tom Dyer. */
signal on syntax name onSyntax
parse arg file
defs = .directory~new; cats = .directory~new; order = .array~new
call linein file
do while lines(file) > 0
  line = linein(file)~strip('T', '0d'x)
  if line = '' then iterate
  parse var line word ',' cat ',' rest
  if rest~left(1) == '"' then rest = rest~substr(2, rest~length - 2)~changestr('""', '"')
  clean = rest~lower~translate('        ', ';:,.()"''')
  a = .array~new; do i = 1 to clean~words; a~append(clean~word(i)); end
  defs[word~lower] = a; cats[word~lower] = cat; order~append(word~lower)
end
dist = .directory~new; queue = .array~new
do w over order
  if wordpos(cats[w], 'maths statistics') > 0 then do; dist[w] = 0; queue~append(w); end
end
/* reverse BFS: w is one hop from an anchor if its definition uses a word at distance d */
do changed = 1 until \changed
  changed = .false
  do w over order
    best = dist[w]
    do t over defs[w]
      if dist~hasIndex(t) then do
        cand = dist[t] + 1
        if best == .nil then best = cand
        else if cand < best then best = cand
      end
    end
    if best \== .nil then if dist[w] \== best then do; dist[w] = best; changed = .true; end
  end
end
do d over .array~of(0, 1, 2, 3, 4, 5, 'none')
  n = 0; list = ''
  do w over order
    v = dist[w]; if v == .nil then v = 'none'
    if v == d then do; n += 1; list = list w; end
  end
  if n = 0 then iterate
  shown = ''
  if d \== 0 then if d \== 1 then shown = ' :' list
  say 'hops' d~right(4) ':' n~right(3) 'words' || shown
end
exit 0
onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1
