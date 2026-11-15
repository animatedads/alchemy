/* read_story.rex - read a story into concepts, check it, say it again.   */
/* Usage: rexx read_story.rex datadir outdir                              */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                       */
parse arg dir outdir
if outdir == '' then outdir = dir'/out'
call SysMkDir outdir
rd = .Reader~new(dir)
rd~readFile(dir'/story.txt')

/* 1. the concept graph: ids only */
g = .Stream~new(outdir'/graph.words')~~open('write replace')
do id over rd~props~allIndexes~sortWith(.CaselessComparator~new)
  p = rd~props[id]
  ln = id'|'p['ACT']'|'p['EVENT']'|pol='p['POL']
  if p['MODAL'] \== '' then ln = ln'|modal='p['MODAL']
  if p['ASPECT'] \== '' then ln = ln'|aspect='p['ASPECT']
  if p~hasIndex('ASKS') then ln = ln'|asks='p['ASKS']
  if p~hasIndex('FRAG') then ln = ln'|frag='p['FRAG']
  if p~hasIndex('TIER') then ln = ln'|tier='p['TIER']
  if p~hasIndex('REPORT') then ln = ln'|report='p['REPORT']
  if p~hasIndex('COMPANY') then ln = ln'|company-of='p['COMPANY']
  do r over p['ROLES']~allIndexes~sortWith(.CaselessComparator~new)
    ln = ln'|'r'='p['ROLES'][r]
  end
  if p~hasIndex('SPEAKER') then ln = ln'|speaker='p['SPEAKER']'|addressee='p['ADDRESSEE']'|sverb='p['SVERB']
  g~lineout(ln)
end
g~close
e = .Stream~new(outdir'/entities.words')~~open('write replace')
do id over rd~ents~allIndexes~sortWith(.CaselessComparator~new)
  en = rd~ents[id]
  e~lineout(id'|'en~concept"|name="en~name"|attrs="en~attrs"|loc="en~loc"|holder="en~holder"|home="en~home"|owner="en~owner"|part-of="en~partOf"|amount="en~amount"|members="en~members"|relation="en~relation"|rel-of="en~relOf"|loc-inferred-from="en~locInfer)
end
e~close

/* 2. English again, from the graph alone */
rz = .Realiser~new(rd)
o = .Stream~new(outdir'/realised.txt')~~open('write replace')
do id over rd~order
  o~lineout(rz~sentence(rd~props[id]))
end
o~close

/* 3. findings, in English from ids */
rf = .Realiser~new(rd)
do id over rd~ents~allIndexes
  rf~seen[id] = 1
end
f = .Stream~new(outdir'/findings.txt')~~open('write replace')
nc = .Directory~new
do fd over rd~findings
  f~lineout(render(fd, rf, rd, nc))
end
f~close

/* 4. what it could not read */
u = .Stream~new(outdir'/unread.txt')~~open('write replace')
do x over rd~unread
  u~lineout(x)
end
do id over rd~order
  if rd~props[id]['NOTE'] \== '' then u~lineout(id':' rd~props[id]['NOTE'])
end
u~close

/* 5. a gloss view for people (not part of the scramble test) */
v = .Stream~new(outdir'/gloss_view.txt')~~open('write replace')
s = .Stream~new(outdir'/graph.words')~~open('read')
do while s~lines > 0
  v~lineout(glossy(s~linein, rd))
end
s~close
v~close

say 'props:' rd~order~items '  entities:' rd~ents~items '  findings:' rd~findings~items '  unread:' rd~unread~items
exit 0

glossy: procedure
  use arg ln, rd
  out = ''
  p = 1
  do forever
    q = ln~pos('C.', p)
    if q = 0 then leave
    out = out||ln~substr(p, q - p)
    id = ln~substr(q, 6)
    out = out||'<'rd~cs~gloss[id]'>'
    p = q + 6
  end
  return out||ln~substr(p)

say1: procedure
  use arg rf, p
  return rf~sentence(p)

render: procedure
  use arg fd, rf, rd, nc
  t = fd['TYPE']
  select
    when t == 'PRONOUN-MISMATCH' then do
      p = fd['PROP']
      parse value fd['PRE'] with . '~' tgt
      return 'PRONOUN  "'fd['WORD']'" fits nobody here who can be' rf~verb(fd['EVENT'], 'ing') '(that needs the' rf~noun(tgt, .false)'). Only' rf~ent(fd['CHOSEN'], nc) 'fits. Read as:' rf~sentence(p)
    end
    when t == 'PRECONDITION-FAILS' then do
      p = fd['PROP']
      if fd['UNSURE'] == 1 then return 'UNSURE    'rf~sentence(p) '- that looks impossible, but a sentence about' rf~ent(fd['CHOSEN'], nc) 'just before was unread, so it may have changed.'
      w = fd['CHOSEN']
      parse value fd['PRE'] with . '.' op '=' r2
      wh = ''
      if fd['LOC'] \== .nil then wh = rf~pp('at', fd['LOC'], nc)
      if op == 'on-same' | op == 'within' then return 'NEEDS     'rf~sentence(p) '- but' rf~ent(w, nc) 'was' wh', not on that.'
      if fd['PRE']~pos('!~') > 0 then return 'NEEDS     'rf~sentence(p) '- but' rf~ent(w, nc) 'was' wh'.'
      if fd['PRE']~pos('~') > 0 then do
        parse value fd['PRE'] with . '~' tgt
        return 'NEEDS     'rf~sentence(p) '- but' rf~ent(w, nc) 'was' wh', not in the' rf~noun(tgt, .false)'.'
      end
      return 'NEEDS     'rf~sentence(p) '- but' rf~ent(w, nc) 'was' wh'.'
    end
    when t == 'BRIDGE' then return 'SAME?    "the' rf~noun(fd['CONCEPT'], .false)'" was taken as' describe(fd['A'], rf, rd, nc)', the nearest place of a sibling kind'
    when t == 'MAYBE-SAME' then return 'SAME?    ' describe(fd['A'], rf, rd, nc) 'may be' describe(fd['B'], rf, rd, nc)
    when t == 'CLAIM' then do
      p = fd['PROP']
      h = p['ROLES']['holder']
      return 'CLAIM    ' tf(fd['TRUE']) rf~sentence(p) '- at that point' rf~ent(h, nc) 'was' rf~pp('at', fd['LOC'], nc)'.'
    end
    when t == 'PREMISE' then do
      p = fd['PROP']
      w = fd['WHO']
      return 'PREMISE  ' tf(fd['TRUE']) rf~sentence(p) '- that order needs' rf~ent(w, nc) 'to be there; at that point' rf~ent(w, nc) 'was' rf~pp('at', fd['LOC'], nc)'.'
    end
    when t == 'CONSISTENT' then return 'CHECK     (consistent)' rf~sentence(fd['PROP']) '- matches what we knew.'
    when t == 'CONFLICT' then return 'CHECK     (conflict)' rf~sentence(fd['PROP']) '- but it was' rf~pp('at', fd['OLD'], nc)'.'
    when t == 'COUNT' then do
      what = 'in all'
      if fd['WHAT'] == 'remaining' then what = 'still out (not buried)'
      cl = 'conflict'
      if fd['TRUE'] then cl = 'consistent'
      st = rf~sentence(fd['PROP'])
      st = st~changeStr('[someone]', 'one of the' fd['CLAIMED'] 'remaining' rf~noun(fd['CONCEPT'], .true))
      return 'COUNT     ('cl')' st '- the text says' fd['CLAIMED']'; the story world has' fd['ACTUAL'] rf~noun(fd['CONCEPT'], fd['ACTUAL'] \= 1) what'.'
    end
    when t == 'CONFLICT-NUMBER' then return 'NUMBER    (conflict)' rf~sentence(fd['PROP']) '- that thing already has another number.'
    when t == 'ANSWER' then return 'ANSWER   ' rf~sentence(fd['PROP']) 'answers' rf~sentence(fd['Q'])
    otherwise return t
  end

tf: procedure
  use arg b
  if b then return '(true)'
  return '(false)'

describe: procedure
  use arg id, rf, rd, nc
  en = rd~ents[id]
  adjs = ''
  do a over en~attrs~subWords
    adjs = adjs rf~w('A/'||a)
  end
  out = 'the' adjs~strip rf~noun(en~concept, en~plural)
  if en~loc \== '' then out = out '('rf~pp('at', en~loc, nc)')'
  return space(out)

::requires 'reader.cls'
::requires 'realiser.cls'
