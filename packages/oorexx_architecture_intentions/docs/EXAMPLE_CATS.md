# Scenario: "I Love Cats" enterprise platform

## What the architect hears

"We want an I Love Cats business platform."

The system must not silently instantiate a website, 27-layer stack, MySQL,
OAuth identities, SaaS billing, clustered storage or public cloud.

## The useful initial questions

1. Is this a public marketplace, charity, internal animal-shelter system,
   veterinary history service, pet-ID network or all of those? Who owns the
   resulting service?
2. Is there an existing application? Old MySQL schema, flat files, proprietary
   software, imports, external vendor APIs? Which is currently authoritative?
3. Are cats the subject of the records, or are they device-identified actors?
   Do people authenticate and represent pets, or do RFID readers authenticate
   as devices? Who approves access to records?
4. What must be migrated, integrated, audited or retained? What are load,
   latency, uptime, regional, data-handling and recovery targets?
5. Which *actual* customer policies apply, their revisions, control ownership,
   evidential standard and allowed delivery channels?
6. How do individual components communicate? Which interface needs same-process DirectCall, JSON-RPC
   sync calls, Queue Fabric work queues, JMS enterprise messages, or XTP
   transport under a RexxOS MU/MI deployment?

## Example policy intersections

- Corporate baseline: forbid unapproved JMS connections.
- Customer standard: requires the ERP/billing boundary to use JMS.
- Result: `ARCH_POLICY_CONFLICT`; an explicit exception or alternative must be
  reviewed. The LINK rule does not silently supersede the corporate rule.
- Compliance requirement: `SPIRAL 1`. The named programme is not enough to
  prove applicability, map controls or demonstrate compliance. Request its
  authoritative versioned control inventory and external qualification.

## Expected output

A plan in `NEEDS_DISCOVERY`, an explicit question set, separate JSON-RPC/JMS
adapter requirements as needed, real Queue Fabric component requests only for
edges using queues, and no invented prices or signed dependency lock.

Run `examples/cats_scope_and_policies.rex` on ooRexx 5.3.0 r13196.

The additional `examples/connect_selector_choices.rex` makes four independently
modelled links and projects actual ConnectSelector provider eligibility for
DIRECT/RPC/QUEUE and a separate JMS/Queue bridge. Its mock adapters demonstrate
non-executing architecture qualification, **not** live delivery.
