/* Detached read-only publication proposal with SSC evidence, no writes. */
handoff = .Directory~new
handoff['schema'] = 'alchemy.architecture.promotion-handoff/0.1'
handoff['projectId'] = 'cats'
handoff['scenarioId'] = 'local'
handoff['executable'] = .JSON~false
handoff['alternatives'] = .Array~new
handoff['alternatives']~append('cloud')
ssc = .Directory~new
ssc['schema'] = 'alchemy.architecture.ssc-qualification/0.1'
ssc['projectId'] = 'cats'
ssc['scenarioId'] = 'local'
ssc['executable'] = .JSON~false
ssc['status'] = 'SSC_RESOLUTION_VERIFIED'
r = .ArchitectureNotNotesPublication~new(handoff,ssc)
call assert r~state == 'PUBLICATION_REQUEST_ONLY', 'request state'
p = r~projection
call assert p['schema'] == 'alchemy.architecture.notnotes-publication-request/0.1','schema'
call assert p['owner'] == 'ALCHEMY_NOTNOTES','external authority'
call assert p['executable'] == .JSON~false,'no execution'
call assert p['publicationReceipt'] == .nil,'no fabricated receipt'
call assert p['sscEvidence']['status'] == 'SSC_RESOLUTION_VERIFIED','receipt retained'
p['body']['projectId']='tampered'
call assert r~projection['body']['projectId'] == 'cats','defensive copy'
say 'PASS NotNotes proposal: detached, non-executable, no publication receipt'
exit 0
assert:
  use arg condition, explanation
  if condition then return
  say 'FAIL' explanation
  exit 1
::requires 'ArchitectureNotNotesPublication.cls'
