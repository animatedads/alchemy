/* SlamLegislation.cls - read a legislation.gov.uk XML file (CLML) and give the text of a section as it
 * stands in one extent.  Pure ooRexx: a scanner for the few elements needed, no XML library.
 *
 * Architecture: Tom Dyer ("use the xml version").  Code: Claude (Opus 5.5), 2026-10-29.
 *
 * What the XML gives, and what it does not:
 *   - a provision's extent is an attribute: <P1group RestrictExtent="E+W+N.I.">; a group without one takes
 *     its enclosing block's (s.3ZA has none of its own: it extends as its crossheading does, E+W+S+N.I.)
 *   - an amendment is markup with a stable id: <Addition CommentaryRef="c19758821">, unlike the F1, F15
 *     footnote numbers of the web pages, which change with the page the text was copied from
 *   - but an inserted phrase's OWN extent is only in its commentary's words: "Words in s. 1(1)(a) inserted
 *     (S.) ...".  So that is read from the commentary the markup points to, by the same rule as before:
 *     a note limited to (S.) is Scotland's, one limited to (E.W.N.I.) is England, Wales and Northern
 *     Ireland's, a note saying neither stands in both.
 * Extent names: E.W. (England and Wales) or S. (Scotland); N.I. also works.
 */
::class SlamLegislation public
::attribute xml get
::attribute notes get
::method init
  expose xml notes
  use strict arg path
  s = .stream~new(path); s~open('READ'); xml = s~charin(1, s~chars); s~close
  notes = .directory~new
  p = xml~pos('<Commentary ')
  do while p > 0
    e = xml~pos('</Commentary>', p)
    if e = 0 then leave
    chunk = xml~substr(p, e - p)
    parse var chunk . 'id="' cid '"' .
    notes[cid] = self~plain(chunk)
    p = xml~pos('<Commentary ', e)
  end

/* The text of section N (P1 id="section-N") in EXTENT, one line per numbered paragraph, or '' when the
   section does not extend there. */
::method section
  expose xml
  use strict arg n, extent
  start = xml~pos('id="section-' || n || '"')
  if start = 0 then return ''
  p1 = xml~lastPos('<P1 ', start)
  ext = ''
  do tagName over .array~of('<P1group', '<Pblock', '<Part', '<Body')     /* nearest one that says */
    g = xml~lastPos(tagName, p1)
    if g = 0 then iterate
    head = xml~substr(g, xml~pos('>', g) - g)
    parse var head . 'RestrictExtent="' ext '"' .
    if ext \== '' then leave
  end
  if ext \== '' & \self~inExtent(ext, extent) then return ''
  body = xml~substr(p1, self~closeOf(xml, p1, 'P1') - p1)
  return self~render(body, extent)

/* Text of a fragment in EXTENT: tags dropped, <Pnumber>x</Pnumber> as a new line "(x) ", additions and
   substitutions kept or dropped by their commentary, entities decoded. */
::method render private
  expose notes
  use strict arg frag, extent
  out = ''; i = 1; len = frag~length; first = .true
  do while i <= len
    ch = frag~substr(i, 1)
    if ch \== '<' then do
      out = out || ch; i += 1; iterate
    end
    close = frag~pos('>', i)
    tag = frag~substr(i + 1, close - i - 1)
    name = tag~word(1)
    select
      when name == 'Pnumber' then do
        e = frag~pos('</Pnumber>', close)
        num = self~render(frag~substr(close + 1, e - close - 1), extent)~strip
        if first then out = out || '(' || num || ') '
        else out = out || '0a'x || '(' || num || ') '
        first = .false
        i = e + 10
      end
      when name == 'Addition' | name == 'Substitution' then do
        e = self~closeOf(frag, i, name)
        parse var tag . 'CommentaryRef="' ref '"' .
        inner = frag~substr(close + 1, e - close - 1)
        keep = .true
        if notes~hasIndex(ref) then keep = self~applies(notes[ref], extent)
        if keep then out = out || self~render(inner, extent)
        i = e + name~length + 3
      end
      when name == 'Commentary' | name == 'CommentaryRef' then do
        if tag~right(1) == '/' then i = close + 1
        else i = self~closeOf(frag, i, name) + name~length + 3
      end
      otherwise i = close + 1
    end
  end
  return self~decode(out)~translate(' ', '09'x)

/* Position of the </NAME> that closes the <NAME ...> at P (nesting counted). */
::method closeOf private
  use strict arg text, p, name
  depth = 0; i = p
  do forever
    o = text~pos('<' || name, i)
    c = text~pos('</' || name || '>', i)
    if c = 0 then return text~length + 1
    /* an opening tag only if followed by a blank or > (so <P1 is not <P1group) */
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

::method inExtent private
  use strict arg restrict, extent
  have = restrict~translate(' ', '+')
  e = extent~upper
  if e~pos('S') > 0 & e~pos('E') = 0 then return wordpos('S', have) > 0
  if e~pos('N.I') > 0 & e~pos('E') = 0 then return wordpos('N.I.', have) > 0
  return wordpos('E', have) > 0 & wordpos('W', have) > 0

::method applies private
  use strict arg note, extent
  ew = extent~upper~pos('E') > 0
  if note~pos('(S.)') > 0 then do
    if note~pos('repealed for E.W.N.I.') > 0 | note~pos('(E.W.N.I.)') = 0 then return \ew
  end
  if note~pos('(E.W.N.I.)') > 0 then return ew
  return .true

::method plain private
  use strict arg frag
  out = ''; i = 1
  do while i <= frag~length
    ch = frag~substr(i, 1)
    if ch == '<' then do
      i = frag~pos('>', i) + 1
      if i = 1 then leave
      iterate
    end
    out = out || ch; i += 1
  end
  return self~decode(out)~space

::method decode private
  use strict arg t
  t = t~changeStr('&amp;', '&')~changeStr('&lt;', '<')~changeStr('&gt;', '>')~changeStr('&quot;', '"')
  t = t~changeStr('&#8212;', '—')~changeStr('&#8217;', '''')~changeStr('&#8220;', '"')~changeStr('&#8221;', '"')
  return t
