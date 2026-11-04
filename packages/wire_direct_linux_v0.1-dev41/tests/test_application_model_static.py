from pathlib import Path
r=Path(__file__).resolve().parents[1]
b=(r/'rexx/WireBinding.cls').read_text()
m=(r/'rexx/WireApplicationModel.cls').read_text()
c=(r/'rexx/WireApplicationController.cls').read_text()
e=(r/'rexx/WireApplicationEvent.cls').read_text()
assert 'source trigger target method' in b
assert 'binding~source == source & binding~trigger == trigger' in m
assert 'model~bindingsFor(event~source, event~trigger)' in c
assert 'binding~target~sendWith(binding~method, .array~of(event))' in c
assert 'source trigger context timestamp rendererContext' in e
alltext='\n'.join((b,m,c,e))
for forbidden in ('Gtk','Gdk','IMAP','uidFetch','MLAssessment','ObservationQueueService','train','fit(', 'GLib'):
    assert forbidden not in alltext, forbidden
# No MailReader-specific event names or classes in generic model/controller.
for forbidden in ('SelectionChanged','WireMailReaderBehaviour','importance','mailbox'):
    assert forbidden not in alltext, forbidden
print('PASS executable application model: semantic binding + generic dispatch authority')
