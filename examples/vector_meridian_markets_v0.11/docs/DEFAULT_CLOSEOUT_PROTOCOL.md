# VMM institutional default / close-out protocol v0.8

Protocol: `vmm.institutional.synthetic.default/0.8`

## State progression

```text
ACTIVE CONTRACT
    |
    +-- DEFAULT NOTICED (contract still ACTIVE)
            |
            +-- CURED on/before deadline -> contract remains ACTIVE
            |
            `-- UNCURED after deadline
                    |
                    `-- non-defaulting party elects TERMINATION
                              |
                              `-- immutable CLOSE-OUT DETERMINATION
                                         |
                                         `-- cash SETTLEMENT
```

These are deliberately different legal/economic facts and are never collapsed into one call.

## Bilateral queue boundary

Dedicated durable queues carry:

- VMM -> client default notices;
- client -> VMM cure instructions when the client is the defaulting party;
- client -> VMM termination elections when VMM is the defaulting party;
- VMM -> client processing results.

Directional ACLs are created for the disclosed institutional gateway and VMM default principal. Federation principals receive no grant. The client helper stores only Queue Fabric manager/identity state and exposes no VMM engine/default service.

## Close-out amount

`grossAmountToVMM` is signed from VMM's perspective. Cash variation margin already posted by VMM may be included with explicit collateral-netting evidence:

`netAmountToVMM = grossAmountToVMM + cashVariationMarginPosted`

In v0.8, segregated initial margin is reported on the determination but is not silently included in that equation. A future treatment must identify legal netting rights and collateral-control evidence explicitly.

## Hedge separation

`VMMSyntheticCloseoutHedgeAttribution` records VMM hedge unwind P&L independently. It is not a legal close-out component. A poor VMM hedge therefore remains VMM's problem unless the master agreement independently creates a recoverable amount with its own evidence.
