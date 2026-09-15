# FlyLo Disruption and AI Customer-Service Procedure

## 1. Establish the operational record

Retrieve the flight from the production AS/400 adapter. Confirm flight number, operating date, origin, destination, scheduled and actual times, cancellation state, disruption reason, passenger booking state, merchant-of-record state, payment method and any alternative itinerary offered or accepted.

If the AS/400 transport is unavailable, mark the case `OPERATIONS_UNAVAILABLE`. Do not switch to demo records. Staff may use the explicit demo adapter only in development or training environments.

## 2. Derive legal facts

Convert the operational record into evidence-bearing facts required by the FlyLo legal generation. Examples include `DEPARTS_UK`, `FLIGHT_CANCELLED`, `ARRIVAL_DELAY_AT_LEAST_3H`, `DELAY_AT_LEAST_5H`, `CARE_THRESHOLD_REACHED`, `EXTRAORDINARY_CIRCUMSTANCES`, `US_COVERED_FLIGHT`, `CANCELLED_OR_US_SIGNIFICANT_CHANGE`, and `PASSENGER_DID_NOT_ACCEPT_ALTERNATIVE`.

Do not infer an unknown disruption cause or passenger choice merely to obtain a determinate result.

## 3. Evaluate Legal Effect

Evaluate the relevant action: care, cancellation refund/rerouting, delay refund, fixed compensation, U.S. refund, refund deadline or U.S. enforcement posture. Retain the assessment, source/provision anchors and decision-trace identity.

`REVIEW_REQUIRED` is a valid result. Route it to a trained staff member with the unresolved inputs identified by the Legal Effect trace query.

## 4. Customer communication

The website or Grok assistant may explain the assessment using the approved legal-explanation tool. The explanation must distinguish confirmed operational facts, legal effects, unresolved facts and optional commercial goodwill.

The assistant must not present temporary enforcement discretion as repeal of an underlying right and must not convert a legal `REVIEW_REQUIRED` result into a promise or refusal.

## 5. Execution

Only an authorised transactional service may rebook, cancel, refund or compensate. AI tool calls are proposals routed through the approved tool broker/orchestrator and must preserve the booking reference, actor, action, result and legal trace identity in the audit record.

## 6. Sale completion and recovery

For a new booking, retain the selected offer identity, passenger data, ancillary choices, accepted Conditions of Carriage version, payment idempotency key, payment authorisation identity and booking idempotency key.

Do not represent payment authorisation and AS/400 booking creation as a single atomic operation unless an actual distributed transaction contract is introduced and proven. If the payment provider authorises but the booking call times out or returns an indeterminate response, set the sale to `RECOVERY_REQUIRED`. Reconcile by idempotency/transaction identity before any retry. Never retry the charge solely because a previous application call did not receive a response.
