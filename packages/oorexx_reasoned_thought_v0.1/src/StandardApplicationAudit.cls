/*
 * StandardApplicationAudit v0.1 -- disparate-treatment / even-handedness probe.
 * Requirement #5 from Sonnet 5's design review: given one STATED standard and its
 * application to two or more argument chains, did the decision-maker apply their OWN
 * stated standard identically? This is a question about internal consistency of
 * reasoning - NOT about whether any underlying claim is true.
 *
 * SCOPE CEILING (Sonnet #4): this class never emits a verdict on the underlying
 * question. No "credible", no "should succeed", no probability. Output is a
 * structural finding about even-handedness only; validatedTruth is always .false.
 *
 * ---- LANE NOTE ----
 * This is a STRAWMAN REFERENCE in ChatGPT's policy/combiner lane, seeded (as the
 * original OrdinalEvidenceCombiner was) so we agree on running code, not prose.
 * ChatGPT (GPT-6) owns the authoritative operator and may replace this file; the
 * adversarial fixture (tests/test_standard_application_audit.rex) is Claude's and
 * is meant to try to BREAK whatever implementation lands here.
 *
 * Architecture: Tom Dyer. Reference: Claude (Opus 4.8). Pure ooRexx 5.3.
 */
::class StandardApplicationAudit public

::method init
  expose standards apps selfTier
  standards = .directory~new   /* id -> directory(kind, dimension, required, description) */
  apps = .directory~new        /* id -> array of application directories */
  selfTier = .directory~new    /* id -> numeric tier the decision-maker's OWN material reaches */

::method standard
  /* kind = 'DISQUALIFY' (a feature value at/above a peer's triggers rejection) or
   *        'THRESHOLD'  (a minimum evidence tier the standard demands) */
  expose standards apps
  use strict arg id, kind, dimension, required = "", description = ""
  if kind \= 'DISQUALIFY' & kind \= 'THRESHOLD' then -
    raise syntax 93.900 array('INVALID_STANDARD_KIND:' || kind)
  if standards~hasIndex(id) then raise syntax 93.900 array('DUPLICATE_STANDARD:' || id)
  s = .directory~new
  s['kind'] = kind; s['dimension'] = dimension; s['required'] = required; s['description'] = description
  standards[id] = s
  apps[id] = .array~new
  return self

::method applied
  /* record how the standard was applied to one chain:
   *   value      = the chain's measured value on the standard's dimension (numeric)
   *   disposition= 'ACCEPTED' or 'REJECTED' (how the decision-maker treated that chain) */
  expose standards apps
  use strict arg standardId, chainId, value, disposition
  if \standards~hasIndex(standardId) then raise syntax 93.900 array('UNKNOWN_STANDARD:' || standardId)
  if disposition \= 'ACCEPTED' & disposition \= 'REJECTED' then -
    raise syntax 93.900 array('INVALID_DISPOSITION:' || disposition)
  a = .directory~new
  a['chain'] = chainId; a['value'] = value; a['disposition'] = disposition
  apps[standardId]~append(a)
  return self

::method selfMaterial
  /* the best evidence tier the decision-maker's OWN accepted material reaches -
   * used to detect a bar set higher than the decision-maker can itself meet. */
  expose selfTier
  use strict arg standardId, tier
  selfTier[standardId] = tier
  return self

::method audit
  expose standards apps selfTier
  use strict arg standardId
  if \standards~hasIndex(standardId) then raise syntax 93.900 array('UNKNOWN_STANDARD:' || standardId)
  s = standards[standardId]
  r = .directory~new
  r['standard'] = standardId
  r['validatedTruth'] = .false
  r['scope'] = 'STANDARD_APPLICATION_CONSISTENCY_ONLY'
  r['pairs'] = .array~new

  if s['kind'] = 'THRESHOLD' then do
    if selfTier~hasIndex(standardId), selfTier[standardId] < s['required'] then do
      r['classification'] = 'UNMEETABLE_BAR'
      r['detail'] = 'required tier ' || s['required'] || -
        ' exceeds the decision-maker''s own material tier ' || selfTier[standardId]
    end
    else r['classification'] = 'CONSISTENT_APPLICATION'
    return r
  end

  /* DISQUALIFY: disparate iff a chain with an EQUAL-OR-GREATER problem value was
   * ACCEPTED while a chain with an EQUAL-OR-LESSER value was REJECTED. A larger
   * problem value justifying rejection is NOT disparate - the standard bit evenly. */
  list = apps[standardId]
  do i = 1 to list~items
    ai = list[i]
    if ai['disposition'] \= 'REJECTED' then iterate
    do j = 1 to list~items
      if j = i then iterate
      aj = list[j]
      if aj['disposition'] \= 'ACCEPTED' then iterate
      if aj['value'] >= ai['value'] then do
        d = .directory~new
        d['rejected'] = ai['chain']; d['rejectedValue'] = ai['value']
        d['accepted'] = aj['chain']; d['acceptedValue'] = aj['value']
        r['pairs']~append(d)
      end
    end
  end
  if r['pairs']~items > 0 then r['classification'] = 'DISPARATE_TREATMENT'
  else r['classification'] = 'CONSISTENT_APPLICATION'
  return r
