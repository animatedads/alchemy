from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
html = (root / 'web' / 'index.html').read_text(encoding='utf-8')
boot = (root / 'web' / 'bootstrap.mjs').read_text(encoding='utf-8')
assert '<option' not in html.lower(), 'HTML must not enumerate source/module options'
assert 'config.mjs' not in boot, 'browser must not require edited config.mjs'
assert './service-descriptor' in boot, 'browser must bootstrap from server descriptor'
# Reject suspicious source-file literals in browser code.
for path in [root/'web'/'index.html', root/'web'/'bootstrap.mjs']:
    text = path.read_text(encoding='utf-8')
    assert not re.search(r'[^A-Za-z0-9_](?:examples|tests|rexx)/[^\s"\']+\.(?:rex|cls|java|cpp|rs|py)', text), f'hard-coded source path in {path}'
print('EXAMINER NO MANUAL INVENTORY TEST: PASS')
