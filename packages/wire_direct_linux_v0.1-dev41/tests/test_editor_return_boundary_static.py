from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'rexx/WireBuilderSession.cls').read_text()
d=(p/'rexx/WireBehaviourDraft.cls').read_text()
assert '::method acceptEditorSource' in s
section=s.split('::method acceptEditorSource',1)[1].split('::method bindingSpecs',1)[0]
assert 'draft~replaceSource(editedSource)' in section
assert 'WIRE_BUILDER_DRAFT_TYPE' in section
assert 'evaluate(' not in section.lower()
assert '::method replaceSource' in d
print('wire-editor-return-boundary=PASS')
