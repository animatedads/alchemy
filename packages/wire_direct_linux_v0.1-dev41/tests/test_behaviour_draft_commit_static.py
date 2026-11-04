from pathlib import Path
p=Path(__file__).resolve().parents[1]
b=(p/'rexx/WireBuilderSession.cls').read_text()
d=(p/'rexx/WireBehaviourDraft.cls').read_text()
assert '::method commitBehaviourDraft' in b
for x in ('WIRE_BUILDER_DRAFT_STALE','WIRE_BUILDER_DUPLICATE_BINDING','draft~matchesSelection','draft~method'):
    assert x in b
for x in ('::method matchesSelection','WIRE_DRAFT_METHOD_MISMATCH','::method methodDeclaration'):
    assert x in d
assert 'specs~append(spec)' in b
for x in ('Gtk','Gdk','SourceEditor~new','execute draft','loadPackage'):
    assert x not in b+d
print('wire-draft-commit=PASS explicit binding, stale-selection and entrypoint guards')
