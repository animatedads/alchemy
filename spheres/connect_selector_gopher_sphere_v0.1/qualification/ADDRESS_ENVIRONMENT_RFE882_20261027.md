# RFE #882: Rexx ADDRESS environment adapter — admission and qualification

Date: 2026-10-27. Status: **exploratory proof committed; executable qualification pending on a suitable interpreter**.
Scope: ConnectSelector is the operation/mode/destination policy and routing authority. The new ooRexx 5.3.0 command-handler feature is a *Rexx syntax adapter*, not a new transport, policy engine or second dispatcher.

## Grounding and version gates
- Upstream report from Josep Maria Blasco: RFE #882 interpreter r13288, documentation r13290, tests r13291; portable build inclusion from r13289. Follow-up samples `cmdhandlers.cls` and `usecmdhandlers.rex` at r13292/13293; native forwarding repair r13294/95; appendix r13296.
- Hosted instance `StackCommandEnvironment` in r13297, rexxapi documentation r13298, tests r13299; native interface 102 (`INSTANCE_INTERFACE_VERSION_5_3_0`). Check `interfaceVersion` before invoking.
- The existing ConnectSelector dev6 release was qualified against **r13196**. Do not run or claim success for the new handler on that old build; compile/runtime support for `.CommandHandler` is not assumed.
- The above revision information comes from the October 2026 announcement; independently inspect the selected runtime/documentation before promoting it.

## Probe files and execution
- `examples/address_environment/AlchemyAddressProbe.cls`: package-prolog registration of `ALCHEMY_CS_PROBE` in each requiring interpreter instance. Handler uses only `command` and `caller`, does not access caller variables/streams or perform shell execution. Commands: `PING` -> RC 0, `DENY` -> RC 13, unknown -> RC 64.
- `examples/address_environment/probe.rex`: separate client which `::requires` the package, submits the three commands and verifies RC. The source is intentionally small enough to review.
- On a **compatible** test host, run from the example directory:
  ```sh
  rexx -v
  cd spheres/connect_selector_gopher_sphere_v0.1/examples/address_environment
  rexx probe.rex
  ```
  Record ooRexx revision/architecture, stdout, stderr, exit status, and a digest of both source files. The probe is *not* a live ConnectSelector service call.
- A second separately started interpreter process should run the same probe independently. This establishes separate per-instance registration but does **not** establish a single cross-process handler object.

## Production integration contract (not yet implemented)
1. Adapter entry point is `ADDRESS ALCHEMY_CONNECT` (proposed name only; no production registration exists). Use explicit `::REQUIRES` from a registry-resolved, exact-version package path; reject missing/incompatible versions. Do not rely on the caller CWD, arbitrary REXX_PATH precedence, or finding the first duplicate package.
2. Parse a deliberately narrow command grammar into a structured operation request. Preserve argument and payload identity rather than lossy conversion to shell command strings; never interpolate commands into an OS shell.
3. Feed the request into the **existing** ConnectSelector operation/mode/destination admission, never bypassing provider policy even for explicit provider selection.
4. Preserve service ownership: RPC Service Core handles published methods and callbacks, Serialisation Selector handles representations, Queue Fabric owns acceptance/durability, RTO2 owns execution continuity and fencing, SocketSelector decides carrier. JMS acknowledgements follow ConnectSelector's existing directional rules.
5. Return RC only after authoritative completion evidence. For accepted-but-not-completed asynchronous work, do not report successful service completion merely because Queue Fabric accepted an item. An ambiguous outcome must remain explicit; no silent retry.
6. `CommandContext` may access the caller's variables/streams and raise its conditions; gate each of those effects by explicit capability and avoid exposing credentials or internal payloads. The issuing thread is the executing thread; do not block indefinitely while holding application locks.
7. Handler stacking/unstacking must preserve predecessor behavior. Forwarding to a native predecessor requires the upstream r13294+ repair. Unexpected commands fail closed rather than automatically forwarding to shell.

## Qualification matrix still required
- **P0:** RFE #882 build availability, isolated prolog `::REQUIRES` test, repeated load, unknown command, RC/error/condition behavior.
- **P0:** two independent clients in one interpreter and two independently created interpreter instances; inspect `.CommandHandler~environments`, stacking, `deregister`, and original-handler restoration.
- **P0:** command grammar/policy: denied operation, wrong mode/destination, incomplete dependency, invalid schema, credentials excluded from traces.
- **P0:** redirection streams, caller-variable access, ERROR/FAILURE/SYNTAX propagation, native handler forwarding including RC zero/no-result and condition ADDITIONAL.
- **P1:** concurrent activities, long-running/blocking dispatch, cancellations, uncertain RPC/Queue acceptance and RTO2 fencing without duplicate effects.
- **P1:** native embedding uses StackCommandEnvironment only when interfaceVersion >= 102; test older interface fallback/rejection.
- **P1:** independently verify exact portable build and Windows/Android availability.

## Explicitly not claimed
No running ooRexx executable is available in the authoring container. These files have not been executed against r13289+; this is a committed, reviewable candidate and test brief only. No real ConnectSelector provider binding, live JMS broker, distributed environment, or RPC operation has been added.
