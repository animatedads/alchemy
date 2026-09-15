# FederationBank Staff Wire UI v0.1

Early server-authoritative Wire UI for FederationBank Staff Banking.

This is intentionally a small first operational surface, not a replacement for Staff Authority, Method Permission, Access Control, authentication, Core Banking, Relationship authority, or Ledger truth.

## First UI cut

The workspace exposes:

- server-owned staff/session/branch/desk context;
- durable Staff Channel work summary;
- filterable/selectable work list;
- exact work detail;
- a narrow `CUSTOMER.TRANSFER.SUBMIT` form.

The browser is never trusted to supply staff identity, session identity, branch, desk, channel or authority. For transfer submission the server:

1. validates the browser's bounded customer-instruction fields;
2. constructs an exact semantic payload identity using server-owned session context;
3. requires a separate Staff Method Permission admission for that exact payload;
4. constructs a sealed Staff Channel request on the server;
5. submits it to Staff Channel, which independently asks Staff Authority and then Core Banking as applicable.

A visible/enabled UI action is not authority.

## Wire UI release

- site/release: `FEDERATIONBANK_STAFF_BANKING` / `2026.08.28.1`
- workspace: `FB.STAFF.WORK`
- definitions: 7

## Preview

Run `./start.sh` and open the shown local URL. The default is a non-authoritative visual preview. Use `./start.sh --live ...` to attach the thin browser shell to a real Wire UI bootstrap. `FederationBankStaffWireWebGatewayService` provides the ooRexx-side Queue Fabric/Wire UI server seam; see `docs/DEPLOYMENT.md`.

## Validation

Run `./run_tests.sh` with the exported dependency paths named at the top of that script. The packaged acceptance run covers the server-authoritative core, actual r13196 Security Manager method-permission path, runtime/gateway surface, browser bootstrap shell, preview boundary and starter.
