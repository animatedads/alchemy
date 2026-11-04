from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'rexx/WireBuilderSession.cls').read_text()
spec=(root/'rexx/WireBuilderBindingSpec.cls').read_text()
reg=(root/'rexx/WireBehaviourRegistry.cls').read_text()
comp=(root/'rexx/WireBindingCompiler.cls').read_text()
assert 'selectElement' in s and 'selectEvent' in s and 'bindBehaviour' in s
assert '.WireBuilderBindingSpec~new(id, selectedSource, selectedTrigger, behaviour, method)' in s
assert 'behaviour get' in spec and 'target' not in spec
assert 'registry~resolve(spec~behaviour)' in comp
assert '.WireBinding~new(spec~id, spec~source, spec~trigger, target, spec~method' in comp
# Design-time Builder must stay symbolic and renderer/source/scheduler neutral.
for text in (s,spec,reg,comp):
    for forbidden in ('Gtk','Gdk','IMAP','Observation','MLAssessment','ObjectQueueManager','GLib','pthread'):
        assert forbidden not in text, forbidden
# No live target object may be persisted by the Builder spec.
for forbidden in ('::attribute target', 'use strict arg id, source, trigger, target'):
    assert forbidden not in spec, forbidden
print('PASS builder editing path: element -> event -> symbolic behaviour; runtime resolution remains separate')
