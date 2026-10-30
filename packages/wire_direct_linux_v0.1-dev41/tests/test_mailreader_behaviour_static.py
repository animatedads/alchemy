from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=(root/'rexx/WireMailReaderBehaviour.cls').read_text()
low=p.lower()
assert 'subjectprojection~subjectfor(event)' in low
assert 'interactionboundary~selectionchanged(subjectref, event)' in low
assert 'selectionprojection~selectionchanged(event)' in low
assert 'assessmentprojection~assessmentchanged(subjectref)' in low
# Composition must not acquire authorities owned by existing subsystems.
for forbidden in ('elapsed','stopwatch','timer','sleep','~captureevent','~observationqueue','~commitcheckpoint','~markoutcome','mlassessment~new','train(','fit(','~uidfetch','~body.peek','~show_list_range','gtk_' ,'glib_' ,'~sort','~reorder'):
    assert forbidden not in low, forbidden
print('PASS MailReader composition: selection + existing interaction boundary + sparse assessment, no lifecycle/ML/source authority')
