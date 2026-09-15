# Staff Authority and Core Banking Policy Separation

FederationBank intentionally evaluates two independent policy questions for an internal employee transaction.

## Staff Authority

Answers: *May this employee, in this current work context, make or approve this exact request?*

Inputs include employee/session identity, assignments, delegation/elevation, branch/desk, action semantics, approvals and Staff Authority Institutional Policy.

## Core Banking

Answers: *May FederationBank execute this banking operation for this customer/account/product under current banking, legal, security and regulatory policy?*

The result remains authoritative even when Staff Authority allowed the request.

## Executable proof

`test_core_staff_policy_separation.rex` first proves an authorized teller action can be accepted by the separate STAFF Core policy. It then proves a supervisor/manager combination can possess enough staff authority for a larger transfer while the customer's Core Banking transaction limit still rejects it with `CORPORATE_POLICY_DENIED`.

`test_relationship_staff_core_chain.rex` additionally proves that a proper Relationship Case decision, Relationship Adapter translation and independent Staff Authority can all succeed before the ordinary Core Banking engine commits the transfer.

The Staff module never calls the Ledger directly.
