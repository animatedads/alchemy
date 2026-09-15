# VMM institutional close-out operations protocol v0.9

Protocol: `vmm.institutional.synthetic.closeout/0.9`

Legal operator: `VECTOR_MERIDIAN_MARKETS_LTD`

This protocol begins after a v0.8 institutional synthetic close-out determination exists. It does not replace `vmm.institutional.synthetic.default/0.8` and it never edits the original determination.

## Queue boundary

Dedicated durable queues carry:

- institutional valuation-dispute instructions;
- VMM processing results;
- VMM finalization notices.

The institutional client can PUT dispute instructions and GET VMM results/notices. VMM has the inverse directional permissions. Federation principals receive no ACL. The client object retains Queue Fabric plus its own principal/legal/counterparty identity only; it has no VMM engine, default service or close-out-operations reference.

## Dispute and finalization

A dispute must identify an existing close-out, one of the contract parties, a different proposed signed gross amount, date, evidence and authority. It must arrive within the currency policy's dispute window.

Fallback resolution uses the configured independent valuation agent and retains methodology/market-data evidence. The original termination valuation agent cannot serve as its own fallback.

Finalization is immutable and has one of two bases:

- `ORIGINAL_UNDISPUTED`: allowed only after the dispute window has expired;
- `DISPUTE_RESOLUTION`: allowed only after a dispute is resolved.

Only finalization authorizes v0.9 cash settlement/accounting.

## Master-agreement netting set

A set requires at least two finalized terminated contracts and exact equality of:

- counterparty ID and legal entity;
- master agreement;
- settlement currency.

It additionally requires governing-law, legal-opinion, close-out-netting-election and authority evidence. Already settled/member close-outs cannot enter.

The determination retains gross VMM receivable, gross VMM payable and signed net amount. It does not include segregated IM. One aggregate settlement marks all member close-outs cash-settled and blocks individual member settlement.

## Post-termination segregated IM

After cash close-out is settled, VMM may instruct return of an exact historical initial-margin transfer. The return retains asset identity, gross carrying value, haircut-adjusted recognized risk value and custodian. Acknowledgement does not change effective collateral; custody settlement does. Return beneficiary is VMM.

## Sign convention

All close-out/finalization/netting amounts are from VMM's perspective:

- positive: VMM receivable;
- negative: VMM payable;
- zero: flat.

VMM hedge-unwind P&L remains separate attribution evidence unless an independently evidenced legal term makes an amount recoverable.
