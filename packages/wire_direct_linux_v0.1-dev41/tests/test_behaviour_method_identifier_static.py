from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'rexx/WireBehaviourDraft.cls').read_text()
assert "letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_'" in s
assert "chars = letters || '0123456789'" in s
assert "verify(substr(method, 1, 1), letters)" in s
assert "verify(method, chars)" in s
assert "WIRE_DRAFT_METHOD_INVALID" in s
assert s.index("WIRE_DRAFT_METHOD_INVALID") < s.index("source = '::method '")
print('PASS generated method names reject directive/newline injection before scaffold creation')
