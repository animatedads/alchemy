/* Closure, circularity and grounding check of a circular-corpus CSV (word,category,definition).
 * Code: Claude (Opus 5.5), 2026-10-28. Corpus and architecture: Tom Dyer. */
signal on syntax name onSyntax
parse arg file
if file = '' then file = 'circular_corpus.csv'
defs = .directory~new; cats = .directory~new; order = .array~new
call linein file                                   /* header */
do while lines(file) > 0
  line = linein(file)~strip('T', '0d'x)
  if line = '' then iterate
  parse var line word ',' cat ',' rest
  if rest~left(1) == '"' then rest = rest~substr(2, rest~length - 2)~changestr('""', '"')
  word = word~lower
  defs[word] = tokens(rest); cats[word] = cat; order~append(word)
end
call stream file, 'C', 'CLOSE'
say 'entries:' order~items
/* closure */
missing = .directory~new
do w over order
  do t over defs[w]
    if \defs~hasIndex(t) then do
      if \missing~hasIndex(t) then missing[t] = .array~new
      missing[t]~append(w)
    end
  end
end
say 'words used but not defined:' missing~items
do t over missing~allIndexes~sort
  say '  ' t~left(12) 'used in:' missing[t]~makeString('L', ' ')
end
/* Tarjan SCC over word -> words-in-definition (defined words only) */
.local~idx = .directory~new; .local~low = .directory~new; .local~onst = .directory~new
.local~stk = .array~new; .local~cnt = 0; .local~comps = .array~new; .local~comp = .directory~new
do w over order
  if \.idx~hasIndex(w) then call strong w, defs
end
say 'strongly connected components:' .comps~items
big = 0; bigc = .nil
do c over .comps
  if c~items > big then do; big = c~items; bigc = c; end
end
say 'largest circle:' big 'words'
selfOnly = 0
do c over .comps
  if c~items = 1 then selfOnly += 1
end
say 'words outside any circle (defined only by other circles):' selfOnly
/* grounding level: condensation depth; 0 = depends on nothing outside its own component */
lvl = .directory~new
do c over .comps                                   /* Tarjan emits components in reverse topological order */
  m = -1
  do w over c
    do t over defs[w]
      if defs~hasIndex(t) then if .comp[t] \== .comp[w] then m = max(m, lvl[.comp[t]])
    end
  end
  lvl[.comp[c[1]]] = m + 1
end
byCat = .directory~new
do w over order
  k = cats[w]
  if \byCat~hasIndex(k) then byCat[k] = .array~new
  byCat[k]~append(lvl[.comp[w]])
end
do k over .array~of('core', 'program', 'maths', 'statistics')
  if \byCat~hasIndex(k) then iterate
  a = byCat[k]; mx = 0; tot = 0; inBig = 0
  do v over a; mx = max(mx, v); tot += v; end
  do w over order
    if cats[w] == k then if .comp[w] == .comp[bigc[1]] then inBig += 1
  end
  say '  ' k~left(11) 'words' a~items~right(3) ' in largest circle' inBig~right(3) ' max level' mx
end
say 'largest circle includes:'
s = bigc~sort; say '  ' s~makeString('L', ' ')
say 'highest-level words:'
do w over order
  if lvl[.comp[w]] >= 2 then say '  ' w~left(14) 'level' lvl[.comp[w]] '(' || cats[w] || ')'
end
exit 0

tokens: procedure
  use arg text
  clean = text~lower~translate('        ', ';:,.()"''')
  out = .array~new
  do i = 1 to clean~words; out~append(clean~word(i)); end
  return out

strong: procedure
  use arg v, defs
  .idx[v] = .cnt; .low[v] = .cnt; .local~cnt = .cnt + 1
  .stk~append(v); .onst[v] = .true
  do t over defs[v]
    if \defs~hasIndex(t) then iterate
    if \.idx~hasIndex(t) then do
      call strong t, defs
      .low[v] = min(.low[v], .low[t])
    end
    else if .onst[t] == .true then .low[v] = min(.low[v], .idx[t])
  end
  if .low[v] = .idx[v] then do
    c = .array~new
    do forever
      w = .stk[.stk~items]; .stk~delete(.stk~items); .onst[w] = .false
      c~append(w); .comp[w] = .comps~items + 1
      if w == v then leave
    end
    .comps~append(c)
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1
