# Changelog

## 0.1.9

- Added the State-Bank-of-NSW-inspired `Merchant Bank derivatives position` ATM enquiry as a strictly read-only feature.
- Kept brokerage/merchant-bank position truth outside the FederationBank retail Ledger and outside `AtmService`; a separate `BrokerageNetwork` transport can use a different JMS provider and destinations.
- Added `GET_MERCHANT_POSITION_SUMMARY` using the dedicated `federationbank.brokerage.atm.*` wire schemas.
- The ATM sends authenticated retail customer/session context but **no brokerage account identifier**; brokerage owns customer-to-relationship linkage.
- Replaced an early individual-position client model with the narrow `MerchantPositionSummary` projection: market value, P/L, collateral/margin, position count, valuation time/status and source authority only.
- Added no trade/close/exercise/margin-transfer operation and no path from merchant position values into retail withdrawal availability.
- Brokerage data is online-only in v0.1.9 and is not written to the ATM transaction journal; if the source is unavailable the ATM refuses to present an old valuation as current.
- Added independent demo bank/brokerage connectivity toggles and a linked Australian demo customer.
- Added separate JNDI/JMS brokerage configuration and `BROKERAGE_POSITION_CONTRACT.md`.
- Added regressions proving brokerage-account selection is absent from the wire, brokerage relationship resolution is source-owned, a large derivatives valuation cannot change Retail Bank cash availability, and a brokerage outage leaves the bank path operational.
- Retained the v0.1.8 signed-rule gate and added its missing regression: a newer signed `DENY` overrides a previously cached unused offline authority before any physical vend while still allowing the unused reservation to be returned.
- Java acceptance/regression suite expanded to 22 tests.

## 0.1.8

- Enforced signed `offline.withdrawalMode` before offline-authority acquisition and before the disconnected dispenser lifecycle.
- Added `BANK_ISSUED_AUTHORITY` semantics: the signed rule permits the mechanism, but a matching bank-issued single-use authority is still mandatory.
- Exposed `Reserve funds for offline cash` and `Return unused offline cash authority` in the normal text-mode account menu.
- Demo rules now use `BANK_ISSUED_AUTHORITY` so the offline lifecycle can be exercised interactively without weakening the rule + authority dual gate.
- Qualified a separate FederationBank v0.9 passive-expiry/late-evidence candidate; that bank candidate remains a bank-side follow-up rather than ATM monetary authority.

## 0.1.7

- Added explicit `RELEASE_OFFLINE_ALLOWANCE` client support so an unused bank-issued offline authority can be returned before customer LOGOFF.
- Release is crash-safe and idempotent: the terminal journals `RELEASE_PENDING` before the bank request and replays the exact release identity after a lost reply.
- Session LOGOFF is deferred while `RELEASE_PENDING` / `RELEASE_RECONCILIATION_REQUIRED` remains unresolved.
- Backward compatibility with stock FederationBank v0.9 is fail-safe: `OPERATION_UNSUPPORTED` restores the local authority to `ACTIVE` rather than pretending the bank released its hold.
- Reproduced the stock v0.9 unused-reservation lifecycle gap: a never-used `RESERVED_ALLOWANCE` remains `ACTIVE` after LOGOFF and its Ledger hold remains active indefinitely.
- Added a narrow bank candidate implementing durable two-phase authority release (`ACTIVE -> RELEASE_PENDING -> RELEASED`) with idempotent backing-hold release.
- Qualified bank restart at `RELEASE_PENDING`: retained authority state rebuilds correctly, hold release resumes, and replay is harmless.
- Java acceptance/regression suite expanded to 18 tests.

## 0.1.6

- Fixed an offline cash authority crash window: a bank-issued authority is now fsynced as `CLAIMED_LOCALLY` before the physical dispenser is invoked.
- A durable zero-cash dispenser result may safely return the local authority to `ACTIVE`; any non-zero cash consumes it locally.
- Restart after offline `DISPENSE_STARTED` with no durable device result now marks the physical transaction `RECONCILIATION_REQUIRED` and the authority `QUARANTINED_LOCALLY`; it can never be selected for a second vend.
- Partial offline cash now carries the actual `amountMinor`/`dispensedMinor` while retaining `requestedAmountMinor` as customer-intent evidence.
- Added Java regressions for zero-cash claim release, delegated partial settlement, reserved partial settlement candidate semantics, and power-loss authority quarantine; suite is now 16 tests.
- Reproduced a FederationBank v0.9 reserved-partial gap: a 10000 hold followed by a 5000 physical dispense returns `ATM_HOLD_MISMATCH` and strands the original hold.
- Added a narrow v0.9 bank candidate patch permitting partial reservation consumption up to the reserved ceiling, releasing the unused single-use reservation and returning `reservedMinor` / `unusedReservedMinor`.
- Added bank-side rejection of `amountMinor` / `dispensedMinor` disagreement before monetary settlement in the candidate patch.
- Qualified the candidate against the delivered dev7-fb1/Queue Fabric path plus existing ATM protocol, money, offline-authority, mandatory-settlement and hold-lifecycle regressions.

## 0.1.5

- Accepted the delivered `oorexx_jms_queue_bridge_v0.1-dev7-fb1` dependency and independently re-ran its full deterministic suite under ooRexx 5.3.0 r13196 + BSF4ooRexx v850.
- Reproduced the unpatched FederationBank v0.8/v0.9 `.JsonString` durable-payload failure and retained version-specific compatibility patches for the ATM JSON boundary.
- Added a FederationBank v0.9 composed JMS-shaped acceptance path covering `GET_OFFLINE_ALLOWANCE`, Ledger-backed reserved allowance, reconnect `OFFLINE_WITHDRAWAL_ADVICE`, replay safety and single-use authority rejection.
- Added `dispensedAt` to durable offline-withdrawal physical evidence.
- Server-side LOGOFF is now deferred while an offline-withdrawal advice or reconciliation fact remains session-bound, matching the existing deposit/cancel protection.
- Added regression coverage for offline-advice LOGOFF protection; Java suite is now 12 tests.
- Documented a FederationBank v0.9 semantic follow-up: authority expiry should be evaluated at physical dispense time, not at delayed advice-arrival time, once the bank accepts trusted physical-time evidence.

## 0.1.4

- Fixed the dependency-free JSON parser so integer JSON tokens remain `Long` values after parsing instead of being promoted to `Double` by Java conditional-expression numeric promotion.
- Added a regression proving the exact FederationBank v0.8 Ed25519 rule signature survives a real JSON stringify/parse wire round-trip; signed `50000` can no longer become canonical `50000.0`.
- Bounded outbound `requestedAt` timestamps to millisecond precision for cross-language compatibility with ooRexx `DateTime~fromIsoDate`; command/idempotency identity remains independent of wall-clock precision.
- Qualified the real transport path with Java 21, ActiveMQ 5.18.3, BSF4ooRexx v850, ooRexx 5.3.0 r13196, recovered JMS Queue Bridge v0.1-dev7-fb1 and FederationBank v0.8 plus its JSON-boundary compatibility patch.
- Real end-to-end qualification covered terminal sign-on, signed rules, logon, account listing, balance, WDA hold/authorisation, WDM physical-dispense commit, deposit commit, final balance and logoff.
- Retains v0.1.3 bank-issued offline-authority support for FederationBank v0.9 unchanged.

## 0.1.3

- Added FederationBank v0.9 GET_OFFLINE_ALLOWANCE client support.
- Durably journals bank-issued RESERVED_ALLOWANCE / DELEGATED_STAND_IN authority envelopes.
- Added real disconnected vending only when a valid bank-issued terminal/customer/account/currency/rules-bound authority exists.
- Offline dispense is irreversible physical evidence and is replayed as OFFLINE_WITHDRAWAL_ADVICE after reconnection.
- Authority is consumed locally before advice upload to prevent a second physical dispense.
- Preserves fail-closed behaviour when no valid authority exists.

## 0.1.2

- Added FederationBank v0.8 composed Queue Fabric/JMS-shaped acceptance harness.
- Added a deterministic provider that exercises `JMSQueueBridgeService` inbound
  and outbound settlement without replacing any banking logic.
- Qualified terminal sign-on, logon, balance, withdrawal hold/commit, deposit,
  response correlation, Queue Fabric transfer-ID duplicate suppression and bank
  monetary idempotency as one composed path.
- Found and documented a FederationBank v0.8 wire-only persistence defect:
  `json.cls` `.JsonString` wrappers could reach durable payment details.  Added
  the minimal bank-boundary compatibility patch used for qualification.
- Bumped the terminal sign-on software version to 0.1.2.
- Added a Java wire-shape regression asserting identifiers/evidence remain JSON
  strings while rule versions and money remain JSON numbers/minor units.
- Live BSF4ooRexx/JMS broker qualification remains pending provider runtime jars
  and broker configuration; it is not conflated with the deterministic composed
  qualification.


## 0.1.1 - 2026-08-26

FederationBank v0.8 compatibility cut.

- reviewed and mapped the new bank-side `FederationBankAtmGateway`;
- added public v0.8 demo compatibility constants and optional fixture-rule-key configuration;
- added an exact cross-language Ed25519 rule-signature vector using the bank's ooRexx fixture;
- added replay of `CANCELLATION_PENDING` withdrawal holds after a lost bank connection;
- recover physical-cash work before server-side LOGOFF and defer bank LOGOFF while a session-bound deposit/cancel fact remains pending;
- documented the remaining JMS Queue Bridge deployment boundary;
- documented the v0.8 logged-off-session deposit-recovery edge for the bank side;
- expanded executable tests from six to nine.

## 0.1.0 - 2026-08-25

Initial runnable Java ATM cut.

- text-mode customer UI and optional ANSI FederationBank roundel;
- bank-network transport abstraction;
- runnable in-process demo network;
- broker-neutral JNDI/JMS request/reply transport without compile-time broker dependency;
- signed Ed25519 terminal rules;
- logon/logoff, account list and balance;
- hold-style withdrawal authorisation, physical dispense, commit/cancel/exception lifecycle;
- physical deposit and idempotent commit/pending-upload lifecycle;
- durable local JSONL journal and terminal sequence;
- restart recovery that cannot blindly repeat a dispense;
- fail-closed offline withdrawal semantics and capture-and-queue offline deposit semantics;
- FederationBank v0.6 mapping and ATM JMS contract;
- six executable acceptance/regression tests.
