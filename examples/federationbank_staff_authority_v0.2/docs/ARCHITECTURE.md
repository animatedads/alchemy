# Architecture

## Purpose

FederationBank Staff Authority provides the institutional business-authority layer between authenticated workforce context and ordinary Core Banking commands.

Authentication is evidence that a session belongs to an employee. Staff Authority is a different proposition: whether that employee may perform a particular banking act in the present branch/desk/role/delegation context, and under which maker/checker rules.

## Authority pipeline

```text
HR / IAM / Workforce authority
        |
 principal + session + assignment facts
        |
        v
FederationBank Staff Authority
        |         ^
        |         |
        |   independent checker contexts/approvals
        |
 exact positive authority envelope
        |
        v
FederationBankStaffCommandBinder
        |
 ordinary STAFF FederationBankCommand
        |
        v
FederationBank Core Banking
 Bouncer -> Institutional Policy -> Legal/Security -> account/payment authority
        |
        v
Ledger
```

Staff Authority does not own or duplicate the Core Banking execution path.

## Why an envelope exists

A positive authority result is deliberately not a reusable role token. `FederationBankStaffAuthorityEnvelope` binds:

- the exact action semantic identity;
- staff and session identity;
- the policy release and matched rule;
- the authority decision;
- selected approvals;
- time validity.

Changing amount, account, operation, customer, branch, command identity or other action semantics invalidates command binding.

## Information sources versus authority

`FederationBankStaffPrincipalRef`, role assignments, delegation and session objects are sealed references/snapshots of externally authoritative facts. This module does not become the HR database or authentication provider by caching them.

Policy gives those facts operational meaning. A role name alone is not a permission.

## Policy layers stay separate

A staff teller may be institutionally authorized to request a GBP 2,500 transfer and Core Banking may still reject it for customer/product/legal reasons. Conversely, a transaction within the customer's Core limit is not executable unless the employee independently holds the required staff authority.

This prevents the common internal-channel failure mode where `STAFF` means `trusted` and silently bypasses customer banking controls.
