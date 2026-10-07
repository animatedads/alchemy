from pathlib import Path

root = Path(__file__).resolve().parents[1]
html = (root / 'web/index.html').read_text()
boot = (root / 'web/bootstrap.mjs').read_text()

required = [
    'data-role="code-examiner"',
    'CODE.CLASS.INSPECT',
    'CODE.COMPARE',
    'METHOD.REQUIREMENT.CREATE',
    'WORK.ACCEPT',
    'BRANCH.CONFLICT.RESOLVE',
]
for token in required:
    assert token in html, token

# A missing service or JS package must not erase the useful shell.
assert "mount.innerHTML = ''" not in boot
assert "startWireUI().catch(showConnectionFailure)" in boot
assert "authenticationRequired !== true" in boot
print('EXAMINER LIVE SHELL TEST: PASS')
