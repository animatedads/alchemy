# Observation v0.5 architecture

Producer engine -> observer -> ObservationStream -> ObservationQueueService -> WLU delivery admission -> Queue Fabric -> remote consumer.

Independent identities/state:

- engine snapshot generation: semantic state revision;
- observation stream sequence: retained observation ordering;
- Queue Fabric package/correlation identity: delivery state;
- consumer checkpoint: last durably consumed observation sequence;
- observation subscriber lease: temporary read authority.

`ObservationProducerRegistration` identifies the producing node and carries `proofRef` plus capability generation. `ObservationStreamDescriptor` exposes discoverable stream/session/type/device/node metadata. These proof fields are integration seams for the common trust architecture, not self-validating assertions.

Replay is based on observation stream sequence, never Queue message number. Checkpoints are monotonic and reject regression. WLU admission gates Queue delivery only; it cannot rewrite semantic observation history.
