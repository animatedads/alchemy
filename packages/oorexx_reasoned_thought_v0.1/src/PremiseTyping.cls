/*
 * PremiseTyping v0.1 -- descriptive / normative / definitional clause typing.
 * Requirement #3 from Sonnet 5's design review: every clause is forced into
 * {DESCRIPTIVE | NORMATIVE | DEFINITIONAL}. The "fudge" lives in the unmarked seam
 * between an is-claim and an ought-claim stated in one breath; typing the clauses
 * makes the seam a finding instead of a smooth sentence.
 *
 * Two structural checks, both under the scope ceiling (never a verdict on truth):
 *   IS_OUGHT_GAP   - a NORMATIVE conclusion drawn from premises with no NORMATIVE
 *                    premise (Hume's guillotine: no ought from is alone).
 *   OUGHT_IS_GAP   - a DESCRIPTIVE conclusion resting only on NORMATIVE premises
 *                    (no fact from values alone).
 * Plus the thick-concept handling (Claude's refinement of #3): a clause that is
 * irreducibly descriptive AND normative - "credible", "cruel" - is typed THICK and
 * must be DECOMPOSED into its parts before use, NOT rewritten away. Using a THICK
 * clause whole is UNTAGGABLE_PREMISE. This is what lets #5 test even-handedness on
 * the descriptive part (was inconsistency measured evenly?) separately from the
 * normative part (was the standard set evenly?).
 *
 * Architecture: Tom Dyer. Coding: Claude (Opus 4.8). Pure ooRexx 5.3. No deps.
 */
::class ArgumentTyping public

::method init
  expose clauses args
  clauses = .directory~new
  args = .directory~new

::method clause
  expose clauses
  use strict arg id, text, type
  if \self~validType(type) then raise syntax 93.900 array('INVALID_CLAUSE_TYPE:' || type)
  if clauses~hasIndex(id) then raise syntax 93.900 array('DUPLICATE_CLAUSE:' || id)
  c = .directory~new
  c['id'] = id; c['text'] = text; c['type'] = type
  c['decomposed'] = .false; c['parts'] = .array~new
  clauses[id] = c
  return self

::method decompose
  /* split a THICK clause into a DESCRIPTIVE part and a NORMATIVE part (new clauses).
   * The thick clause is marked decomposed; its PARTS are what later arguments cite. */
  expose clauses
  use strict arg thickId, descId, descText, normId, normText
  if \clauses~hasIndex(thickId) then raise syntax 93.900 array('UNKNOWN_CLAUSE:' || thickId)
  if clauses[thickId]['type'] \= 'THICK' then -
    raise syntax 93.900 array('ONLY_THICK_CLAUSES_DECOMPOSE:' || thickId)
  self~clause(descId, descText, 'DESCRIPTIVE')
  self~clause(normId, normText, 'NORMATIVE')
  clauses[thickId]['decomposed'] = .true
  clauses[thickId]['parts'] = .array~of(descId, normId)
  return self

::method argument
  expose args
  use strict arg argId
  if args~hasIndex(argId) then raise syntax 93.900 array('DUPLICATE_ARGUMENT:' || argId)
  a = .directory~new; a['premises'] = .array~new; a['conclusion'] = ''
  args[argId] = a
  return self

::method premise
  expose args clauses
  use strict arg argId, clauseId
  if \args~hasIndex(argId) | \clauses~hasIndex(clauseId) then -
    raise syntax 93.900 array('UNKNOWN_ARGUMENT_OR_CLAUSE')
  args[argId]['premises']~append(clauseId)
  return self

::method conclusion
  expose args clauses
  use strict arg argId, clauseId
  if \args~hasIndex(argId) | \clauses~hasIndex(clauseId) then -
    raise syntax 93.900 array('UNKNOWN_ARGUMENT_OR_CLAUSE')
  args[argId]['conclusion'] = clauseId
  return self

::method audit
  expose args clauses
  use strict arg argId
  if \args~hasIndex(argId) then raise syntax 93.900 array('UNKNOWN_ARGUMENT:' || argId)
  a = args[argId]
  r = .directory~new
  r['argument'] = argId
  r['validatedTruth'] = .false      /* typing never establishes the conclusion is true */
  r['scope'] = 'ARGUMENT_TYPING_ONLY'
  r['untaggable'] = .array~new

  /* a THICK clause used whole (premise or conclusion) is untaggable: decompose first */
  cids = .array~new
  do p over a['premises']; cids~append(p); end
  if a['conclusion'] \= '' then cids~append(a['conclusion'])
  do cid over cids
    if clauses[cid]['type'] = 'THICK' then r['untaggable']~append(cid)
  end
  if r['untaggable']~items > 0 then do
    r['classification'] = 'UNTAGGABLE_PREMISE'
    r['detail'] = 'a thick (descriptive+normative) clause is used whole; decompose into typed parts first'
    return r
  end

  hasNorm = .false; hasDesc = .false; hasDef = .false
  do p over a['premises']
    select
      when clauses[p]['type'] = 'NORMATIVE' then hasNorm = .true
      when clauses[p]['type'] = 'DESCRIPTIVE' then hasDesc = .true
      when clauses[p]['type'] = 'DEFINITIONAL' then hasDef = .true
      otherwise nop
    end
  end
  ctype = clauses[a['conclusion']]['type']
  select
    when ctype = 'NORMATIVE' then do
      if hasNorm then r['classification'] = 'WELL_TYPED'
      else do
        r['classification'] = 'IS_OUGHT_GAP'
        r['detail'] = 'normative conclusion with no normative premise - no ought from is alone'
      end
    end
    when ctype = 'DESCRIPTIVE' then do
      if hasDesc then r['classification'] = 'WELL_TYPED'
      else do
        r['classification'] = 'OUGHT_IS_GAP'
        r['detail'] = 'descriptive conclusion resting only on normative premises - no fact from values alone'
      end
    end
    otherwise do   /* DEFINITIONAL conclusion */
      if hasDef then r['classification'] = 'WELL_TYPED'
      else do
        r['classification'] = 'UNWARRANTED_DEFINITION'
        r['detail'] = 'definitional conclusion with no definitional/stipulative premise'
      end
    end
  end
  return r

::method validType private
  use strict arg t
  return t = 'DESCRIPTIVE' | t = 'NORMATIVE' | t = 'DEFINITIONAL' | t = 'THICK'
