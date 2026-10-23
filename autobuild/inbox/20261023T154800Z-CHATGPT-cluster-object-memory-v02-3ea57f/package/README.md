# Cluster Object Memory Fabric Transport v0.2

Execution-to-memory transport seam for ooRexx clustered objects.

API: `cluster.object.peer/0.2`.

The package keeps authority separated:

- Memory Fabric owns provider/block identity, residency, generation and owner-epoch fencing.
- Queue Fabric owns inter-node control/object transport.
- Job-to-Node remains placement/admission authority and is deliberately not reimplemented here.
- Application objects remain ordinary ooRexx objects.

A MOVE carries a compact execution envelope and fenced Memory Fabric reference. It does not carry resident memory merely because execution changes node. Destination argument resolution occurs only after current block/provider fencing succeeds.

The October 7 runtime qualification used Memory Fabric dev6 plus Object Queue Fabric from RTO2 Grid dev7. Static compatibility inspection on October 23 confirms the Memory Fabric classes/methods consumed here remain present in dev10. Runtime requalification against dev10 remains an environment gate; this submission does not overstate it.
