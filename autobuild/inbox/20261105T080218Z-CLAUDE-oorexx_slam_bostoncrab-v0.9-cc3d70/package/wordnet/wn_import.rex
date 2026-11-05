/* wn_import.rex - grow the lexicon from WordNet, only for words a text uses */
/* For each word the reader does not know: find its lemma (forms table and  */
/* regular endings), take the first sense of each part of speech, and       */
/* follow "kind of" up WordNet until it meets an anchor. Every concept on    */
/* the way is written to concepts_wn.src with its WordNet id and definition */
/* so each imported line can be audited. Names are skipped.                 */
/* Usage: rexx wn_import.rex story.txt [readerdir]                          */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                         */
/* Data: Open English WordNet 2025 (CC BY 4.0).                             */
parse arg story rdir
/* the reader folder is the one above this program's own */
parse source . . me
if rdir == '' then rdir = filespec('L', me)'..'
rdir = rdir~strip('T', '/')
here = rdir'/wordnet'
ws = .WordStore~new(here'/oewn.db')
lex = .Lexicon~new(rdir'/lexicon.words')
/* gloss of each compiled concept id, so a form of a hand word can point at it */
glossOf = .StringTable~new
s = .Stream~new(rdir'/concepts.words')~~open('read')
do while s~lines > 0
  parse value s~linein with cid '|' g '|' .
  glossOf[cid] = g
end
s~close

/* glosses already taken, and what is already imported */
taken = .StringTable~new
call takeGlosses rdir'/concepts.src', taken
call takeGlosses here'/concepts_wn.src', taken
imported = .StringTable~new
if SysFileExists(here'/wn_map.words') then do
  s = .Stream~new(here'/wn_map.words')~~open('read')
  do while s~lines > 0
    parse value s~linein with id '|' g
    imported[id] = g
  end
  s~close
end
anchors = .StringTable~new
s = .Stream~new(here'/anchors.src')~~open('read')
do while s~lines > 0
  ln = s~linein
  if ln~strip == '' | ln~left(1) == '#' then iterate
  parse var ln lemma '|' pos '|' rank '|' g
  id = ws~senseOf(lemma, pos, rank)
  if id == '' then say 'anchor not found:' ln
  else anchors[id] = g
end
s~close

/* the words of the text, and which are names */
words = .Array~new
seenW = .StringTable~new
capMid = .StringTable~new
lowAny = .StringTable~new
capStart = .StringTable~new
nextOf = .StringTable~new
prevStart = ''
s = .Stream~new(story)~~open('read')
/* a cast list beside the story declares names outright */
cast = .StringTable~new
castFile = filespec('L', story)'cast.words'
if SysFileExists(castFile) then do
  cs = .Stream~new(castFile)~~open('read')
  do while cs~lines > 0
    nm = cs~linein~strip~lower
    if nm \== '' then cast[nm] = 1
  end
  cs~close
end
do while s~lines > 0
  t = s~linein~changeStr('’', "'")~changeStr('“', '"')~changeStr('”', '"')
  t = t~changeStr('"', ' . ')~changeStr('.', ' . ')~changeStr('!', ' . ')~changeStr('?', ' . ')~changeStr(',', ' ')~changeStr('—', ' ')
  start = .true
  /* a heading is title case: its capitals say nothing about names */
  heading = (t~strip~left(1) == '#')
  do w over t~subWords
    if w == '#' then iterate
    if heading then do
      lw = w~lower
      if \seenW~hasIndex(lw) then do
        seenW[lw] = 1
        words~append(lw)
      end
      iterate
    end
    if w == '.' then do
      start = .true
      iterate
    end
    w = w~changeStr("'s", '')
    lw = w~lower
    /* HUGE, BIG: emphasis, not a capital */
    if w~length > 1 then if w == w~upper then w = lw
    if prevStart \== '' then do
      nextOf[prevStart] = (nextOf[prevStart] lw)~strip
      prevStart = ''
    end
    if w~left(1) \== lw~left(1) then do
      if start then do
        capStart[lw] = 1
        prevStart = lw
      end
      else capMid[lw] = 1
    end
    else lowAny[lw] = 1
    start = .false
    if \seenW~hasIndex(lw) then do
      seenW[lw] = 1
      words~append(lw)
    end
  end
end
s~close

cOut = .Stream~new(here'/concepts_wn.src')~~open('write append')
lOut = .Stream~new(here'/lexicon_wn.src')~~open('write append')
mOut = .Stream~new(here'/wn_map.words')~~open('write append')
newWords = 0
newConcepts = 0
skipped = ''
do w over words
  /* the hand lexicon is authoritative for every word it lists */
  if lex~known(w) then iterate
  if verify(w, "abcdefghijklmnopqrstuvwxyz-'") \= 0 then iterate
  if cast~hasIndex(w) then iterate
  /* a capital mid-sentence is a name, unless WordNet has the word as an
     adjective: British, Russian, French are proper adjectives, not people.
     A character called Frank goes in cast.words. */
  if capMid~hasIndex(w) then if morph(ws, w, 'a') == '' then iterate
  /* a capital only at sentence starts is a name unless WordNet knows the
     word, and even then a name if a past-tense verb follows it directly
     ("Pip dropped"): a common noun there would need "the" or "a" */
  if capStart~hasIndex(w) then if \lowAny~hasIndex(w) then do
    known = 0
    do pz over .array~of('n', 'v', 'a')
      if morph(ws, w, pz) \== '' then known = 1
    end
    if known = 0 then iterate
    if morph(ws, w, 'a') == '' then do
      nameLike = 0
      nxl = nextOf[w]
      if nxl == .nil then nxl = ''
      do nx over nxl~subWords
        /* the hand lexicon decides for words it knows ("are" is present);
           otherwise only a regular -ed past counts */
        if lex~known(nx) then do c over lex~candidates(.array~of(nx), 1)
          if c['E']['FEATS']['form'] == 'past' then nameLike = 1
        end
        else if nx~right(2) == 'ed' then if morph(ws, nx, 'v')~pos('form=past') > 0 then nameLike = 1
      end
      if nameLike then iterate
    end
  end
  got = 0
  /* acorns, wags: a form of a word the hand lexicon knows keeps the hand concept */
  handForm = .false
  do pos over .array~of('n', 'v')
    lp = word('noun verb', pos(pos, 'nv'))
    do c over stemsOf(w, pos)
      parse var c stem '|' feats
      if stem == w then iterate
      if \lex~known(stem) then iterate
      do e over lex~candidates(.array~of(stem), 1)
        if e['E']['POS'] \== lp then iterate
        if \glossOf~hasIndex(e['E']['CONCEPT']) then iterate
        lOut~lineout(w'|'lp'|^'glossOf[e['E']['CONCEPT']]'|'feats)
        handForm = .true
        leave
      end
      if handForm then leave
    end
    if handForm then leave
  end
  if handForm then do
    newWords = newWords + 1
    iterate
  end
  do pos over .array~of('n', 'v', 'a', 'r')
    m = morph(ws, w, pos)
    if m == '' then iterate
    parse var m lemma '|' feats
    id = ws~senseOf(lemma, pos, 1)
    if pos == 'r' then g = importAdverb(id)
    else g = import(id, pos)
    lpos = word('noun verb adj adv', pos(pos, 'nvar'))
    /* a verb whose chain reaches the "say" anchor introduces speech */
    if pos == 'v' then if reaches(id, 'say') then feats = (feats';speech=yes')~strip('L', ';')
    lOut~lineout(w'|'lpos'|^'g'|'feats)
    got = got + 1
  end
  if got > 0 then newWords = newWords + 1
  else skipped = skipped w
end
cOut~close
lOut~close
mOut~close
say 'imported' newWords 'words,' newConcepts 'new concepts'
if skipped \== '' then say 'not in WordNet (left for the hand lexicon):' skipped~strip
exit 0

/* lemma and lexicon features for a surface word as part of speech pos */
morph: procedure
  use arg ws, w, pos
  cands = .Array~new
  do f over ws~formsOf(w)
    if f[2] == pos then do
      /* fell / fallen: both are irregular forms; a -en, -wn or -ne form is the
         participle, so the realiser never says "nuts fallen" (declared heuristic) */
      if pos == 'v' then do
        pp = ''
        if w \== f[1] then if wordpos(right(w, 2), 'en wn ne') > 0 then pp = ';pp=yes'
        cands~append(f[1]'|form=past'pp)
      end
      if pos == 'n' then cands~append(f[1]'|num=pl')
    end
  end
  if pos == 'n' then do
    cands~append(w'|')
    call ending cands, w, 'ies', 'y', 'num=pl'
    call ending cands, w, 'ves', 'f', 'num=pl'
    call ending cands, w, 'es', '', 'num=pl'
    call ending cands, w, 's', '', 'num=pl'
  end
  if pos == 'v' then do
    cands~append(w'|form=base')
    call ending cands, w, 'ied', 'y', 'form=past'
    call ending cands, w, 'ed', '', 'form=past'
    call ending cands, w, 'ed', 'e', 'form=past'
    call ending cands, w, 'ing', '', 'form=ing'
    call ending cands, w, 'ing', 'e', 'form=ing'
    call ending cands, w, 'ies', 'y', 'form=pres3'
    call ending cands, w, 'es', '', 'form=pres3'
    call ending cands, w, 's', '', 'form=pres3'
    /* stopped -> stop, running -> run */
    do sfx over .array~of('ed', 'ing')
      if w~length > sfx~length + 2 then if w~right(sfx~length) == sfx then do
        stem = w~left(w~length - sfx~length)
        if stem~right(1) == stem~substr(stem~length - 1, 1) then do
          ff = 'form=past'
          if sfx == 'ing' then ff = 'form=ing'
          cands~append(stem~left(stem~length - 1)'|'ff)
        end
      end
    end
  end
  if pos == 'a' then cands~append(w'|')
  if pos == 'r' then cands~append(w'|')
  do c over cands
    parse var c lemma '|' .
    if lemma \== '' then if ws~hasLemma(lemma, pos) then return c
  end
  return ''

/* candidate stems by regular endings only (no WordNet needed) */
stemsOf: procedure
  use arg w, pos
  cands = .Array~new
  if pos == 'n' then do
    call ending cands, w, 'ies', 'y', 'num=pl'
    call ending cands, w, 'es', '', 'num=pl'
    call ending cands, w, 's', '', 'num=pl'
  end
  if pos == 'v' then do
    call ending cands, w, 'ied', 'y', 'form=past'
    call ending cands, w, 'ed', '', 'form=past'
    call ending cands, w, 'ed', 'e', 'form=past'
    call ending cands, w, 'ing', '', 'form=ing'
    call ending cands, w, 'ing', 'e', 'form=ing'
    call ending cands, w, 's', '', 'form=pres3'
  end
  return cands

ending: procedure
  use arg cands, w, sfx, add, feats
  if w~length > sfx~length + 1 then if w~right(sfx~length) == sfx then cands~append(w~left(w~length - sfx~length)||add'|'feats)
  return

/* the gloss for a synset, importing it and its chain if needed */
import: procedure expose ws anchors imported taken cOut mOut newConcepts
  use arg id, pos
  if anchors~hasIndex(id) then return anchors[id]
  if imported~hasIndex(id) then return imported[id]
  mg = ws~members(id)
  parse value mg[1] with first ';' .
  base = first~lower~changeStr(' ', '-')~changeStr("'", '')
  g = base
  if taken~hasIndex(g) then g = base'~'id
  taken[g] = 1
  imported[id] = g
  defs = ''
  if pos == 'a' then do
    /* an adjective is a value; its parent is the slot it is a value of */
    at = ws~first(id, 'attr')
    if at == '' then do
      head = ws~first(id, 'similar')
      if head \== '' then at = ws~first(head, 'attr')
    end
    if at == '' then parent = 'quality'
    else parent = import(at, 'n')
  end
  else do
    h = ws~first(id, 'hyper')
    if h == '' then do
      if pos == 'v' then parent = 'event'
      else parent = 'thing'
    end
    else parent = import(h, pos)
    if pos == 'n' then do
      wh = ws~wholeOf(id)
      if wh \== '' then do
        if anchors~hasIndex(wh) then defs = 'part-of=^'anchors[wh]
        else if imported~hasIndex(wh) then defs = 'part-of=^'imported[wh]
      end
    end
  end
  cOut~lineout('# wn' id':' mg[2]~left(min(100, mg[2]~length)))
  cOut~lineout(g'|'parent'|'defs)
  mOut~lineout(id'|'g)
  newConcepts = newConcepts + 1
  return g

/* does the first-hypernym chain of id reach the anchor with this gloss? */
reaches: procedure expose ws anchors
  use arg id, gloss
  do 30
    if id == '' then return .false
    if anchors~hasIndex(id) then return anchors[id] == gloss
    id = ws~first(id, 'hyper')
  end
  return .false

/* adverbs have no "kind of" chain: each is a plain concept */
importAdverb: procedure expose ws anchors imported taken cOut mOut newConcepts
  use arg id
  if imported~hasIndex(id) then return imported[id]
  mg = ws~members(id)
  parse value mg[1] with first ';' .
  base = first~lower~changeStr(' ', '-')~changeStr("'", '')
  g = base
  if taken~hasIndex(g) then g = base'~'id
  taken[g] = 1
  imported[id] = g
  cOut~lineout('# wn' id':' mg[2]~left(min(100, mg[2]~length)))
  cOut~lineout(g'|thing|')
  mOut~lineout(id'|'g)
  newConcepts = newConcepts + 1
  return g

takeGlosses: procedure
  use arg file, taken
  if \SysFileExists(file) then return
  s = .Stream~new(file)~~open('read')
  do while s~lines > 0
    ln = s~linein
    if ln~strip == '' | ln~left(1) == '#' then iterate
    parse var ln g '|' .
    taken[g~strip] = 1
  end
  s~close
  return

::requires 'wordstore.cls'
::requires 'reader.cls'
