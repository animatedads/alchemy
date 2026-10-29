from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'src/StorageInstrumentationMesh.cls').read_text()
required=[
 '::class StorageFabricMeshSource public',
 '::class StorageInstrumentationHooks public',
 '::class StorageInstrumentedTransfer subclass StorageTransfer public',
 '::class StorageTransferCommitObserver public',
 '::class StorageProviderStateObserver public',
 'instrumentationEvents~transferStarted',
 'instrumentationEvents~transferProgress',
 'instrumentationEvents~transferCompleted',
 'instrumentationEvents~transferFailed',
 'authority~replicaPolicies',
 'StorageFabricInstrumentationSource~new',
 'self~begin:super',
 'self~progress:super(bytesArg)',
 'self~commit:super',
 'self~fail:super(reasonArg)',
 '::requires "InstrumentationMesh.cls"',
]
for needle in required:
    assert needle in s, needle
assert 'FkKsHJbLF0a2EMQL' not in s
commit=s[s.index('::method commit\n  expose instrumentationEvents'):s.index('::method fail\n  expose instrumentationEvents')]
assert 'transferCompleted' in commit
verify=s[s.index('::method verify\n  use strict arg verificationArg'):s.index('::method commit\n  expose instrumentationEvents')]
assert 'transferCompleted' not in verify
print('PASS static storage instrumentation boundary-hook contract')
