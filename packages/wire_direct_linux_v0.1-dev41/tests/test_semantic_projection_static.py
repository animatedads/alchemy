from pathlib import Path
root=Path(__file__).resolve().parents[1]
subject=(root/'rexx/WireEventSubjectProjection.cls').read_text()
assessment=(root/'rexx/WireAssessmentProjection.cls').read_text()
ref=(root/'rexx/WireSubjectRef.cls').read_text()
assert 'event~context[contextKey]' in subject
assert '.WireSubjectRef~new(value)' in subject
assert 'resolver~valueForSubject(subjectRef)' in assessment
assert 'target~setProperty(property, value)' in assessment
for text in (subject,assessment,ref):
    low=text.lower()
    for forbidden in ('gtk','glib','body.peek','uidfetch','imapcommand','train(','markoutcome','captureobservation','interactioncapturelibrary'):
        assert forbidden not in low, forbidden
print('PASS semantic subject + assessment projection: identity is transported; existing authorities remain external')
