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
    /* a noun stem and its declension class (the standard tables):
         nm   masculine, hard consonant: пілон (g= genitive ending а or у)
         nf   feminine -а: зона (к г х become ц з с before і: ділянці)
         nfi  feminine -ія: позиція
         nn   neuter -я: завдання
         nne  neuter -е: поле
       gpl= gives a genitive plural the tables cannot (ділянок, завдань).
       Irregular nouns (міст, мосту) stay listed form by form */
    if wordpos(pos, 'nm nf nfi nn nne') > 0 then do
      call nounForms o, label, pos, cid, feats, ids
      iterate
    end
    if pos == 'adjhard' | pos == 'adjsoft' then do
      /* the nominative of each gender is tagged (case=nom;gen=m/f/n), so
         the realiser can say "північний пілон", "червона ділянка" */
      if pos == 'adjhard' then do
        sgE = 'ий:m ого ому им ім а:f ої ій у ою е:n'
        plE = 'і:p их ими'
      end
      else do
        sgE = 'ій:m ього ьому ім я:f ьої ю ьою є:n'
        plE = 'і:p іх іми'
      end
      do ending over sgE~subWords
        parse var ending endg ':' eg
        ef = 'num=sg;'
        if eg \== '' then ef = 'num=sg;case=nom;gen='eg';'
        o~lineout(refs(label || endg'|adj|'cid'|'ef || feats, ids))
      end
      do ending over plE~subWords
        parse var ending endg ':' eg
        ef = 'num=pl;'
        if eg \== '' then ef = 'num=pl;case=nom;'
        o~lineout(refs(label || endg'|adj|'cid'|'ef || feats, ids))
      end
      iterate
    end
    o~lineout(refs(label'|'pos'|'cid'|'feats, ids))
  end
  s~close
  o~close
  return

nounForms: procedure
  use arg o, st, cls, cid, feats, ids
  g = ''
  gpl = ''
  rest = ''
  do f over feats~makeArray(';')
    parse var f k '=' v
    select
      when k == 'g' then g = v
      when k == 'gpl' then gpl = v
      otherwise rest = rest';'f
    end
  end
  rest = rest~strip('L', ';')
  /* (a Cyrillic letter is two bytes in UTF-8) */
  last = st~right(2)
  velar = wordpos(last, 'к г х') > 0
  /* к г х before і */
  soft = st
  if last == 'к' then soft = st~left(st~length - 2)'ц'
  if last == 'г' then soft = st~left(st~length - 2)'з'
  if last == 'х' then soft = st~left(st~length - 2)'с'
  f = .array~new
  select
    when cls == 'nm' then do
      if g == '' then g = 'а'
      loc = st'і'
      if velar then loc = st'у'
      f~append(st 'sg nom'); f~append(st 'sg acc'); f~append(st || g 'sg gen')
      f~append(st'у sg dat'); f~append(st'ові sg dat'); f~append(st'ом sg ins'); f~append(loc 'sg loc')
      f~append(st'и pl nom'); f~append(st'и pl acc'); f~append(st'ів pl gen')
      f~append(st'ам pl dat'); f~append(st'ами pl ins'); f~append(st'ах pl loc')
      gn = 'm'
    end
    when cls == 'nf' then do
      if gpl == '' then gpl = st
      f~append(st'а sg nom'); f~append(st'и sg gen'); f~append(soft'і sg dat'); f~append(st'у sg acc')
      f~append(st'ою sg ins'); f~append(soft'і sg loc')
      f~append(st'и pl nom'); f~append(st'и pl acc'); f~append(gpl 'pl gen')
      f~append(st'ам pl dat'); f~append(st'ами pl ins'); f~append(st'ах pl loc')
      gn = 'f'
    end
    when cls == 'nfi' then do
      f~append(st'ія sg nom'); f~append(st'ії sg gen'); f~append(st'ії sg dat'); f~append(st'ію sg acc')
      f~append(st'ією sg ins'); f~append(st'ії sg loc')
      f~append(st'ії pl nom'); f~append(st'ії pl acc'); f~append(st'ій pl gen')
      f~append(st'іям pl dat'); f~append(st'іями pl ins'); f~append(st'іях pl loc')
      gn = 'f'
    end
    when cls == 'nn' then do
      f~append(st'я sg nom'); f~append(st'я sg acc'); f~append(st'я sg gen'); f~append(st'ю sg dat')
      f~append(st'ям sg ins'); f~append(st'і sg loc')
      f~append(st'я pl nom'); f~append(st'я pl acc'); if gpl \== '' then f~append(gpl 'pl gen')
      f~append(st'ям pl dat'); f~append(st'ями pl ins'); f~append(st'ях pl loc')
      gn = 'n'
    end
    when cls == 'nne' then do
      f~append(st'е sg nom'); f~append(st'е sg acc'); f~append(st'я sg gen'); f~append(st'ю sg dat')
      f~append(st'ем sg ins'); f~append(st'і sg loc')
      f~append(st'я pl nom'); f~append(st'я pl acc'); if gpl \== '' then f~append(gpl 'pl gen')
      f~append(st'ям pl dat'); f~append(st'ями pl ins'); f~append(st'ях pl loc')
      gn = 'n'
    end
  end
  do x over f
    parse var x form num cas
    ff = 'num='num';case='cas';gen='gn
    if rest \== '' then ff = ff';'rest
    o~lineout(refs(form'|noun|'cid'|'ff, ids))
  end
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
