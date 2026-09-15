# FlyLo Customer Service and Passenger Rights Policy

## Purpose

FlyLo will give customers clear booking, flight-status, disruption, refund and assistance information without hiding statutory rights behind promotional language or an AI conversation.

## Principles

1. Operational facts come from the airline operations/booking system. Production must use the AS/400 adapter or another explicitly approved operational source; demo data must never silently replace unavailable production data.
2. Legal entitlements are evaluated through the versioned Legal Effect passenger-rights generation. Customer-facing text is an explanation of that result, not the source of the result.
3. The Grok assistant is advisory. It may query approved flight, booking and legal-explanation tools. It may not change a booking, issue money, waive a fare condition, determine an unresolved legal fact, or claim an operational fact that was not returned by an approved tool.
4. Where the evidence is incomplete or conflicting, the customer is told what is unknown and the case is routed for staff review.
5. Refunds, rerouting, care and compensation options must be presented separately so that accepting one option is not implied merely because another was offered.
6. Personal information supplied for booking lookup is used only for the requested service and must not be inserted into unrestricted model context or logs.
7. Every legal explanation shown during disruption must retain the Legal Effect trace identity and the operational evidence identifiers used to derive the facts.
8. The mandatory price is shown before optional ancillaries. Optional products must not be preselected or disguised as required to continue when they are not required.
9. The final payment action must state the amount to be charged and must follow a review of the selected flight, extras and total.
10. A booking is not described as confirmed until the authoritative booking host confirms it. Payment authorisation alone is not a booking confirmation.
11. If payment and booking systems disagree or an external outcome is uncertain, the customer must not be charged again merely because an application request timed out. The case enters controlled recovery using idempotency and transaction identities.
12. Conditions of Carriage acceptance is versioned and retained with the transaction rather than inferred from later website content.
