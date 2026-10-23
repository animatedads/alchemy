import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
d = json.loads((root/'integration.json').read_text())
assert d['schema'] == 'alchemy.autobuild.integration/0.2'
assert d['package']['name'] == 'rexxos_managed_compute_mu'
assert d['publish']['tree']['path'] == 'packages/rexxos_managed_compute_mu_v0.1-dev2'
s = (root/'src/ManagedComputeMU.cls').read_text()
assert 'allocator~verifyLease(lease,request,now)' in s
assert "'REPLAY_HELD'" in s
assert 'CLAIMED' in s
w = (root/'windows/Invoke-ManagedComputeWindows.ps1').read_text()
assert '--network=none' in w and '--pull=never' in w
assert 'IMAGE_NOT_PINNED' in w
print('PASS static manifest, authority, Windows boundary')
