# FederationBank v0.8 ATM Gateway Feedback

Client tested: FederationBank Java ATM v0.1.1
Bank reviewed: `federationbank_engine_v0.8.zip`

## Good fit

The gateway matches the ATM protocol closely and preserves the intended authority split. In particular:

- ATM is a channel, never a direct Ledger client;
- `WITHDRAW_AUTHORISE` creates a hold without book movement;
- physical dispense remains terminal-owned evidence;
- `WITHDRAW_COMMIT` consumes the hold and creates balanced ATM withdrawal postings;
- `WITHDRAW_CANCEL` releases the hold without book movement;
- `DEPOSIT_COMMIT` records balanced physical-cash/customer postings;
- internal ATM cash accounts are derived bank-side;
- replay is idempotent;
- the v0.8 Ed25519 rule fixture verifies exactly in Java.

## Recovery edge to fix bank-side

`FederationBankAtmGateway` calls `sessions~resolve(req["sessionId"], .true)` for `DEPOSIT_COMMIT` and `WITHDRAW_CANCEL`. `allowExpired=.true` bypasses time expiry, but `FederationBankAtmSessionAuthority~resolve` still rejects sessions with status other than `ACTIVE`.

That means a server-side `LOGOFF` can make later replay of already-accepted physical cash fail with `SESSION_INVALID`.

Suggested rule:

> Once the ATM has durably recorded an irreversible physical cash fact under a previously authenticated session, recovery/settlement authority must survive expiry or logoff of the interactive session.

A durable bank-issued physical-operation/recovery authority would be cleaner than keeping the original session alive.

The Java v0.1.1 client contains a defensive compatibility workaround: it attempts pending physical recovery before LOGOFF and defers server-side LOGOFF while a session-bound deposit/cancel remains recoverable.

## JMS deployment boundary

The engine exposes `FederationBankAtmGateway~processBridgeMessage(JMSBridgeMessage)` and declares `ooRexx JMS Queue Bridge v0.1-dev7-fb1` as a dependency. The standalone v0.8 engine ZIP does not itself define/start a broker listener for `FB.ATM.REQUESTS` or the per-terminal reply queues.

That is fine as an adapter boundary, but the deployable integration still needs an explicit JMS Queue Bridge/provider binding and ACL configuration.

## Next useful bank slice

The existing `OFFLINE_WITHDRAWAL_ADVICE` mandatory-settlement path is appropriate for cash that has already left the machine. The next useful endpoint addition remains bank-issued bounded offline authority (`RESERVED_ALLOWANCE` or equivalent), with durable authority identity, expiry, amount remaining and reconciliation.

The terminal should never manufacture that authority locally.
