from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=(r/'src/PharoObject.cls').read_text()
s=(r/'pharo/AlchemyRexxBridge.st').read_text()
m=(r/'docs/MESSAGE_MODEL.md').read_text()
assert "subclass AlchemyForeignObject" in p
assert "installForeignUnknownComposition('BRIDGEUNKNOWN')" in p
assert "bridge~understands" in p and "bridge~send" in p
assert "foreignUnknownFallback" in p
assert "doesNotUnderstand: aMessage" in s
assert "aMessage selector" in s and "aMessage arguments" in s
assert "Nested Rexx -> Pharo -> Rexx -> Pharo" in m
print("PHARO ALCHEMY static contract PASS")
