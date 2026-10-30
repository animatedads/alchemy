from pathlib import Path
p=Path('rexx/WireCompletion.cls').read_text()
for token in ['WireCompletionRequest','WireCompletionProvider','WireCompletionService','providers[key]~complete(request)']:
    assert token in p
for forbidden in ['Gtk','QuickJS','IMAP','Observation','~send(', 'executeBlock']:
    assert forbidden not in p
assert 'projected capability surface' in p
assert 'must not execute user code' in p
print('PASS completion contract: provider-owned language spelling; no engine/renderer/source or execution authority')
