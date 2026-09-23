from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=(root/'src/Wire3DPresentation.cls').read_text()
j=(root/'web/wire3d.js').read_text()
h=(root/'web/index.html').read_text()
assert 'Wire3DLayoutCollection' in p
assert 'Wire3DPresentationRegistry' in p
assert 'Wire3DPersonInfoLayout' in p
assert 'Wire3DTranscriptedMediaLayout' in p
assert 'display3d' in (root/'examples/domain/TranscriptedMediaDemo.cls').read_text()
assert 'openPresentation' in j and 'presentationWorkspace' in j
assert 'data-nav="workspace"' in h
print('Wire3D semantic presentation static: PASS')
