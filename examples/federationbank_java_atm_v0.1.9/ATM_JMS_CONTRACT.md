# FederationBank ATM JMS Contract v0.1

## Destinations

```text
Request queue:       FB.ATM.REQUESTS
Per-terminal replies: FB.ATM.REPLIES.<terminalId>
Rules topic:          FB.ATM.RULES
```

The reply destination is durable rather than temporary because losing a JMS connection must not make the monetary outcome of a physical cash operation unknowable.

## Message type

ATM protocol messages are JMS `TextMessage` values containing UTF-8 JSON.

Required JMS metadata on a request:

```text
JMSCorrelationID       = commandId
JMSReplyTo             = the terminal reply queue
FB_ATM_SCHEMA          = federationbank.atm.request/0.1
FB_ATM_OPERATION       = operation
FB_ATM_TERMINAL_ID     = terminalId
FB_ATM_RULES_VERSION   = rulesVersion
```

The reply uses the same `JMSCorrelationID` and carries the same `commandId` inside the JSON payload. Both are checked.

## Request envelope

```json
{
  "schema": "federationbank.atm.request/0.1",
  "commandId": "ATM-IOM-001-WDA-000000000142",
  "idempotencyKey": "ATM-IOM-001-WDA-000000000142",
  "operation": "WITHDRAW_AUTHORISE",
  "terminalId": "ATM-IOM-001",
  "terminalSequence": 142,
  "sessionId": "SESSION-...",
  "requestedAt": "2026-08-25T21:30:00Z",

`requestedAt` is emitted in UTC ISO-8601 at no more than millisecond precision.
Durable operation identity is carried by `commandId`, `idempotencyKey` and
`terminalSequence`; timestamp sub-millisecond precision is not part of identity.
  "rulesetId": "FB-ATM-IOM",
  "rulesVersion": 17,
  "data": {}
}
```

A retransmission of one business action retains the same `commandId` and `idempotencyKey`. The terminal sequence is durably allocated before use.

## Response envelope

```json
{
  "schema": "federationbank.atm.response/0.1",
  "commandId": "ATM-IOM-001-WDA-000000000142",
  "operation": "WITHDRAW_AUTHORISE",
  "terminalId": "ATM-IOM-001",
  "ok": true,
  "code": "WITHDRAW_AUTHORISED",
  "detail": "",
  "bankTime": "2026-08-25T21:30:00Z",
  "data": {}
}
```

Business behaviour is driven by `ok`, `code`, and structured `data`; human-readable `detail` is not parsed.

## Operations implemented by this client

```text
TERMINAL_SIGN_ON
GET_RULES
LOGON
LOGOFF
LIST_ACCOUNTS
GET_BALANCE
GET_OFFLINE_ALLOWANCE
WITHDRAW_AUTHORISE
WITHDRAW_COMMIT
WITHDRAW_CANCEL
WITHDRAW_EXCEPTION
DEPOSIT_COMMIT
GET_TRANSACTION_STATUS
OFFLINE_WITHDRAWAL_ADVICE
```

## TERMINAL_SIGN_ON

Request data includes:

```json
{
  "softwareVersion": "0.1.0",
  "protocolVersion": "0.1",
  "supportedOperations": ["LOGON", "LIST_ACCOUNTS", "GET_BALANCE", "WITHDRAWAL", "DEPOSIT"]
}
```

Expected codes include `TERMINAL_ACCEPTED`, `TERMINAL_DISABLED`, `TERMINAL_UNKNOWN`, and `UPGRADE_REQUIRED`.

## GET_RULES / RULES_UPDATE

Response data:

```json
{
  "rules": {
    "schema": "federationbank.atm.rules/0.1",
    "rulesetId": "FB-ATM-IOM",
    "version": 17,
    "issuedAt": "2026-08-25T20:00:00Z",
    "validFrom": "2026-08-25T20:00:00Z",
    "validUntil": "2026-08-26T20:00:00Z",
    "target": {"terminalId": "*", "region": "IOM"},
    "online": {"balance": true, "withdrawal": true, "deposit": true},
    "offline": {
      "balanceMode": "CACHED_MARKED_STALE",
      "withdrawalMode": "DENY",
      "depositMode": "CAPTURE_AND_QUEUE"
    },
    "limits": {
      "maxWithdrawalMinor": 50000,
      "maxDepositMinor": 100000,
      "sessionTimeoutSeconds": 600
    }
  },
  "signatureAlgorithm": "Ed25519",
  "keyId": "FB-ATM-RULE-KEY-1",
  "signature": "base64..."
}
```

The signature is over canonical JSON of the `rules` object: object keys are sorted recursively, arrays retain order, strings/numbers/booleans retain JSON meaning. The client rejects invalid signatures, expired rules, target mismatch and a lower rules version than the currently accepted one.

## LOGON

Demo request data:

```json
{
  "cardId": "4111111111111111",
  "credentialType": "DEMO_PIN",
  "credential": "..."
}
```

The bank derives the customer identity from authentication. It must not trust a caller-supplied `customerId` in place of the authenticated session.

Production PIN-block/HSM semantics replace `DEMO_PIN`; this message shape is intentionally a demo boundary.

## LIST_ACCOUNTS

Response data:

```json
{
  "accounts": [
    {
      "accountId": "GBP-001",
      "displayName": "Current Account",
      "productCode": "OFFSHORE_CURRENT",
      "currency": "GBP",
      "status": "OPEN"
    }
  ]
}
```

Only accounts owned/available to the authenticated customer are returned.

## GET_BALANCE

Request data:

```json
{"accountId":"GBP-001"}
```

Response data:

```json
{
  "accountId": "GBP-001",
  "currency": "GBP",
  "bookBalanceMinor": 125000,
  "heldMinor": 10000,
  "availableBalanceMinor": 115000,
  "asOf": "2026-08-25T21:31:00Z"
}
```

This is deliberately consistent with FederationBank v0.6:

```text
available = book - ACTIVE holds
```


## GET_OFFLINE_ALLOWANCE (FederationBank v0.9)

The terminal may request a bank-issued single-use offline cash authority while online:

```json
{
  "accountId": "GBP-001",
  "currency": "GBP",
  "amountMinor": 10000,
  "authorityMode": "RESERVED_ALLOWANCE"
}
```

The returned authority is bank-owned evidence bound to terminal, authenticated customer, account, currency and rules version. `RESERVED_ALLOWANCE` is backed by a real Ledger hold. `DELEGATED_STAND_IN` is a separately governed bank risk authority. The terminal persists the returned envelope but cannot mint or enlarge it.

## RELEASE_OFFLINE_ALLOWANCE (v0.1.7 candidate)

An unused locally `ACTIVE` bank-issued authority may be returned while the customer session is still available:

```json
{
  "offlineAuthorityId": "OFFAUTH-...",
  "authorityMode": "RESERVED_ALLOWANCE",
  "accountId": "GBP-001",
  "currency": "GBP",
  "maxAmountMinor": 10000,
  "releaseRequestedAt": "2026-08-26T02:45:00Z"
}
```

The request uses a dedicated stable command/idempotency identity. The terminal durably records `RELEASE_PENDING` before sending it. A lost response is retried with the same identity.

The bank must make the authority non-vendable durably before releasing any backing hold. The recommended retained state transition is:

```text
ACTIVE -> RELEASE_PENDING -> RELEASED
```

For `RESERVED_ALLOWANCE`, hold release occurs between the two durable authority states. For `DELEGATED_STAND_IN`, there is no Ledger hold, but the same authority lifecycle is useful.

A locally claimed, consumed, quarantined, or physically ambiguous authority must never be returned through this operation.

Stock FederationBank v0.9 does not implement this operation. In that case the Java ATM treats `OPERATION_UNSUPPORTED` as evidence that no bank-side release happened and restores the local authority to `ACTIVE`.

## OFFLINE_WITHDRAWAL_ADVICE

Before a disconnected physical dispense, the terminal journals the authority as `CLAIMED_LOCALLY` and fsyncs that claim before invoking the dispenser. A known zero-cash result may release the claim. Any non-zero result consumes the authority locally; an unknown result after restart quarantines it. This prevents the same bank-issued authority being selected for a second physical vend after a crash.

When cash physically leaves the machine, connectivity recovery sends that physical fact by stable idempotency identity, for example:

```json
{
  "offlineAuthorityId": "OFFAUTH-...",
  "authorityMode": "RESERVED_ALLOWANCE",
  "accountId": "GBP-001",
  "currency": "GBP",
  "amountMinor": 10000,
  "dispensedMinor": 10000,
  "physicalTransactionId": "PHYS-OFFLINE-...",
  "dispensedAt": "2026-08-26T01:42:17.123Z"
}
```

For a partial dispense, `amountMinor` and `dispensedMinor` are both the **actual** cash amount that left the terminal. `requestedAmountMinor` may additionally preserve what the customer originally asked for. The bank must reject a disagreement between the monetary advice amount and physical `dispensedMinor`.

`dispensedAt` is terminal physical evidence, not independent monetary authority. FederationBank v0.9 currently validates authority expiry when advice is processed; the preferred follow-up is to distinguish "authority valid when cash physically left" from "advice arrived later after a network outage" without trusting an unbounded terminal timestamp. Until the bank-side rule is upgraded, delayed post-expiry advice can require reconciliation.

For a partial `RESERVED_ALLOWANCE`, stock FederationBank v0.9 requires the settlement amount to equal the original hold and therefore returns `ATM_HOLD_MISMATCH`. The v0.1.6 compatibility candidate permits settlement of any positive actual cash amount up to the reserved ceiling, releases the unused remainder of the single-use hold, and returns `reservedMinor` / `unusedReservedMinor` as evidence.

## WITHDRAW_AUTHORISE

Request data:

```json
{
  "accountId": "GBP-001",
  "currency": "GBP",
  "amountMinor": 10000
}
```

Expected accepted response data:

```json
{
  "authorizationId": "WDAUTH-...",
  "holdId": "ATM-HOLD-...",
  "amountMinor": 10000,
  "currency": "GBP",
  "expiresAt": "2026-08-25T21:34:00Z"
}
```

The bank should reserve funds using its normal Payments -> Ledger authority path. Authorisation alone is not a posting.

## WITHDRAW_COMMIT

Sent only after the terminal has durably recorded a successful physical dispense:

```json
{
  "sessionId": "SESSION-...",
  "customerId": "CUST-001",
  "accountId": "GBP-001",
  "currency": "GBP",
  "amountMinor": 10000,
  "authorizationId": "WDAUTH-...",
  "holdId": "ATM-HOLD-...",
  "physicalTransactionId": "PHYS-DISP-...",
  "dispensedMinor": 10000
}
```

The gateway must authenticate/derive the customer from the original transaction/session evidence rather than simply trusting the data fields.

The bank should atomically consume the reservation into balanced ATM withdrawal postings and a durable receipt. Repeating this commit with the same idempotency key returns the original result and never debits twice.

## WITHDRAW_CANCEL

Sent if zero physical cash was dispensed. It releases the reservation.

A partial dispense is **not** represented as a normal cancel. The ATM sends `WITHDRAW_EXCEPTION` and leaves resolution to bank reconciliation logic.

## DEPOSIT_COMMIT

The terminal sends this only after physical cash has been accepted and durably journalled:

```json
{
  "sessionId": "SESSION-...",
  "customerId": "CUST-001",
  "accountId": "GBP-001",
  "currency": "GBP",
  "amountMinor": 20000,
  "physicalTransactionId": "PHYS-DEP-..."
}
```

If JMS is unavailable after physical receipt, the terminal preserves exactly the same command/idempotency identity and retries later. The bank must therefore make this operation durable and idempotent.

## Offline rules

The shipped client understands:

```text
offline.balanceMode:
  CACHED_MARKED_STALE
  DENY

offline.withdrawalMode:
  DENY
  BANK_ISSUED_AUTHORITY
  RESERVED_ALLOWANCE
  DELEGATED_STAND_IN

offline.depositMode:
  DENY
  CAPTURE_AND_QUEUE
```

`BANK_ISSUED_AUTHORITY`, `RESERVED_ALLOWANCE` and `DELEGATED_STAND_IN` all deliberately fail closed unless a matching bank-issued authority has been received. A newer signed `DENY` overrides a previously cached unused authority before the dispenser is touched. The client never invents an offline allowance locally. It durably claims the stored authority before invoking the physical dispenser; after any non-zero or uncertain physical outcome the authority cannot be used to vend again.

## Broker trust boundary

The ATM principal should have only the minimum broker rights required for:

```text
PUT    FB.ATM.REQUESTS
GET    FB.ATM.REPLIES.<own terminal>
BROWSE/CONSUME its own durable FB.ATM.RULES subscription
```

It must have no capability to publish to FederationBank Ledger queues.

## Separate brokerage / Merchant Bank enquiry transport (v0.1.9)

The derivatives-position feature does **not** use `FB.ATM.REQUESTS` as though the Retail Bank ATM gateway owned brokerage position truth.

It has a separate read-only contract and may use a separate JMS provider:

```text
FB.BROKERAGE.ATM.REQUESTS
FB.BROKERAGE.ATM.REPLIES.<terminalId>
```

The only v0.1 operation is `GET_MERCHANT_POSITION_SUMMARY`.  The ATM sends bank-authenticated customer/session context but no brokerage account identifier.  Relationship resolution and valuation remain server-side brokerage concerns.

The brokerage response is deliberately not a bank `Balance`: market value, P/L, collateral and available margin cannot feed Retail Bank cash withdrawal availability.

See `BROKERAGE_POSITION_CONTRACT.md` for the full schema.
