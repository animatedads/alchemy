from pathlib import Path
p=Path('rexx/WireLanguageBlock.cls').read_text()
b=Path('rexx/WireLanguageBlockBridge.cls').read_text()
assert '::class WireLanguageBlock public' in p
assert '::method dispatch' in p
assert 'variables["event"] = event' in p
assert 'return bridge~executeBlock(language, source, variables)' in p
assert '::method executeBlock abstract' in b
# Hard choke point: no renderer, engine, scheduler or foreign-language dispatch graph.
for forbidden in ['Gtk','QuickJS','qjs_', 'Promise', 'pumpJobs', 'IMAP', 'Observation', 'thread', 'async']:
    assert forbidden not in p
print('PASS language block choke point: Wire dispatch remains ooRexx; foreign entry/return is one bridge call')
