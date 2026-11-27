/* HeelTurnLanguage.cls - Heel Turn SLAM: words to concept items.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Closed-class roles (NEGATOR MODAL PRONOUN JOIN PREP DETERMINER TITLE) come
   from the Librarian's deterministic grammar (LibrarianGrammar). Open words
   come from data/lexicon.src (Boston Crab house format) and point at
   concepts in data/concepts.src. Board places and powers come from the MAP
   the framework sends. Nothing here predicts text. */
::requires 'LibrarianSalvagedCore_v09.cls'

::class HeelTurnVocabulary public
::attribute dataDir get
::attribute maxWords get
::method init
  expose dataDir parentOf lexicon rules grammar maxWords firstLabels testimony
  use strict arg dataDir
  if dataDir~right(1) \== '/' then dataDir = dataDir'/'
  parentOf = .directory~new
  lexicon = .directory~new
  rules = .directory~new
  firstLabels = .directory~new
  maxWords = 1
  do line over heelTurnReadLines(dataDir'concepts.src')
    parse var line concept '|' parent '|' .
    parentOf[concept~strip] = parent~strip
  end
  do line over heelTurnReadLines(dataDir'lexicon.src')
    parse var line label '|' pos '|' concept '|' feats
    label = label~strip~lower
    concept = concept~strip
    if concept~left(1) == '^' then concept = concept~substr(2)
    if \parentOf~hasIndex(concept) then raise syntax 93.900 array('lexicon.src: unknown concept' concept 'for' label)
    entry = .directory~new
    entry['POS'] = pos~strip
    entry['CONCEPT'] = concept
    entry['LABEL'] = label
    entry['FEATS'] = heelTurnFeats(feats)
    if \lexicon~hasIndex(label) then lexicon[label] = .array~new
    lexicon[label]~append(entry)
    if words(label) > maxWords then maxWords = words(label)
    key = concept'|'entry['POS']
    if \firstLabels~hasIndex(key) then firstLabels[key] = label
  end
  do line over heelTurnReadLines(dataDir'policy.src')
    parse var line act '|' obj '|' knob '|' weight
    act = act~strip
    obj = obj~strip
    if \parentOf~hasIndex(act) then raise syntax 93.900 array('policy.src: unknown act' act)
    if obj \== '' then if \parentOf~hasIndex(obj) then raise syntax 93.900 array('policy.src: unknown object' obj)
    key = act'|'obj
    if \rules~hasIndex(key) then rules[key] = .array~new
    rules[key]~append(.array~of(knob~strip, weight~strip))
  end
  testimony = .directory~new
  if .stream~new(dataDir'testimony.src')~query('EXISTS') \== '' then do line over heelTurnReadLines(dataDir'testimony.src')
    parse var line key '|' value
    testimony[key~strip] = value~strip
  end
  lex = .LibrarianLexicon~new
  grammar = .LibrarianGrammar~new(lex)
  grammar~installBuiltins
::method testimony
  expose testimony
  return testimony
::method known
  expose parentOf
  use strict arg concept
  return parentOf~hasIndex(concept)
::method parent
  expose parentOf
  use strict arg concept
  if \parentOf~hasIndex(concept) then return ''
  return parentOf[concept]
::method isa
  expose parentOf
  use strict arg concept, ancestor
  c = concept
  do while c \== ''
    if c == ancestor then return .true
    if \parentOf~hasIndex(c) then return .false
    c = parentOf[c]
  end
  return .false
::method chain
  expose parentOf
  use strict arg concept
  out = .array~new
  c = concept
  do while c \== ''
    out~append(c)
    if \parentOf~hasIndex(c) then leave
    c = parentOf[c]
  end
  return out
::method entries
  expose lexicon
  use strict arg label
  if lexicon~hasIndex(label) then return lexicon[label]
  return .array~new
::method role
  expose grammar
  use strict arg word
  return grammar~roleFor(word)
::method label
  expose firstLabels
  use strict arg concept, pos
  key = concept'|'pos
  if firstLabels~hasIndex(key) then return firstLabels[key]
  return concept
::method rulesFor
  -- Most exact rule set for act+object. Walks the act's chain, and for each
  -- act tries the object's chain, then the bare act.
  expose rules
  use strict arg act, obj
  do a over self~chain(act)
    if obj \== '' then do o over self~chain(obj)
      if rules~hasIndex(a'|'o) then return rules[a'|'o]
    end
    if rules~hasIndex(a'|') then return rules[a'|']
  end
  return .array~new
::method ruleKey
  -- The policy.src rule rulesFor chose, as act|object, or '' for none.
  expose rules
  use strict arg act, obj
  do a over self~chain(act)
    if obj \== '' then do o over self~chain(obj)
      if rules~hasIndex(a'|'o) then return a'|'o
    end
    if rules~hasIndex(a'|') then return a'|'
  end
  return ''
::method module_version class
  return '0.1r6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

/* Board places and powers, from the MAP section the framework sends. */
::class HeelTurnPlaces public
::attribute codes get
::method init
  expose codes nameToCode powerNames maxWords
  use strict arg mapLines = (.array~new)
  codes = .directory~new
  nameToCode = .directory~new
  powerNames = .directory~new
  maxWords = 1
  do line over mapLines
    parse var line code '|' name '|' kind '|' .
    if code == '' | kind == '' then iterate
    if code~upper == 'CODE' then iterate
    codes[code~upper] = name
    if code~pos('/') = 0 then do
      self~addName(name~lower, code~upper)
    end
  end
  -- Common short forms a player may write. Only added when the map has them.
  aliases = .array~of('st petersburg=STP', 'saint petersburg=STP', 'st. petersburg=STP', 'mid atlantic=MAO', 'mid-atlantic=MAO', 'north atlantic=NAO', 'gulf of lyons=LYO', 'gulf of lyon=LYO', 'lyon=LYO', 'tyrrhenian=TYS', 'black sea=BLA', 'english channel=ENG', 'the channel=ENG', 'channel=ENG', 'north sea=NTH', 'norwegian sea=NWG', 'barents=BAR', 'baltic=BAL', 'bothnia=BOT', 'skagerrak=SKA', 'heligoland=HEL', 'helgoland=HEL', 'aegean=AEG', 'adriatic=ADR', 'ionian=ION', 'eastern med=EAS', 'western med=WES', 'irish sea=IRI', 'constantinople=CON', 'istanbul=CON', 'north africa=NAF', 'tyrol=TYR', 'tyrolia=TYR', 'ruhr=RUH', 'prussia=PRU', 'silesia=SIL', 'galicia=GAL', 'bohemia=BOH', 'ukraine=UKR', 'livonia=LVN', 'piedmont=PIE', 'tuscany=TUS', 'apulia=APU', 'picardy=PIC', 'burgundy=BUR', 'gascony=GAS', 'wales=WAL', 'yorkshire=YOR', 'clyde=CLY', 'edinburgh=EDI', 'liverpool=LVP', 'london=LON')
  do pair over aliases
    parse var pair nm '=' cd
    if codes~hasIndex(cd) then self~addName(nm, cd)
  end
  powers = .array~of('AUS=austria austrian austria-hungary austro-hungarian austro-hungary', 'ENG=england english britain british uk', 'FRA=france french', 'GER=germany german', 'ITA=italy italian', 'RUS=russia russian', 'TUR=turkey turkish ottoman ottomans')
  do pair over powers
    parse var pair cd '=' names
    do w over names~makeArray(' ')
      powerNames[w] = cd
    end
  end
::method addName private
  expose nameToCode maxWords
  use strict arg nm, cd
  nameToCode[nm] = cd
  if words(nm) > maxWords then maxWords = words(nm)
::method maxWords
  expose maxWords
  return maxWords
::method isCode
  expose codes
  use strict arg token
  return codes~hasIndex(token~upper)
::method codeForName
  expose nameToCode
  use strict arg phrase
  if nameToCode~hasIndex(phrase) then return nameToCode[phrase]
  return ''
::method powerFor
  expose powerNames
  use strict arg word
  if powerNames~hasIndex(word) then return powerNames[word]
  return ''
::method isPowerCode
  use strict arg token
  return wordpos(token~upper, 'AUS ENG FRA GER ITA RUS TUR') > 0
::method base
  use strict arg code
  parse var code b '/' .
  return b
::method name
  expose codes
  use strict arg code
  if codes~hasIndex(code) then return codes[code]
  return code
::method module_version class
  return '0.1r6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

/* Reads sentences into items. One item per word or phrase:
   K = kind, C = concept, T = text as written, F = features.
   Kinds: NEGATOR MODAL PRONOUN JOIN PREP DETERMINER TITLE (Librarian roles),
   ACT OBJ QUAL COND TIME TONE NEGVERB CONDWORD FORCE SUBJ FILLER (lexicon),
   PROV POWER UNIT DASH NUM PUNCT UNKNOWN. */
::class HeelTurnReader public
::attribute vocab get
::method init
  expose vocab places
  use strict arg vocab, places = .nil
  if places == .nil then places = .HeelTurnPlaces~new
::method places
  expose places
  return places
::method sentences
  -- Lines are kept apart (bullets, headings). Inside a line, . ! ? ; end
  -- a sentence when a space or the end follows. Bullet marks are dropped.
  use strict arg text
  out = .array~new
  normal = changestr('0D0A'x, text, '0A'x)
  normal = changestr('0D'x, normal, '0A'x)
  do line over normal~makeArray('0A'x)
    line = line~strip
    do while line \== ''
      first = line~left(1)
      if pos(first, '-*#>') = 0 then do
        if first~datatype('W') then do
          parse var line num rest
          if num~right(1) == '.' | num~right(1) == ')' then do
            line = rest~strip
            iterate
          end
        end
        leave
      end
      line = line~substr(2)~strip
    end
    if line == '' then iterate
    buffer = ''
    do idx = 1 to line~length
      ch = line~substr(idx, 1)
      buffer = buffer || ch
      if pos(ch, '.!?;') > 0 then do
        nextCh = line~substr(idx + 1, 1)
        if nextCh == ' ' | idx = line~length then do
          if ch == '.' & heelTurnAbbrev(buffer) then iterate
          if buffer~strip \== '' then out~append(buffer~strip)
          buffer = ''
        end
      end
    end
    if buffer~strip \== '' then out~append(buffer~strip)
  end
  return out
::method items
  expose vocab places
  use strict arg sentence
  toks = heelTurnTokens(sentence)
  out = .array~new
  n = toks~items
  idx = 1
  do while idx <= n
    tok = toks[idx]
    w = tok['W']
    o = tok['O']
    -- punctuation
    if w~length = 1 & pos(w, '?.!,;:()"') > 0 then do
      out~append(heelTurnItem('PUNCT', w, o))
      idx += 1
      iterate
    end
    if w == '-' | w == '->' | w == '=>' then do
      out~append(heelTurnItem('DASH', '-', o))
      idx += 1
      iterate
    end
    -- unit: A / F / army / fleet then a place
    if wordpos(w, 'a f army fleet') > 0 & idx < n then do
      skip = 0
      if wordpos(w, 'army fleet') > 0 & idx + 1 < n then if wordpos(toks[idx + 1]['W'], 'in at from on') > 0 then skip = 1
      took = self~placeAt(toks, idx + 1 + skip, skip = 0)
      if took~items > 0 then took[1] = took[1] + skip
      if took~items > 0 then do
        ok = .true
        if w == 'a' | w == 'f' then if o \== o~upper then ok = .false
        if ok then do
          kind = 'A'
          if w == 'f' | w == 'fleet' then kind = 'F'
          item = heelTurnItem('UNIT', kind took[2], o took[3])
          item['TYPE'] = kind
          item['LOC'] = took[2]
          out~append(item)
          idx += 1 + took[1]
          iterate
        end
      end
    end
    -- multi-word lexicon phrases before single places (english channel is a place)
    phrase = self~lexAt(toks, idx, 2)
    placeHit = self~placeAt(toks, idx, .false)
    if phrase~items > 0 & placeHit~items > 0 then do
      if placeHit[1] >= phrase[1] then phrase = .array~new
      else placeHit = .array~new
    end
    if phrase~items > 0 then do
      out~append(self~lexItem(phrase[2], phrase[3], '', out))
      idx += phrase[1]
      iterate
    end
    if placeHit~items > 0 then do
      item = heelTurnItem('PROV', placeHit[2], placeHit[3])
      item['CODE'] = placeHit[2]
      out~append(item)
      idx += placeHit[1]
      iterate
    end
    -- powers
    pw = places~powerFor(w)
    if pw == '' then if places~isPowerCode(w) then if o == o~upper then pw = w~upper
    if pw \== '' then do
      item = heelTurnItem('POWER', pw, o)
      item['CODE'] = pw
      out~append(item)
      idx += 1
      iterate
    end
    if w~datatype('N') then do
      out~append(heelTurnItem('NUM', w, o))
      idx += 1
      iterate
    end
    -- single words: specific lexicon kinds, then Librarian roles, then lexicon
    entries = vocab~entries(w)
    special = .nil
    do e over entries
      if wordpos(e['POS'], 'force condword negverb') > 0 then do
        special = e
        leave
      end
    end
    if special \== .nil then do
      out~append(self~lexItem(entries, o, special['POS'], out))
      idx += 1
      iterate
    end
    role = vocab~role(w)
    if role \== '' & entries~items = 0 then do
      out~append(heelTurnItem(role, w~upper, o))
      idx += 1
      iterate
    end
    if role \== '' then do
      -- Librarian role wins for closed-class words, except where the
      -- lexicon has an act or object for it (back, may as a modal stays).
      useLex = .false
      do e over entries
        if wordpos(e['POS'], 'act obj qual') > 0 then useLex = .true
      end
      if wordpos(role, 'MODAL NEGATOR PRONOUN DETERMINER JOIN') > 0 then useLex = .false
      if \useLex then do
        out~append(heelTurnItem(role, w~upper, o))
        idx += 1
        iterate
      end
    end
    if entries~items = 0 then entries = self~stemEntries(w)
    if entries~items > 0 then do
      out~append(self~lexItem(entries, o, '', out))
      idx += 1
      iterate
    end
    out~append(heelTurnItem('UNKNOWN', w, o))
    idx += 1
  end
  return out
::method lexAt private
  -- Longest lexicon label of at least minWords words starting at idx.
  expose vocab
  use strict arg toks, idx, minWords
  best = .array~new
  limit = vocab~maxWords
  do len = limit to minWords by -1
    if idx + len - 1 > toks~items then iterate
    phraseText = ''
    origs = ''
    do k = idx to idx + len - 1
      phraseText = phraseText toks[k]['W']
      origs = origs toks[k]['O']
    end
    phraseText = phraseText~strip
    entries = vocab~entries(phraseText)
    if entries~items > 0 then return .array~of(len, entries, origs~strip)
  end
  return best
::method placeAt private
  -- Longest place name at idx, or a 3-letter code (with /XX coast).
  -- A code that is also an English word counts only in capitals, unless
  -- the caller already knows a place must follow (after A or F).
  expose places
  use strict arg toks, idx, afterUnit
  limit = places~maxWords
  do len = limit to 1 by -1
    if idx + len - 1 > toks~items then iterate
    phraseText = ''
    origs = ''
    do k = idx to idx + len - 1
      phraseText = phraseText toks[k]['W']
      origs = origs toks[k]['O']
    end
    phraseText = phraseText~strip
    code = places~codeForName(phraseText)
    if code \== '' then return .array~of(len, code, origs~strip)
  end
  w = toks[idx]['W']
  o = toks[idx]['O']
  if places~isCode(w) then do
    if o == o~upper | afterUnit then return .array~of(1, w~upper, o)
  end
  return .array~new
::method lexItem private
  -- One lexicon word with its alternatives. prefer names a part of speech
  -- to take first. After a determiner or a possessive (an ally, your ally)
  -- a word with an object sense is the object, not the act.
  expose vocab
  use strict arg entries, o, prefer, sofar
  order = 'force condword act obj qual cond time tone negverb subj filler'
  if sofar~items > 0 then do
    prev = sofar[sofar~items]
    possessive = .false
    if prev['K'] == 'PRONOUN' then if wordpos(prev['C'], 'MY YOUR OUR THEIR HIS HER ITS') > 0 then possessive = .true
    if prev['K'] == 'DETERMINER' | possessive | prev['K'] == 'OBJ' then order = 'force condword obj qual act cond time tone negverb subj filler'
    -- after a negating verb the word is the act it negates: avoid ATTACKING
    if prev['K'] == 'NEGVERB' then order = 'act force condword obj qual cond time tone negverb subj filler'
  end
  if prefer \== '' then order = prefer order
  best = .nil
  bestRank = 99
  do e over entries
    rank = wordpos(e['POS'], order)
    if rank = 0 then rank = 98
    if rank < bestRank then do
      best = e
      bestRank = rank
    end
  end
  item = heelTurnItem(best['POS']~upper, best['CONCEPT'], o)
  item['F'] = best['FEATS']
  item['ALT'] = entries
  return item
::method stemEntries private
  expose vocab
  use strict arg w
  tries = .array~new
  len = w~length
  if len > 3 & w~right(3) == 'ies' then tries~append(w~left(len - 3)'y')
  if len > 3 & w~right(2) == 'es' then tries~append(w~left(len - 2))
  if len > 2 & w~right(1) == 's' then tries~append(w~left(len - 1))
  if len > 4 & w~right(3) == 'ing' then do
    stem = w~left(len - 3)
    tries~append(stem)
    tries~append(stem'e')
    if stem~length > 2 then if stem~right(1) == stem~substr(stem~length - 1, 1) then tries~append(stem~left(stem~length - 1))
  end
  if len > 3 & w~right(2) == 'ed' then do
    stem = w~left(len - 2)
    tries~append(stem)
    tries~append(w~left(len - 1))
    if stem~length > 2 then if stem~right(1) == stem~substr(stem~length - 1, 1) then tries~append(stem~left(stem~length - 1))
  end
  if len > 4 & w~right(2) == 'ly' then tries~append(w~left(len - 2))
  do t over tries
    entries = vocab~entries(t)
    if entries~items > 0 then return entries
  end
  return .array~new
::method fixNegverbs
  -- A negating verb must govern an act: "avoid attacking", "stop lying".
  -- "stop the leader" or "afraid" alone take the word's other sense.
  use strict arg items
  do idx = 1 to items~items
    item = items[idx]
    if item['K'] \== 'NEGVERB' then iterate
    governs = .false
    do k = idx + 1 to min(idx + 3, items~items)
      if items[k]['K'] == 'ACT' then governs = .true
      if items[k]['K'] == 'PUNCT' then leave
    end
    if governs then iterate
    if \item~hasIndex('ALT') then iterate
    do e over item['ALT']
      if e['POS'] \== 'negverb' then do
        item['K'] = e['POS']~upper
        item['C'] = e['CONCEPT']
        item['F'] = e['FEATS']
        leave
      end
    end
  end
  return items
::method module_version class
  return '0.1r6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnItem public
  use strict arg kind, concept, text
  item = .directory~new
  item['K'] = kind
  item['C'] = concept
  item['T'] = text
  item['F'] = .directory~new
  return item

::routine heelTurnFeats public
  use strict arg text
  feats = .directory~new
  do part over text~strip~makeArray(';')
    if part~strip == '' then iterate
    parse var part k '=' v
    feats[k~strip] = v~strip
  end
  return feats

::routine heelTurnAbbrev
  use strict arg buffer
  last = buffer~strip~word(words(buffer~strip))~lower
  if wordpos(last, 'e.g. i.e. etc. vs. st. mr. dr. no.') > 0 then return .true
  -- a number such as 5. at the start of a bullet is not an end
  return .false

::routine heelTurnReadLines public
  use strict arg path
  out = .array~new
  src = .stream~new(path)
  if src~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read' path)
  do while src~lines > 0
    line = src~linein
    if line~strip == '' then iterate
    if line~left(1) == '#' then iterate
    out~append(line)
  end
  src~close
  return out

::routine heelTurnTokens public
  -- Words keep letters, digits, / ' - % inside them. Contractions open out
  -- (won't = will not, don't = do not, let's = let us). Each token keeps
  -- the form as written (O) and a lower-case form (W).
  use strict arg text
  out = .array~new
  t = text~changestr('E28099'x, "'")~changestr('E28098'x, "'")
  t = t~changestr('E2809C'x, '"')~changestr('E2809D'x, '"')
  t = t~changestr('E28093'x, ' - ')~changestr('E28094'x, ' - ')
  t = t~translate(' ', '09'x)
  buffer = ''
  do idx = 1 to t~length + 1
    ch = t~substr(idx, 1)
    if idx > t~length then ch = ' '
    inner = .false
    if ch == '.' & buffer \== '' then if t~substr(idx + 1, 1)~datatype('A') then inner = .true
    if ch~datatype('A') | pos(ch, "/'-%_") > 0 | ch~c2d > 127 | inner then do
      buffer = buffer || ch
      iterate
    end
    if buffer \== '' then call heelTurnPush out, buffer
    buffer = ''
    if ch \== ' ' then call heelTurnPush out, ch
  end
  return out

::routine heelTurnPush
  use strict arg out, raw
  word = raw
  do while word~length > 1 & pos(word~right(1), "'-") > 0
    word = word~left(word~length - 1)
  end
  do while word~length > 1 & pos(word~left(1), "'-") > 0
    word = word~substr(2)
  end
  if word == '' then return
  low = word~lower
  -- A move written without spaces: BUD-SER, BUD->SER
  if word~pos('-') > 1 & word == word~upper then do
    parse var word lhs '-' rhs
    rhs = rhs~strip('L', '>')
    if lhs~length >= 3 & rhs~length >= 3 & lhs~left(3)~datatype('U') & rhs~left(3)~datatype('U') then do
      call heelTurnPush out, lhs
      call heelTurnPush out, '-'
      call heelTurnPush out, rhs
      return
    end
  end
  expand = ''
  select
    when low == "won't" then expand = 'will not'
    when low == "can't" then expand = 'can not'
    when low == "cannot" then expand = 'can not'
    when low == "shan't" then expand = 'shall not'
    when low == "let's" then expand = 'let us'
    when low~right(3) == "n't" then expand = low~left(low~length - 3) 'not'
    when low~right(3) == "'ll" then expand = low~left(low~length - 3) 'will'
    when low~right(3) == "'re" then expand = low~left(low~length - 3) 'are'
    when low~right(3) == "'ve" then expand = low~left(low~length - 3) 'have'
    when low~right(2) == "'m" then expand = low~left(low~length - 2) 'am'
    when low~right(2) == "'d" then expand = low~left(low~length - 2) 'would'
    when low~right(2) == "'s" then do
      stem = low~left(low~length - 2)
      if wordpos(stem, 'it that there he she what who where here') > 0 then expand = stem 'is'
      else expand = stem
    end
    otherwise nop
  end
  if expand \== '' then do
    do part over expand~makeArray(' ')
      tok = .directory~new
      tok['W'] = part
      tok['O'] = part
      out~append(tok)
    end
    return
  end
  tok = .directory~new
  tok['W'] = low~changestr("'", '')
  tok['O'] = word
  out~append(tok)

::routine heelTurnClip public
  use strict arg v
  if v < 0 then return 0
  if v > 1 then return 1
  return format(v,,3)

::routine heelTurnSorted public
  use strict arg collection
  arr = .array~new
  do x over collection
    arr~append(x)
  end
  return arr~sort
