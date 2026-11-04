from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=(root/'rexx/WireObservationConsumerPort.cls').read_text()
# Exact ObservationQueueService v0.5 consumer API.
for required in (
    'service~checkpoint(consumerId, streamId)',
    'service~replay(replayRequest)',
    'service~commitCheckpoint(consumerId, streamId, sequence, generation, now)',
    'service~discover(terminalType, nodeId)',
):
    assert required in p, required
# Ownership stays in Observation v0.5: Wire must not manufacture evidence,
# streams, requests, checkpoints, or acquire producer/delivery authority.
for forbidden in (
    '.ObservationEnvelope~new', '.ObservationStreamRecord~new',
    '.ObservationStream~new', '.ObservationReplayRequest~new',
    '.ObservationConsumerCheckpoint~new', 'registerProducer', 'registerStream',
    'publishLatest', 'ObjectQueueManager', '~put(',
):
    assert forbidden not in p, forbidden
# Consumer port is also not an ML/training boundary.
for forbidden in ('ML', 'train', 'classifier', 'importance', 'Gtk', 'IMAP'):
    assert forbidden not in p, forbidden
print('PASS exact Observation v0.5 consumer port + authority boundaries')
