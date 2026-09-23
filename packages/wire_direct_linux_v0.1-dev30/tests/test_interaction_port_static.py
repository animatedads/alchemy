from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=(root/'rexx/WireInteractionCapturePort.cls').read_text()
assert 'library~captureEvent(sealedEvent)' in p
assert 'library~addLink(interactionLink)' in p
assert 'library~assessmentsFor(eventId)' in p
# Exact v0.3 capture API has no markOutcome/captureObservation shortcut.
for forbidden in ('markOutcome', 'captureObservation', 'attachEvidence'):
    assert forbidden not in p
# Wire must not manufacture objects owned by Interaction Event.
for forbidden in ('.InteractionEvent~new', '.InteractionLink~new', '.InteractionAssessment~new'):
    assert forbidden not in p
print('PASS exact Interaction Event v0.3 capture port')
