# FlyLo Sales Process v0.2

## 1. Search and offer

The customer supplies route, travel date and passenger count. `FLIGHT.SEARCH` is sent to the operations service. Every returned offer must carry an offer identity, flight identity, currency and mandatory fare amount. Production availability comes from the approved operational host; demo data is allowed only in explicit demo mode.

The displayed flight price includes mandatory charges represented by the offer. Optional products are not included unless clearly identified as included.

## 2. Offer selection

`FLIGHT.SELECT` creates a sale identity and pins the selected offer. The application does not re-price the chosen offer from display text. A future live pricing host may impose quote expiry/revalidation, but any changed price must be surfaced before payment rather than silently substituted.

## 3. Passenger details

`PASSENGER.SAVE` captures the passenger information required to create the booking. The sales process validates passenger count against the selected offer. Personal information must not be copied into unrestricted AI prompts or general diagnostic logs.

## 4. Optional extras

`ANCILLARY.SAVE` records explicit customer choices. Cabin bag, checked bag, seat selection and priority boarding are optional in the v0.2 demonstration catalogue and are unselected by default. Their prices remain separately visible in the review stage.

No ancillary-selection UI may represent omission as an error when the product is genuinely optional.

## 5. Review and terms

Before payment, the customer sees the flight amount, selected extras and total. `SALE.REVIEW` records the exact Conditions of Carriage version accepted by the customer. The final price is not derived from hidden client state alone; the server-side sale remains authoritative.

## 6. Payment

The FlyLo application receives only an opaque payment-method token from a PCI-capable payment provider. Raw card number and CVV data are outside the FlyLo application boundary.

`PAYMENT.AUTHORIZE` uses a payment idempotency key scoped to the sale. An authorisation must match the server-side sale amount and currency.

## 7. Booking creation

After payment is authorised, the process sends `BOOKING_CREATE` to the production AS/400 adapter with a separate booking idempotency key, the pinned offer, passenger data, extras, accepted terms version, authorised payment identity, amount and currency.

The customer is shown `CONFIRMED` only when the booking host returns a confirmed booking record.

## 8. Uncertain outcome

Payment authorisation and booking creation are not falsely described as one atomic database transaction.

If payment is authorised but the booking outcome is unavailable or uncertain, the sale becomes `RECOVERY_REQUIRED`. Staff/recovery automation must query the payment and booking systems by their idempotency/transaction identities before attempting another charge or another booking creation.

A timeout is not evidence that the previous external side effect did not happen.

## 9. Post-booking passenger servicing (v0.4.7)

Post-booking servicing is not modelled as rewriting the original sale. Booking lookup creates a Wire UI v0.16 passenger workspace over stable passenger identities. The UI may select one or more passengers, but `BOOKING.ADD_CHECKED_BAG` is accepted only with the exact current server-minted workspace context. Browser row position, display name and model prose are not transaction authority.

The checked-bag service is priced server-side at the current development authority, obtains a separate opaque payment authorisation and appends an ancillary-service record to the booking projection. Reusing the same servicing idempotency identity returns the prior result. Production payment and host adapters remain separate boundaries.
