from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=(r/'src/PharoObject.cls').read_text(); b=(r/'src/PharoBridge.cls').read_text(); s=(r/'pharo/AlchemyRexxBridge.st').read_text(); i=(r/'docs/LIVE_INSPECTION_CONTRACT.md').read_text()
assert "installForeignUnknownComposition('BRIDGEUNKNOWN')" in p
assert 'bridge~understands' in p and 'bridge~send' in p and 'foreignUnknownFallback' in p
assert 'arguments = .nil' in b and 'arguments = .array~new' in b
assert 'doesNotUnderstand: aMessage' in s and 'aMessage selector' in s and 'aMessage arguments' in s
assert 'cached inspector snapshot' in i and 'without recreating the proxy' in i
print('PHARO ALCHEMY dev6 review contract PASS')
