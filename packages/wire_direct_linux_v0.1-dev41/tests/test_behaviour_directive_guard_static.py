from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'rexx/WireBehaviourDraft.cls').read_text()
assert "WIRE_DRAFT_EXTRA_DIRECTIVE" in s
assert "left(trimmed, 2) == '::'" in s
assert "remaining = substr(newSource, lf + 1)" in s
assert s.index("WIRE_DRAFT_EXTRA_DIRECTIVE") < s.index("source = newSource")
assert "nextLf = pos('0a'x, remaining)" in s
print('wire-behaviour-directive-guard=PASS extra package directives rejected before source mutation')
