/* Architecture Intentions — NotNotes document publication request /0.1.
 * A frozen, transport-neutral object proposal. NotNotes alone can accept it
 * as a document revision; this class has NO NotNotes mutation authority.
 * An SSC verification is evidence, not publication approval.
 */
::requires 'ArchitectureSscReceipt.cls'

::class ArchitectureNotNotesPublication public
::attribute state get

::method init
  expose handoffJSON sscJSON state
  use strict arg promotionHandoff, sscEvidence = .nil
  if \promotionHandoff~isA(.Directory) then -
    raise syntax 93.900 array('ARCH_NOTNOTES_HANDOFF_SHAPE')
  if promotionHandoff['schema'] \== 'alchemy.architecture.promotion-handoff/0.1' then -
    raise syntax 93.900 array('ARCH_NOTNOTES_HANDOFF_SCHEMA')
  if promotionHandoff['projectId'] == .nil | promotionHandoff['scenarioId'] == .nil then -
    raise syntax 93.900 array('ARCH_NOTNOTES_ID_MISSING')
  if promotionHandoff['executable'] \== .JSON~false then -
    raise syntax 93.900 array('ARCH_NOTNOTES_EXECUTION_CLAIM')
  handoffJSON = .JSON~toJSON(promotionHandoff)
  sscJSON = ''
  if sscEvidence \== .nil then do
    if \sscEvidence~isA(.Directory) then -
      raise syntax 93.900 array('ARCH_NOTNOTES_SSC_SHAPE')
    if sscEvidence['schema'] \== 'alchemy.architecture.ssc-qualification/0.1' then -
      raise syntax 93.900 array('ARCH_NOTNOTES_SSC_SCHEMA')
    if sscEvidence['projectId'] \== promotionHandoff['projectId'] | -
       sscEvidence['scenarioId'] \== promotionHandoff['scenarioId'] then -
      raise syntax 93.900 array('ARCH_NOTNOTES_SSC_TARGET_MISMATCH')
    if sscEvidence['executable'] \== .JSON~false then -
      raise syntax 93.900 array('ARCH_NOTNOTES_SSC_EXECUTION_CLAIM')
    sscJSON = .JSON~toJSON(sscEvidence)
  end
  state = 'PUBLICATION_REQUEST_ONLY'

::method projection
  expose handoffJSON sscJSON state
  handoff = .JSON~fromJSON(handoffJSON)
  p = .Directory~new
  p['schema'] = 'alchemy.architecture.notnotes-publication-request/0.1'
  p['projectId'] = handoff['projectId']
  p['scenarioId'] = handoff['scenarioId']
  p['documentKind'] = 'ARCHITECTURE_REVIEW'
  p['owner'] = 'ALCHEMY_NOTNOTES'
  p['status'] = state
  p['body'] = handoff
  p['sscEvidence'] = .nil
  if sscJSON \== '' then p['sscEvidence'] = .JSON~fromJSON(sscJSON)
  p['expectedDocumentRevision'] = .nil
  p['documentId'] = .nil
  p['requiresNotNotesPolicyAndRevisionCheck'] = .JSON~true
  p['executable'] = .JSON~false
  p['activationRequested'] = .JSON~false
  p['publicationReceipt'] = .nil
  return .JSON~fromJSON(.JSON~toJSON(p))
