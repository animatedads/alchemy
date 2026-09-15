# ooRexx Observation v0.5

Neutral read-only observation protocol, stream, gateway and Queue service shared by Terminal Machine and Virtual Browser.

v0.5 adds `ObservationQueueService`: producer registration, stream descriptors/discovery, consumer replay requests, monotonic consumer checkpoints, optional WLU delivery admission, and Queue Fabric delivery through the stable `ObjectQueueManager~put(queue,payload,options,principal)` boundary.

Semantic state, transport delivery state and consumer checkpoints remain distinct. A WLU-throttled Queue delivery does not remove the observation from the local retained stream; replay can recover it later. Producer and stream descriptors carry stable node identity, capability generation and proof reference without inventing a new trust model.

The optional `ObservationWLUDeliveryAdmission` duck-types a WLU v0.12 capacity bucket; Observation does not acquire WLU scheduling authority. The service authorizer remains a seam for the common Crypto + Access Control + Permissions + Security Effect architecture.
