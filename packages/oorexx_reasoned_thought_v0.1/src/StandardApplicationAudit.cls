/*
 * StandardApplicationAudit/0.2: domain-neutral stated-standard consistency operator.
 * Architecture: Tom Dyer. Authoritative policy operator: ChatGPT GPT-6.
 * Reference interface and independent adversarial acceptance fixture: Claude Opus 4.8.
 *
 * Tests whether a decision-maker applied its OWN declared standard uniformly.
 * It does not certify inputs, truth, legal correctness, fairness of the standard,
 * or merit/outcome of an underlying case. Every report has validatedTruth=.false.
 *
 * Important epistemic limits:
 * - Noncomparable measurements cannot prove even-handedness.
 * - A missing measurement is not value zero.
 * - Self material below a demanded threshold is a conditional self-standard gap,
 *   not proof that the threshold is objectively impossible to meet.
 * - Finite consistent applications do not prove universal uniform treatment.
 * - Similar values are comparable only under a declared dimension AND basis.
 */
::class StandardApplicationAudit public

::method init
  expose standards apps ownMaterial
  standards = .directory~new
  apps = .directory~new
  ownMaterial = .directory~new

::method standard
  expose standards apps
  use strict arg id, kind, dimension, required = '', description = '', direction = 'HIGHER_WORSE'
  if id = '' | dimension = '' then raise syntax 93.900 array('EMPTY_STANDARD_ID_OR_DIMENSION')
  if standards~hasIndex(id) then raise syntax 93.900 array('DUPLICATE_STANDARD:' || id)
  if kind \= 'DISQUALIFY' & kind \= 'THRESHOLD' then -
    raise syntax 93.900 array('INVALID_STANDARD_KIND:' || kind)
  if direction \= 'HIGHER_WORSE' & direction \= 'LOWER_WORSE' then -
    raise syntax 93.900 array('INVALID_DIRECTION:' || direction)
  if kind = 'THRESHOLD' then do
    if \datatype(required,'N') then raise syntax 93.900 array('NONNUMERIC_REQUIRED_TIER:' || required)
    if required < 0 then raise syntax 93.900 array('NEGATIVE_REQUIRED_TIER')
  end
  s = .directory~new
  s['kind'] = kind
  s['dimension'] = dimension
  s['required'] = required
  s['description'] = description
  s['direction'] = direction
  standards[id] = s
  apps[id] = .array~new
  return self

::method applied
  /* Optional dimension and measurementBasis keep the original four-arg API.
   * Omitting them asserts (but does not verify!) equivalence of dimension and
   * measurement basis with the declared standard. Such reports are CONDITIONAL.
   * UNKNOWN is an explicit missing value, never zero.
   */
  expose standards apps
  use strict arg standardId, chainId, value, disposition, dimension = '', measurementBasis = ''
  if \standards~hasIndex(standardId) then raise syntax 93.900 array('UNKNOWN_STANDARD:' || standardId)
  if chainId = '' then raise syntax 93.900 array('EMPTY_CHAIN_ID')
  if disposition \= 'ACCEPTED' & disposition \= 'REJECTED' then -
    raise syntax 93.900 array('INVALID_DISPOSITION:' || disposition)
  do entry over apps[standardId]
    if entry['chain'] == chainId then raise syntax 93.900 array('DUPLICATE_CHAIN:' || chainId)
  end
  s = standards[standardId]
  a = .directory~new
  a['chain'] = chainId
  a['value'] = value
  a['disposition'] = disposition
  a['dimensionExplicit'] = (dimension \= '')
  a['basisExplicit'] = (measurementBasis \= '')
  if dimension = '' then dimension = s['dimension']
  if measurementBasis = '' then measurementBasis = 'ASSUMED_EQUIVALENT:' || standardId
  a['dimension'] = dimension
  a['basis'] = measurementBasis
  a['valueKnown'] = datatype(value,'N')
  apps[standardId]~append(a)
  return self

::method selfMaterial
  /* Caller-supplied tier is not verified; comparison presumes the same standard
   * applies to the decision-maker's own material. That presumption is surfaced. */
  expose standards ownMaterial
  use strict arg standardId, tier
  if \standards~hasIndex(standardId) then raise syntax 93.900 array('UNKNOWN_STANDARD:' || standardId)
  if \datatype(tier,'N') then raise syntax 93.900 array('NONNUMERIC_SELF_TIER')
  d = .directory~new
  d['tier'] = tier
  d['sameStandardAssumed'] = .true
  ownMaterial[standardId] = d
  return self

::method audit
  expose standards apps ownMaterial
  use strict arg standardId
  if \standards~hasIndex(standardId) then raise syntax 93.900 array('UNKNOWN_STANDARD:' || standardId)
  s = standards[standardId]
  r = .directory~new
  r['standard'] = standardId
  r['kind'] = s['kind']
  r['dimension'] = s['dimension']
  r['validatedTruth'] = .false
  r['scope'] = 'STANDARD_APPLICATION_CONSISTENCY_ONLY'
  r['evidenceAuthority'] = 'CALLER_DECLARED_NOT_AUTHENTICATED'
  r['universalConsistencyProven'] = .false
  r['pairs'] = .array~new
  r['incomparablePairs'] = .array~new
  r['reasonCodes'] = .array~new
  r['comparablePairs'] = 0
  r['observations'] = apps[standardId]~items
  r['classification'] = 'INDETERMINATE'
  r['conditional'] = .true

  if s['kind'] = 'THRESHOLD' then do
    if \ownMaterial~hasIndex(standardId) then do
      r['classification'] = 'INSUFFICIENT_SELF_MATERIAL'
      r['detail'] = 'the stated threshold exists but no comparable self-material tier was supplied'
      r['reasonCodes']~append('NO_SELF_MATERIAL')
      return r
    end
    d = ownMaterial[standardId]
    if d['tier'] < s['required'] then do
      /* Legacy label retained for Claude's published fixture; semantically this
       * is a conditional SELF-STANDARD GAP, not literal unattainability. */
      r['classification'] = 'UNMEETABLE_BAR'
      r['detail'] = 'conditional self-standard gap: required tier ' || s['required'] || -
        ' exceeds declared own-material tier ' || d['tier'] || -
        '; no finding that this standard is impossible for others'
      r['reasonCodes']~append('SELF_STANDARD_GAP_IF_COMPARABLE')
    end
    else do
      r['classification'] = 'CONSISTENT_APPLICATION'
      r['detail'] = 'declared own-material tier meets the stated threshold; no universal consistency proved'
      r['reasonCodes']~append('SELF_STANDARD_GAP_NOT_FOUND')
    end
    return r
  end

  list = apps[standardId]
  if list~items < 2 then do
    r['classification'] = 'INSUFFICIENT_APPLICATIONS'
    r['detail'] = 'fewer than two applications recorded; cannot compare treatment'
    r['reasonCodes']~append('NO_COMPARATIVE_PAIR')
    return r
  end

  notComparable = .false
  do i = 1 to list~items
    ai = list[i]
    /* Even identical outcomes do not prove consistency where measurement
     * dimensions or bases differ. Enumerate all unordered pairs. */
    do j = i + 1 to list~items
      aj = list[j]
      problem = ''
      if ai['dimension'] \= s['dimension'] | aj['dimension'] \= s['dimension'] then -
        problem = 'DIMENSION_MISMATCH'
      else if ai['dimension'] \= aj['dimension'] then problem = 'DIMENSION_MISMATCH'
      else if ai['basis'] \= aj['basis'] then problem = 'MEASUREMENT_BASIS_MISMATCH'
      else if \ai['valueKnown'] | \aj['valueKnown'] then problem = 'UNKNOWN_OR_NONNUMERIC_VALUE'

      if problem \= '' then do
        notComparable = .true
        bad = .directory~new
        bad['chainA'] = ai['chain']; bad['chainB'] = aj['chain']
        bad['reason'] = problem
        r['incomparablePairs']~append(bad)
        iterate
      end
      r['comparablePairs'] += 1
      if ai['disposition'] = aj['disposition'] then iterate
      if ai['disposition'] = 'REJECTED' then do
        rejected = ai; accepted = aj
      end
      else do
        rejected = aj; accepted = ai
      end
      if s['direction'] = 'HIGHER_WORSE' then violation = accepted['value'] >= rejected['value']
      else violation = accepted['value'] <= rejected['value']
      if violation then do
        d = .directory~new
        d['rejected'] = rejected['chain']
        d['rejectedValue'] = rejected['value']
        d['accepted'] = accepted['chain']
        d['acceptedValue'] = accepted['value']
        d['dimension'] = s['dimension']
        d['basis'] = accepted['basis']
        r['pairs']~append(d)
      end
    end
  end

  if r['pairs']~items > 0 then do
    r['classification'] = 'DISPARATE_TREATMENT'
    r['detail'] = 'at least one comparable declared pair reverses the stated ordering; this is not a merits verdict'
    r['reasonCodes']~append('COMPARABLE_COUNTEREXAMPLE')
    if notComparable then r['reasonCodes']~append('OTHER_PAIRS_INCOMPARABLE')
  end
  else if notComparable then do
    r['classification'] = 'INDETERMINATE_COMPARABILITY'
    r['detail'] = 'no counterexample detected, but some applications lack a comparable dimension, basis, or numeric value'
    r['reasonCodes']~append('INCOMPLETE_COMPARABILITY')
  end
  else do
    r['classification'] = 'CONSISTENT_APPLICATION'
    r['detail'] = 'no ordering reversal in the finite declared comparison set; other chains and truth not established'
    r['reasonCodes']~append('NO_COUNTEREXAMPLE_IN_DECLARED_SET')
  end
  return r