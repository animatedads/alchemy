from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'src/StorageParallelFetch.cls').read_text()
cli=(root/'bin/storagefetchctl.rex').read_text()
need=['StorageRangeSearchRequest','StorageRangeOffer','StorageFetchPolicy','StorageMultiSourcePlanner','StorageOperationalFetchControl','PER_CONTEXT_CAP_PERCENT','MAX_PARALLEL_CONTEXTS','AGGREGATE_CAP_PERCENT']
for n in need: assert n in s,n
assert 'looksLikeIp' in s
assert '--offer' in cli and 'effective_inbound_percent' in cli
print('PASS Storage parallel-fetch static contract')
