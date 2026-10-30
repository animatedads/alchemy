/* SlamNswLegislation.cls - read a NSW legislation XML file (NSW Parliamentary Counsel "exchange" XML, DTD
 * -//NSWPCO//DTD Ldds Exchange XML//EN) and give the text of a section, its version dates, and the history
 * notes that say when the section was inserted, substituted, amended or repealed.  Pure ooRexx.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.  The same interface as SlamLegislation (the
 * UK's CLML), so SlamLaw's gates take either: section(n, extent) gives '' unless the extent is NSW.
 *
 * What the file gives:
 *   - the version: first.valid.date and end.valid.date on <exdoc> (the Crimes Act file Tom attached is the
 *     version valid 2026-10-01 to 2026-10-28, not the current one)
 *   - a section: <level type="clause" id="sec.192E">, its subsections <tier type="subclause"> and
 *     paragraphs <li>, each numbered by <no>(1)</no>, <no>(a)</no>
 *   - history: notes inside the section, "s 192B-192M): Ins 2009 No 99, Sch 1 [3]", "s 253: Subst 2009 No 99",
 *     "s 117: Am 1974 No 50 ...; 1999 No 94 ...".  Years only: the date an amending Act commenced is not in
 *     this file, so a change in the same year as an event can not be placed before or after it.
 */
::class SlamNswLegislation public
::attribute xml get
::attribute validFrom get
::attribute validTo get
::attribute title get
::method init
  expose xml validFrom validTo title
  use strict arg path
  s = .stream~new(path); s~open('READ'); xml = s~charin(1, s~chars); s~close
  p = xml~pos('<exdoc')
  head = xml~substr(p, xml~pos('>', p) - p)
  parse var head . 'first.valid.date="' validFrom '"' .
  parse var head . 'end.valid.date="' validTo '"' .
  parse var head . 'title="' title '"' .

/* The text of section N in EXTENT (NSW only), one line per numbered subsection or paragraph, or ''. */
::method section
  expose xml
  use strict arg n, extent
  if extent~upper \== 'NSW' then return ''
  p = xml~pos('<level type="clause" id="sec.' || n || '">')
  if p = 0 then return ''
  body = xml~substr(p, self~closeOf(xml, p, 'level') - p)
  t = self~render(body)
  nl = t~pos('0a'x)
  if nl > 0 then if t~left(nl - 1)~strip == n then t = t~substr(nl + 1)   /* the section's own number, from its head */
  if t~word(1) == n then t = t~subword(2)                      /* a section with no subsections: "54 Whosoever" */
  return t

/* History notes in section N: an Array of Directories ACTION (Ins, Subst, Am, Rep, Renumbered) and YEAR. */
::method history
  use strict arg n
  out = .array~new
  t = self~notes(n)
  do w = 1 to t~words - 1
    a = t~word(w)~strip('L', ':')
    if wordpos(a, 'Ins Subst Am Rep Renumbered') = 0 then iterate
    y = t~word(w + 1)
    if \datatype(y, 'W') | y~length \= 4 then iterate
    d = .directory~new; d['ACTION'] = a; d['YEAR'] = y
    out~append(d)
    /* "Am 1974 No 50, sec 6 (h); 1999 No 94, Sch 3 [35]": further years after ";" belong to the same action */
    rest = t~subword(w + 2)
    do while rest~pos(';') > 0
      parse var rest seg ';' rest
      if seg~words > 0 & seg~pos(':') > 0 then leave
      nx = rest~word(1)
      if \datatype(nx, 'W') | nx~length \= 4 then leave
      d2 = .directory~new; d2['ACTION'] = a; d2['YEAR'] = nx
      out~append(d2)
    end
  end
  return out

/* Was section N's text the law at WHEN (YYYY or YYYY-MM-DD)?
     NOT_IN_FORCE         inserted in a year after WHEN's: the section did not exist
     EARLIER_TEXT_NEEDED  substituted or amended after WHEN's year, or in the same year (dates unknown)
     IN_FORCE_TEXT        history notes found, and every one is in a year before WHEN's
     NO_HISTORY_NOTE      the section carries no note: it can not be placed in time from this file
     NOT_IN_THIS_TEXT     the section is not in this version (repealed, or never there): an older text is needed */
::method asAt
  expose xml
  use strict arg n, when
  y = when~left(4)
  if xml~pos('<level type="clause" id="sec.' || n || '">') = 0 then return 'NOT_IN_THIS_TEXT'
  h = self~history(n)
  if h~items = 0 then return 'NO_HISTORY_NOTE'
  do d over h
    if d['ACTION'] == 'Ins' & d['YEAR'] > y then return 'NOT_IN_FORCE'
  end
  do d over h
    if d['YEAR'] >= y then return 'EARLIER_TEXT_NEEDED'
  end
  return 'IN_FORCE_TEXT'

/* The text of the history notes for section N: each <content type="historynote"> in the section. */
::method notes private
  expose xml
  use strict arg n
  p = xml~pos('<level type="clause" id="sec.' || n || '">')
  if p = 0 then return ''
  body = xml~substr(p, self~closeOf(xml, p, 'level') - p)
  out = ''
  q = body~pos('<content type="historynote">')
  do while q > 0
    e = body~pos('</content>', q)
    out = out self~plain(body~substr(q, e - q))
    q = body~pos('<content type="historynote">', e)
  end
  return out~space

/* Text of a fragment: <no>x</no> starts a new line "x ", the heading and attribute blocks dropped, tags
   dropped, entities decoded. */
::method render private
  use strict arg frag
  out = ''; i = 1; len = frag~length; first = .true
  do while i <= len
    ch = frag~substr(i, 1)
    if ch \== '<' then do
      if ch \== '0a'x & ch \== '0d'x then out = out || ch; else out = out || ' '
      i += 1; iterate
    end
    close = frag~pos('>', i)
    tag = frag~substr(i + 1, close - i - 1)
    name = tag~word(1)
    select
      when name == 'parentattributes' | name == 'heading' then i = frag~pos('</' || name || '>', close) + name~length + 3
      when name == 'content' & tag~pos('historynote') > 0 then i = frag~pos('</content>', close) + 10
      when name == 'no' then do
        e = frag~pos('</no>', close)
        num = frag~substr(close + 1, e - close - 1)~strip
        if first then out = out || num || ' '
        else out = out || '0a'x || num || ' '
        first = .false
        i = e + 5
      end
      otherwise i = close + 1
    end
  end
  lines = .array~new
  do ln over self~decode(out)~makeArray('0a'x)
    if ln~space \== '' then lines~append(ln~space)
  end
  return lines~makeString('L', '0a'x)

::method closeOf private
  use strict arg text, p, name
  depth = 0; i = p
  do forever
    o = text~pos('<' || name, i)
    c = text~pos('</' || name || '>', i)
    if c = 0 then return text~length + 1
    if o > 0 & o < c then do
      nx = text~substr(o + name~length + 1, 1)
      if nx == ' ' | nx == '>' then depth += 1
      i = o + 1
      iterate
    end
    depth -= 1
    if depth = 0 then return c
    i = c + 1
  end

::method plain private
  use strict arg frag
  out = ''; i = 1
  do while i <= frag~length
    ch = frag~substr(i, 1)
    if ch == '<' then do
      i = frag~pos('>', i) + 1
      if i = 1 then leave
      out = out || ' '
      iterate
    end
    out = out || ch; i += 1
  end
  return self~decode(out)~space

::method decode private
  use strict arg t
  t = t~changeStr('&amp;', '&')~changeStr('&lt;', '<')~changeStr('&gt;', '>')~changeStr('&quot;', '"')
  t = t~changeStr('&#8212;', '—')~changeStr('&#8211;', '-')~changeStr('&#8217;', '''')~changeStr('&#8220;', '"')~changeStr('&#8221;', '"')
  return t
