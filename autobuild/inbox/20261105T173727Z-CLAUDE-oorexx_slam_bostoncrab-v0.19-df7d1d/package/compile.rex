/* compile.rex - turn the authoring files into id-only files.            */
/* concepts.src -> concepts.words  (id | gloss | parent-id | defs-by-id)  */
/* lexicon.src  -> lexicon.words   (every ^gloss replaced by its id)      */
/* rules.src    -> rules.words     (every ^gloss replaced by its id)      */
/* Usage: rexx compile.rex [dir]                                          */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                       */
parse arg dir
dir = dir~strip
if dir = '' then dir = '.'

ids   = .StringTable~new
lines = .Array~new
n = 0
do cf over .array~of(dir'/concepts.src', dir'/wordnet/concepts_wn.src')
  if \SysFileExists(cf) then iterate
  s = .Stream~new(cf)~~open('read')
  do while s~lines > 0
    ln = s~linein
    if ln~strip = '' then iterate
    if ln~left(1) = '#' then iterate
    parse var ln gloss '|' parent '|' defs
    n = n + 1
    id = 'C.'||n~right(4, '0')
    ids[gloss~strip] = id
    lines~append(gloss~strip||'|'||parent~strip||'|'||defs~strip)
  end
  s~close
end

out = .Stream~new(dir'/concepts.words')~~open('write replace')
i = 0
do ln over lines
  i = i + 1
  parse var ln gloss '|' parent '|' defs
  pid = ''
  if parent \= '' then do
    if \ids~hasIndex(parent) then call fail 'unknown parent' parent 'for' gloss
    pid = ids[parent]
  end
  out~lineout('C.'||i~right(4, '0')||'|'||gloss||'|'||pid||'|'||refs(defs, ids))
end
out~close

call convert dir'/lexicon.src', dir'/lexicon.words', ids
if SysFileExists(dir'/wordnet/lexicon_wn.src') then call convert dir'/wordnet/lexicon_wn.src', dir'/lexicon.words', ids, 'append'
/* lexicon_uk.src: Ukrainian words. "пілон|noun|=pylon|num=sg" means the
   concept the English noun "pylon" has, so the two languages share one
   concept and nothing about it is Ukrainian or English */
if SysFileExists(dir'/lexicon_uk.src') then call convertUk dir'/lexicon_uk.src', dir'/lexicon.words', ids, enTable(dir)
call convert dir'/rules.src',   dir'/rules.words',   ids
say 'compiled' n 'concepts'
exit 0

convert: procedure
  use arg src, dst, ids, mode
  s = .Stream~new(src)~~open('read')
  if mode == 'append' then o = .Stream~new(dst)~~open('write append')
  else o = .Stream~new(dst)~~open('write replace')
  do while s~lines > 0
    ln = s~linein
    if ln~strip = '' then iterate
    if ln~left(1) = '#' then iterate
    o~lineout(refs(ln, ids))
  end
  s~close
  o~close
  return

/* English label|pos -> its first ^gloss, from the English lexicons */
enTable: procedure
  use arg dir
  t = .StringTable~new
  do f over .array~of(dir'/lexicon.src', dir'/wordnet/lexicon_wn.src')
    if \SysFileExists(f) then iterate
    s = .Stream~new(f)~~open('read')
    do while s~lines > 0
      ln = s~linein
      if ln~strip = '' | ln~left(1) = '#' then iterate
      parse var ln label '|' pos '|' cid '|' .
      if cid~left(1) \== '^' then iterate
      if \t~hasIndex(label'|'pos) then t[label'|'pos] = cid
      if \t~hasIndex(label'|*') then t[label'|*'] = cid
    end
    s~close
  end
  return t

convertUk: procedure
  use arg src, dst, ids, en
  s = .Stream~new(src)~~open('read')
  o = .Stream~new(dst)~~open('write append')
  do while s~lines > 0
    ln = s~linein
    if ln~strip = '' then iterate
    if ln~left(1) = '#' then iterate
    parse var ln label '|' pos '|' cid '|' feats
    if cid~left(1) == '=' then do
      /* "=orbit:verb": the concept of the English verb (обліт, a fly-around,
         is the act of orbiting, not an orbit's path) */
      parse value cid~substr(2) with w ':' wantPos
      enPos = pos
      /* a stem is an adjective: take the English adjective, never the
         noun ("hostile" the adjective, not a hostile) */
      if pos == 'adjhard' | pos == 'adjsoft' then enPos = 'adj'
      if wordpos(enPos, 'noun adj verb') = 0 then enPos = '*'
      if wantPos \== '' then enPos = wantPos
      if en~hasIndex(w'|'enPos) then cid = en[w'|'enPos]
      else if en~hasIndex(w'|*') then cid = en[w'|*']
      else call fail 'lexicon_uk: no English word "'w'" to share a concept with, in:' ln
    end
    if feats == '' then feats = 'lang=uk'
    else feats = feats';lang=uk'
    /* an adjective stem and its declension: "західн|adjhard|=west" gives
       західний, західного, ... західними. The endings are the standard
       tables (hard stem -ий, soft stem -ій); nothing else is generated */
    if pos == 'adjhard' | pos == 'adjsoft' then do
      if pos == 'adjhard' then do
        sgE = 'ий ого ому им ім а ої ій у ою е'
        plE = 'і их ими'
      end
      else do
        sgE = 'ій ього ьому ім я ьої ю ьою є'
        plE = 'і іх іми'
      end
      do ending over sgE~subWords
        o~lineout(refs(label || ending'|adj|'cid'|num=sg;'feats, ids))
      end
      do ending over plE~subWords
        o~lineout(refs(label || ending'|adj|'cid'|num=pl;'feats, ids))
      end
      iterate
    end
    o~lineout(refs(label'|'pos'|'cid'|'feats, ids))
  end
  s~close
  o~close
  return

/* replace every ^gloss in a line with its concept id */
refs: procedure
  use arg text, ids
  outText = ''
  p = 1
  do forever
    q = text~pos('^', p)
    if q = 0 then leave
    outText = outText||text~substr(p, q - p)
    e = q + 1
    do while e <= text~length
      ch = text~substr(e, 1)
      /* a gloss may carry a WordNet id after a tilde: climb~01925957-v */
      if verify(ch, 'abcdefghijklmnopqrstuvwxyz0123456789-~') \= 0 then leave
      e = e + 1
    end
    g = text~substr(q + 1, e - q - 1)
    if \ids~hasIndex(g) then call fail 'unknown concept ^'g 'in:' text
    outText = outText||ids[g]
    p = e
  end
  return outText||text~substr(p)

fail:
  parse arg msg
  say 'compile error:' msg
  exit 1
