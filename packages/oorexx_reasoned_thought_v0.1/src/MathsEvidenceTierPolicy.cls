/*
 * Optional cross-pillar conformance adapter: Reasoned Thought -> ooRexx Maths.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6.
 *
 * This object does NOT decide evidence meaning, admissibility, binding, warrants,
 * SUPPORT/REBUT/UNDERCUT, assertion floors, settlement or truth.  It only maps
 * Reasoned Thought's declared evidence labels onto a generic finite chain and
 * can detect rank drift between the two packages.
 */
::class MathsEvidenceTierPolicy public

::method init
  expose chain
  chain=.Maths~finiteChain(.array~of('STYLOMETRIC','TESTIMONY','DOCUMENTARY','PROVENANCE'))

::method chain
  expose chain
  return chain

::method rank
  expose chain
  use strict arg label
  return chain~rank(label~upper)

::method compare
  expose chain
  use strict arg left,right
  return chain~compare(left~upper,right~upper)

::method max
  expose chain
  use strict arg left,right
  return chain~max(left~upper,right~upper)

::method min
  expose chain
  use strict arg left,right
  return chain~min(left~upper,right~upper)

::method verifyEvidenceClasses
  expose chain
  report=.directory~new
  mismatches=.array~new
  values=chain~values
  do label over values
    expected=chain~rank(label)
    observed=.EvidenceClass~of(label)~rank
    if observed\=expected then do
      d=.directory~new
      d['label']=label
      d['mathsRank']=expected
      d['reasonedThoughtRank']=observed
      mismatches~append(d)
    end
  end
  report['ok']=(mismatches~items=0)
  report['mismatches']=mismatches
  report['chain']=chain~canonical
  report['scope']='ORDER_CONFORMANCE_ONLY'
  report['semanticAuthority']='REASONED_THOUGHT'
  report['mathAuthority']='OO REXX MATHS'
  return report

::requires 'ReasonedThought.cls'
::requires 'MathsBootstrap.cls'
