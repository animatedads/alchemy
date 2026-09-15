# FederationBank Merchant Collateral Protocol v0.1

Arm's-length protocol between FederationBank Merchant Banking and FederationBank Retail/Core Banking.

The package deliberately contains **no implementation of Core account or Ledger mutation**. It defines the request/decision evidence that each regulatory perimeter may exchange.

## Control

Merchant Banking may request control over a specific Core asset under a specific collateral agreement. Core Banking independently decides ownership, validity, enforceability, priority and controlled amount. A rejection is final for that request; the merchant side cannot reinterpret it.

## Realisation

After a Merchant default and close-out decision, Merchant Banking may request realisation of a particular recognised encumbrance. Core Banking independently validates the security authority and executes any permitted cash/asset movement, returning a Core settlement reference.

The protocol therefore keeps these effects distinct:

1. close derivative positions — Merchant Banking authority;
2. realise Core-held collateral — Core Banking authority.
