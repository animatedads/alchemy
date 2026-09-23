from objects import RexxArgumentProbe, OMITTED

probe = RexxArgumentProbe.new()

cases = [
    ("omitted", OMITTED, "OMITTED"),
    ("nil", None, "NIL"),
    ("empty", "", "EMPTY"),
    ("value", "hello", "VALUE:hello"),
]

for label, value, expected in cases:
    if value is OMITTED:
        got = probe.probe()
    else:
        got = probe.probe(value)
    print(f"python-{label}->rexx:", got)
    assert got == expected, (label, got, expected)

assert probe.probe() != probe.probe(None)
assert probe.probe(None) != probe.probe("")
assert probe.probe() != probe.probe("")

print("PYTHON -> REXX OMITTED != NIL != EMPTY POC PASS")
