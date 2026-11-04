from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'rexx/WireBuilderSession.cls').read_text()
d=(p/'rexx/WireBehaviourDraft.cls').read_text()
assert "spec~metadata['wire.behaviour.source'] = draft~source" in s
assert "spec~metadata['wire.behaviour.method'] = draft~method" in s
assert r'if first \== declaration' in d
assert "right(first, 1) == '0d'x" in d
assert 'if lf = 0 then raise syntax' in d
assert s.index('WIRE_BUILDER_DRAFT_STALE') < s.index("spec~metadata['wire.behaviour.source']")
assert s.index('self~assertUnusedBindingId(id)', s.index('::method commitBehaviourDraft')) < s.index("spec~metadata['wire.behaviour.source']")
print('wire-editor-roundtrip=PASS edited source retained at explicit commit; exact method header')
