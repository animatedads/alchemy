from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'rexx/AlchemyPythonAdapter.cls').read_text()
for method in ('import','evaluate','execute','keyword','box','pythonType'):
    assert '::method '+method+' class' in s
assert 'forward to (.py) message "KW" arguments (arg(1, "A"))' in s
assert 'forward to (.py) message "BOX" arguments (arg(1, "A"))' in s
print('PASS static adapter contract')
