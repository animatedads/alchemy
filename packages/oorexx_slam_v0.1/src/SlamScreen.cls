/* SlamScreen.cls - one set of events, screened against many offences.
 *
 * Architecture: Tom Dyer ("take a set of consistently named events and evidence points, and run it against
 * a plethora of potential offences").  Case schema (offence-event, JSON) and the per-person, per-element
 * report: ChatGPT (GPT-6), OFFENCE_EVENT_CONTRACT_v0.1.  Code: Claude (Opus 5.5), 2026-10-30.  The Reasoned
 * Thought engine (Claude (Opus 4.8); combiner design ChatGPT (GPT-6)) is used unchanged, through SlamLaw.
 *
 * The case is entered once.  Each rule pack says which kinds of event its offence can be about ("it is
 * about an event of kind:"); the screen runs the rule once for each such event and each person the
 * evidence names for it (UNRESOLVED when none: "they" is never filled in).  An event reported as a series,
 * with recorded parts (partOf), is screened through its parts.  Evidence reaches an element when the kind
 * it is offered for, or the kind it binds, is one the element takes (before guidance, so that what guidance
 * refuses is refused on the record, with the guidance quoted).  Evidence about the screened event, or
 * about an event this rule does not screen (a death, a message), or about every event ("*"), applies;
 * evidence about another screened event does not.  Evidence with a subject applies only to that person.
 *
 * What comes out, per rule, extent, event and person: each element's status, and the gaps (what is
 * missing, and what would count).  Not a verdict, not a charge.  The report's statuses (ChatGPT's set):
 * SUPPORTED, CONTRADICTED, UNKNOWN, OUT_OF_SCOPE, plus DISPUTED (testimony against testimony is neither).
 */
::requires 'SlamLaw.cls'
::requires 'json.cls'

::class SlamScreen public

/* CASE and EVIDENCE: Directories (json.cls) of a case file and of an evidence file (or .nil).  RULES: an
   Array of rule file paths.  EXTENT: E.W. or S.  GUIDANCE: an Array of .array(path, text), or .nil.
   VALIDFROM: a Directory, rule id -> the date its official text is valid from, or .nil.  Returns an Array of
   result Directories (see result). */
::method screen class
  use strict arg case, evidence, rules, extent, guidance = .nil, validFrom = .nil
  if guidance == .nil then guidance = .array~new
  events = .directory~new; order = .array~new
  do e over case['events']; events[e['eventId']] = e; order~append(e['eventId']); end
  items = .array~new; tags = .array~new
  if evidence \== .nil then do
    if evidence~hasIndex('events') then do e over evidence['events']; events[e['eventId']] = e; order~append(e['eventId']); end
    if evidence~hasIndex('evidenceItems') then items = evidence['evidenceItems']
    if evidence~hasIndex('tags') then tags = evidence['tags']
  end
  hasParts = .set~new
  do id over order
    if events[id]~hasIndex('partOf') then hasParts~put(events[id]['partOf'])
  end
  r = .SlamReasoning~new
  results = .array~new
  parsed = .array~new
  do path over rules
    rule = .SlamLaw~parse(path)
    if wordpos(extent, rule['EXTENT']) = 0 then do
      results~append(self~outOfScope(rule, path, extent))
      iterate
    end
    parsed~append(.array~of(path, rule))
  end
  /* rules that are elements of others are built first */
  built = .directory~new
  do pass = 1 to 2
    do pr over parsed
      path = pr[1]; rule = pr[2]
      linked = .false
      do el over rule['ELEMENTS']; if el['LINK'] \== '' then linked = .true; end
      if (pass = 1) = linked then iterate
      screened = .set~new
      do id over order
        if rule['ABOUT']~hasItem(events[id]['eventType']) & \hasParts~hasItem(id) then screened~put(id)
      end
      do id over order
        if \screened~hasItem(id) then iterate
        persons = .array~new
        do it over items
          if it['eventId'] == id & self~field(it, 'subject') \== '' then
            if \persons~hasItem(it['subject']) then persons~append(it['subject'])
        end
        if persons~items = 0 then persons~append('UNRESOLVED')
        do who over persons
          rp = .SlamLaw~parse(path)
          rp['EXTENT'] = extent
          do g over guidance
            ge = .SlamLaw~applyGuidance(rp, g[1], g[2], tags)    /* refused guidance changes nothing */
          end
          rp['KEY'] = rp['ID'] || '/' || extent || '@' || id || '#' || who
          links = .directory~new
          do el over rp['ELEMENTS']
            if el['LINK'] \== '' then do
              lk = el['LINK'] || '/' || extent || '@' || id || '#' || who
              if built~hasIndex(lk) then links[el['LINK']] = built[lk]
            end
          end
          ignored = .SlamLaw~build(r, rp, links)
          do it over items
            if \self~reaches(it, id, who, screened) then iterate
            do el over rp['ELEMENTS']
              if el['LINK'] \== '' then iterate
              ex = .false
              if el~hasIndex('EXCLUDES') then ex = el['EXCLUDES']~hasIndex(it['binding'])
              if el['TAKES0']~hasItem(it['offeredFor']) | el['TAKES0']~hasItem(it['binding']) | ex then do
                cid = .SlamLaw~elementId(rp, el['ID'])
                note = it['evidenceId'] || ':' it['text']
                if it['effect'] == 'REBUT' then r~evidenceAgainst(cid, it['tier'], note, it['binding'])
                else r~evidenceFor(cid, it['tier'], note, it['binding'])
              end
            end
          end
          built[rp['ID'] || '/' || extent || '@' || id || '#' || who] = rp
          results~append(self~result(r, rp, path, extent, events[id], who, links, validFrom))
        end
      end
    end
  end
  return results

/* Does evidence item IT reach the instance for event ID and person WHO? */
::method reaches class private
  use strict arg it, id, who, screened
  ev = it['eventId']
  if ev \== id & ev \== '*' & screened~hasItem(ev) then return .false
  sub = self~field(it, 'subject')
  if sub \== '' & sub \== who then return .false
  return .true

::method field class private
  use strict arg d, name
  if d~hasIndex(name) then return d[name]
  return ''

/* One result: RULE FILE EXTENT EVENT EVENTTYPE PERSON KEY OK STATUS ELEMENTS (Array of Directories: ELEMENT,
   STATUS (the engine's), REPORT (the report's)) GAPS ASAT (IN_FORCE_TEXT: the event is on or after the
   date the text is valid from; EARLIER_TEXT_NEEDED: before it; NOT_RUN: the event has no date). */
::method result class private
  use strict arg r, rule, path, extent, event, who, links, validFrom
  out = .directory~new
  out['RULE'] = rule['ID']; out['FILE'] = path~substr(path~lastPos('/') + 1); out['EXTENT'] = extent
  out['EVENT'] = event['eventId']; out['EVENTTYPE'] = event['eventType']; out['PERSON'] = who; out['KEY'] = rule['KEY']
  m = r~mayAct(.SlamLaw~decisionId(rule))
  out['OK'] = m['OK']; out['WHY'] = m['WHY']
  if m['OK'] then out['STATUS'] = 'SUPPORTED'; else out['STATUS'] = 'NOT_SUPPORTED'
  els = .array~new
  do el over rule['ELEMENTS']
    e = .directory~new; e['ELEMENT'] = el['ID']
    if el['LINK'] \== '' then do
      st = 'NO_RULE_PACK'
      if links~hasIndex(el['LINK']) then do
        if r~mayAct(.SlamLaw~decisionId(links[el['LINK']]))['OK'] then st = 'OFFENCE_SUPPORTED'; else st = 'OFFENCE_NOT_SUPPORTED'
      end
      e['STATUS'] = st
      if st == 'OFFENCE_SUPPORTED' then e['REPORT'] = 'SUPPORTED'; else e['REPORT'] = 'UNKNOWN'
    end
    else do
      e['STATUS'] = r~assess(.SlamLaw~elementId(rule, el['ID']))['status']
      e['REPORT'] = self~report(e['STATUS'])
    end
    els~append(e)
  end
  out['ELEMENTS'] = els
  out['GAPS'] = .SlamLaw~gaps(r, rule, links)
  out['ASAT'] = 'NOT_RUN'
  when = ''
  if event~hasIndex('time') then if event['time']~hasIndex('value') then when = event['time']['value']
  vf = ''
  if validFrom \== .nil then if validFrom~hasIndex(rule['ID']) then vf = validFrom[rule['ID']]
  if when \== '' & vf \== '' then do
    if when >= vf then out['ASAT'] = 'IN_FORCE_TEXT'; else out['ASAT'] = 'EARLIER_TEXT_NEEDED'
  end
  return out

::method outOfScope class private
  use strict arg rule, path, extent
  out = .directory~new
  out['RULE'] = rule['ID']; out['FILE'] = path~substr(path~lastPos('/') + 1); out['EXTENT'] = extent
  out['EVENT'] = ''; out['EVENTTYPE'] = ''; out['PERSON'] = ''; out['KEY'] = ''
  out['OK'] = .false; out['STATUS'] = 'OUT_OF_SCOPE'
  out['WHY'] = 'the rule''s text is for' rule['EXTENT'] || ', not' extent
  out['ELEMENTS'] = .array~new; out['GAPS'] = .array~new; out['ASAT'] = 'NOT_RUN'
  return out

/* The engine's statuses, in the report's set.  DISPUTED stays DISPUTED. */
::method report class
  use strict arg status
  select
    when status == 'SETTLED' | status == 'SUPPORTED' then return 'SUPPORTED'
    when status == 'REBUTTED' then return 'CONTRADICTED'
    when status == 'DISPUTED' then return 'DISPUTED'
    otherwise return 'UNKNOWN'
  end

/* One line per result, for a person to read. */
::method line class
  use strict arg res
  if res['STATUS'] == 'OUT_OF_SCOPE' then return res['RULE'] res['EXTENT'] '(' || res['FILE'] || '): OUT_OF_SCOPE:' res['WHY']
  t = res['RULE'] res['EXTENT'] res['EVENT'] res['PERSON']~left(10) || ':'
  do e over res['ELEMENTS']; t = t e['ELEMENT'] || '=' || e['REPORT']; end
  return t '->' res['STATUS'] '(as-at:' res['ASAT'] || ')'
