/*
 * LegalEffectStructuredRelationBridge.cls
 *
 * Companion bridge which wraps Structured Relation RichBusinessFact sources
 * in HardWorld RichEvidenceValue objects before placing them in LegalFactSet.
 * This keeps the native source object reachable while giving Legal Effect
 * evaluation/promotion a deterministic canonical provenance contract.
 */

::class LegalEffectStructuredRelationBridge public

::method factSetFrom class
  use arg richFacts, consistencyGrade = 'FROZEN_OBSERVATION', consistencyHash = ''
  legalFacts = .LegalFactSet~new
  do richFact over richFacts
    richEvidence = .StructuredRelationRichEvidenceAdapter~adaptFact(richFact, consistencyGrade, consistencyHash)
    name = richFact~name
    state = richFact~state~string~upper
    value = .nil
    if richFact~hasMethod('VALUE') then value = richFact~value
    select
      when state == 'KNOWN' then ignored = legalFacts~putKnown(name, value, richEvidence, 'STRUCTURED_RELATION/RICH_EVIDENCE')
      when state == 'PRESENT' then ignored = legalFacts~putKnown(name, value, richEvidence, 'STRUCTURED_RELATION/RICH_EVIDENCE')
      when state == 'PRESENT_EMPTY' then ignored = legalFacts~putKnown(name, value, richEvidence, 'STRUCTURED_RELATION/RICH_EVIDENCE')
      when state == 'UNKNOWN' then ignored = legalFacts~putUnknown(name, richEvidence, 'STRUCTURED_RELATION/RICH_EVIDENCE')
      when state == 'CONFLICT' then ignored = legalFacts~putConflict(name, richEvidence, 'STRUCTURED_RELATION/RICH_EVIDENCE')
      otherwise raise syntax 93.900 additional('Unsupported Structured Relation fact state for Legal Effect:' state)
    end
  end
  return legalFacts

::method conflictFactSet class
  use arg factName, richEvidence
  legalFacts = .LegalFactSet~new
  ignored = legalFacts~putConflict(factName, richEvidence, 'STRUCTURED_RELATION/RICH_EVIDENCE')
  return legalFacts

::requires 'LegalEffect.cls'
::requires 'StructuredRelationRichEvidenceAdapter.cls'
