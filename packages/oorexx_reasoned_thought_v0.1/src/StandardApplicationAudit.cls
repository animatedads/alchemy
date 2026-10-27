/*
 * StandardApplicationAudit/0.4: domain-neutral stated-standard consistency operator.
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
  use strict arg id, kind, dimension, required = '', description = '', direction = 'HIGHER_WORSE', requiredBasis = ''
  if id = '' | dimension = '' then raise syntax 93.900 array('EMPTY_STANDARD_ID_OR_DIMENSION')
  if standards~hasIndex(id) then raise syntax 93.900 array('DUPLICATE_STANDARD:' || id)
  if kind \= 'DISQUALIFY' & kind \= 'THRESHOLD' then -
    raise syntax 93.900 array('INVALID_STANDARD_KIND:' || kind)
  if direction \= 'HIGHER_WORSE' & direction \= 'LOWER_WORSE' then -
    raise syntax 93.900 array('INVALID_DIRECTION:' || direction)
  if kind = 'THRESHOLD' | required \= '' then do
    if \datatype(required,'N') then raise syntax 93.900 array('NONNUMERIC_REQUIRED_TIER:' || required)
    if required < 0 then raise syntax 93.900 array('NEGATIVE_REQUIRED_TIER')
  end
  s = .directory~new
  s['kind'] = kind
  s['dimension'] = dimension
  s['required'] = required
  s['description'] = description
  s['direction'] = direction
  if requiredBasis = '' then requiredBasis = 'ASSUMED_EQUIVALENT:' || id
  s['requiredBasis'] = requiredBasis
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
  r['ruleViolations'] = .array~new
  r['ruleConformingCases'] = 0
  r['incomparablePairs'] = .array~new
  r['reasonCodes'] = .array~new
  r['comparablePairs'] = 0
  r['observations'] = apps[standardId]~items
  r['classification'] = 'INDETERMINATE'
  r['conditional'] = .true

  if s['kind'] = 'THRESHOLD' then do
    /* Threshold is a NECESSARY condition for ACCEPTANCE, not sufficient.
     * Rejection above the minimum may have other grounds and is not a rule
     * violation unless a separate sufficient-condition warrant is admitted.
     * Evidence tiers must share the standard's declared metric and basis. */
    unknownCases = 0
    r['ruleBasis'] = s['requiredBasis']
    do a over apps[standardId]
      if a['dimension'] \= s['dimension'] | a['basis'] \= s['requiredBasis'] | \a['valueKnown'] then do
        unknownCases += 1
        iterate
      end
      if a['disposition'] = 'ACCEPTED' & a['value'] < s['required'] then do
        d = .directory~new
        d['chain'] = a['chain']; d['value'] = a['value']
        d['required'] = s['required']; d['actual'] = a['disposition']
        d['reason'] = 'ACCEPTED_BELOW_NECESSARY_THRESHOLD'
        r['ruleViolations']~append(d)
      end
      else r['ruleConformingCases'] += 1
    end
    r['uncomparableCases'] = unknownCases
    if ownMaterial~hasIndex(standardId) then do
      d = ownMaterial[standardId]
      r['selfStandardGap'] = (d['tier'] < s['required'])
    end
    else r['selfStandardGap'] = .nil

    if r['ruleViolations']~items > 0 then do
      r['classification'] = 'STATED_RULE_VIOLATION'
      r['detail'] = 'accepted declared case below stated necessary minimum; input and other grounds unverified'
      r['reasonCodes']~append('ACCEPTED_BELOW_NECESSARY_THRESHOLD')
      if r['selfStandardGap'] == .true then r['reasonCodes']~append('SELF_STANDARD_GAP_IF_COMPARABLE')
      if unknownCases > 0 then r['reasonCodes']~append('OTHER_CASES_NOT_COMPARABLE')
    end
    else if r['selfStandardGap'] == .true then do
      r['classification'] = 'UNMEETABLE_BAR'
      r['detail'] = 'conditional self-standard gap only, not proof that standard is impossible'
      r['reasonCodes']~append('SELF_STANDARD_GAP_IF_COMPARABLE')
      if unknownCases > 0 then r['reasonCodes']~append('OTHER_CASES_NOT_COMPARABLE')
    end
    else if unknownCases > 0 then do
      r['classification'] = 'INDETERMINATE_COMPARABILITY'
      r['detail'] = 'at least one application uses an unbound basis, dimension or measurement'
      r['reasonCodes']~append('THRESHOLD_CASES_NOT_COMPARABLE')
    end
    else if r['selfStandardGap'] == .nil then do
      r['classification'] = 'INSUFFICIENT_SELF_MATERIAL'
      r['detail'] = 'no comparable decision-maker own-material tier recorded'
      r['reasonCodes']~append('NO_SELF_MATERIAL')
    end
    else do
      r['classification'] = 'CONSISTENT_APPLICATION'
      r['detail'] = 'no counterexample in recorded minimum-tier applications; not proof of universal or substantive consistency'
      r['reasonCodes']~append('NO_COUNTEREXAMPLE_IN_DECLARED_SET')
    end
    return r
  end

  /* An explicit DISQUALIFY boundary is a unary rule on EACH case. Pairwise
   * even-handedness alone cannot detect two equally wrong ACCEPTED decisions.
   * Legacy callers omit required and only receive the original pairwise audit.
   * Even with a numeric boundary, these are conditional declared observations;
   * unmodelled exceptions or legitimate extra dimensions require review. */
  list = apps[standardId]
  if s['required'] \= '' then do a over list
    if a['dimension'] \= s['dimension'] | \a['valueKnown'] then iterate
    if s['direction'] = 'HIGHER_WORSE' then shouldReject = (a['value'] >= s['required'])
    else shouldReject = (a['value'] <= s['required'])
    if shouldReject then expected = 'REJECTED'
    else expected = 'ACCEPTED'
    if a['disposition'] \= expected then do
      d = .directory~new
      d['chain'] = a['chain']; d['value'] = a['value']
      d['actual'] = a['disposition']; d['expected'] = expected
      d['boundary'] = s['required']; d['dimension'] = s['dimension']
      d['basis'] = a['basis']
      r['ruleViolations']~append(d)
    end
    else r['ruleConformingCases'] += 1
  end
  if list~items < 2 then do
    if r['ruleViolations']~items > 0 then do
      r['classification'] = 'STATED_RULE_VIOLATION'
      r['detail'] = 'declared application conflicts with explicit stated boundary; underlying standard and exceptions unverified'
      r['reasonCodes']~append('EXPLICIT_BOUNDARY_COUNTEREXAMPLE')
      return r
    end
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
    if r['ruleViolations']~items > 0 then r['reasonCodes']~append('EXPLICIT_BOUNDARY_COUNTEREXAMPLE')
    if notComparable then r['reasonCodes']~append('OTHER_PAIRS_INCOMPARABLE')
  end
  else if r['ruleViolations']~items > 0 then do
    r['classification'] = 'STATED_RULE_VIOLATION'
    r['detail'] = 'one or more declarations contradict the explicit stated cutoff; no merits finding'
    r['reasonCodes']~append('EXPLICIT_BOUNDARY_COUNTEREXAMPLE')
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
