# XTP dev18 — receiver-advertised RATE/BURST pacing

Dev18 completes the executable XTP rate-control loop for the multicast stream profile.

Receiver CNTL already contains `RATE`, `BURST`, `RSEQ`, and `ALLOC`. Dev18 parses all four and keeps them per receiver. The sender uses the minimum RATE/BURST values across the known receiver population, while the existing ALLOC controller continues to use the minimum ALLOC.

The controls are orthogonal:

```text
ALLOC       how far the sequence may advance
RATE/BURST  how quickly otherwise-legal bytes may be emitted
```

A receiver can therefore expose a large receive window but request low burst rate, or expose a small window while permitting fast bursts.

`RATE=0xffffffff` means rate pacing disabled in this bounded implementation, corresponding to XTP's documented `RATE=-1` convention. `BURST=0` is invalid.

The sender's pacing gate groups information packets into bursts no larger than the receiver BURST value and delays the next burst according to bytes emitted / RATE. Retransmitted packets pass through the same gate; failover or go-back-N does not bypass receiver rate policy.

This remains below the common socket selector and above L2/raw36/UDP carriers, so Queue Fabric, Memory Fabric and Storage Fabric do not implement transport timing themselves.
