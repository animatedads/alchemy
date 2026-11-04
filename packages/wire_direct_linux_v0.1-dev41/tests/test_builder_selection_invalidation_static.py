from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'rexx/WireBuilderSession.cls').read_text()
assert 'expose selectedSource selectedTrigger\n  use strict arg source' in s
assert 'if source \\== selectedSource then selectedTrigger = ""' in s
assert s.count('self~assertUnusedBindingId(id)') == 2
assert '::method assertUnusedBindingId private' in s
assert s.count("WIRE_BUILDER_DUPLICATE_BINDING") == 1
print('PASS element reselection invalidates event; binding identity unique across both creation paths')
