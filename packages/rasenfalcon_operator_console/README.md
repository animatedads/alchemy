# Rasen Falcon Operator Console (ooRexx)

Status (2026-11-07): source candidate only; **NOT DEPLOYED or OPERATIONAL**.

This operator-only localhost application lets a human operator inspect Rasen Falcon requests and threaded enquiries and reply or explicitly record a decision. Architecture: native Alchemy Wire UI renderer → WireUIServer v0.17 → Queue Fabric / native browser gateway → RFOperatorWireApplication → RFOperatorMailbox → authenticated native Rasen Falcon MCP client. No Python, Node, fake browser authority or direct HTTP access to MCP credentials.

Development source candidate `rasenfalcon_operator_console_v0.1-dev2.zip` was produced in the ChatGPT project conversation (SHA256 `6a95a92acdba952c425833658a9d6c75b2bcf951729c0ed9cc72cce1646781e9`). This GitHub entry is only an integration handoff; it does **not** represent source publication of the ZIP or a deployed program.

The native ooRexx domain contract requires `principal()`, `requestsList(unreadOnly)`, `markRead(requestId)` and `requestReply(requestId,body,requestType)` returning `.RFOperatorResult` objects. Current MCP backend operations: `project.requests.list`, `project.request.mark_read`, `project.request.reply` from `packages/oorexx_mcp_service_v0.2-dev8`. Caller must be a verified human principal, never the CHATGPT connector. Confirm/decline are append-only request replies, **not** job execution.

Must pass prior to production: operator principal authentication and CA trust, real native HTTPS MCP transport, compiled semantic release, native localhost HTTP/WebSocket access, CSRF/Origin/session expiry, real live request/reply verification, stale duplicate replay and privilege-denial regression tests. No authorisations are sent as part of smoke tests.

Rasen Falcon lane: `rasenfalcon-operator-console`; integration handoff `REQ-00003309`, `REQ-00003317`.

## Browser implementation v0.1-dev4-ui (2026-11-08)

The previous source-only limitation is addressed in the **UI source candidate**, delivered to the ChatGPT Library at `/rasenfalcon_operator_console_v0.1-dev4-ui.zip` (Library ID `libfile_13409f76f8ac819193e6a1606a72219e`, SHA-256 `a694d4136aa84c79ff1273488b4f7b6f4e27fe03159955905420cab8a05674fb`). This is an archive handoff, **not** a claim of deployment. Source includes native `RFOperatorWebController.cls`, `RFWebCodec.cls`, `RFOperatorHttpsBinding.cls`, `RFRemoteMcpTransport.cls` (Alchemy API Client), `RFOperatorRuntime.cls`, CSS and `bin/serve_fixture.rex`. Implements an actual server-rendered browser inbox, search/filter, threaded request details, read receipt, reply, review and confirm/decline forms. Zero Python/Node/JS runtime. The fixture launcher serves the UI on loopback with synthetic records but disables writes. Live mode requires HTTPS client cert admission, verified operator identity and a qualified native API Client/MCP client certificate route. Native tests and actual localhost remote qualification remain outstanding. Rasen Falcon coordination: REQ-00003369.


## Native Gopher / SSC browser integration — v0.1-dev5 (10 November 2026)

**Artifact**: ChatGPT Library `/rasenfalcon_operator_console_v0.1-dev5-integrated.zip` (Library ID `libfile_2ecc628b1774819180326587ef2765ae`, SHA-256 `c1ab01f2b00d07c37edf8a637a3569351d9b4486a871e5531a861389dde7800b`). This is a complete native ooRexx source/preview archive, not a live deployment or a GitHub source import.

The original localhost HTML/CSS browser UI gains `/spheres`, `/sphere`, `/ssc` and read-only `POST /ssc/manifest`. A new `RFOperatorKnowledge.cls` projects Gopher catalogue and provenance through existing `project.components.list(componentKind=sphere)` and `sphere.check` tools, and projects SSC exact `source.history`, `source.objects_in`, and `source.get_package` through an **injected** `SemanticSourceMcpOperations`-compatible source authority. Accepted package results return a manifest summary, never source bytes to the browser. Both source authorities are independent from Rasen Falcon request/approval; no implicit SSC revision acceptance, branch mutation or deployment is allowed.

The UI adds exact component-scoped inbox links from sphere cards; request details use direct SSC links **only when** the authoritative record explicitly supplies `sscObjectId`. Arbitrary component strings are not rewritten as semantic source IDs. The archive contains two headless-Chromium static preview screenshots and read-only native fixture sources/tests. Native tests and authenticated host rollout are **NOT EXECUTED** here.

**Backend status observed** via Rasen Falcon connector on 10 Nov: project sphere component catalogue returned zero entries, and `sphere.check` failed with `SPHERE_CHECKER_UNAVAILABLE`. No qualified remote SSC dispatch endpoint was verified. The console surfaces these errors instead of claiming live Gopher/SSC. An operator host must bind real Gopher checker, accepted source store, authenticated human identity, and native HTTPS and run qualified field tests before enabling use. See archive `docs/GOPHER_SSC_INTEGRATION.md`.
