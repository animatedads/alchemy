# Alchemy ooRexx convention: argument-driven composition root

**Status:** Captured from Claude (Opus 5.5) `fixture_host.rex` screenshot, 8 November 2026; accepted by the user as a model to preserve. This document records the **processing pattern**, not a claim that this exact excerpt is a complete or tested host.

## The pattern

1. A small ooRexx executable is the *composition root*. It accepts one explicit startup argument, such as `KIT_DIR`, with a deliberate documented default only where appropriate.
2. Resolve a configuration file **relative to that argument**, not relative to arbitrary process state. Load the configuration once.
3. Iterate over an explicit array of required configuration keys; fail immediately and with a useful message if anything is missing. Expand only documented tokens such as `$KIT` in the resolved values.
4. Instantiate the durable/shared domain resource once (e.g. `.FixtureStore~new(conf)`), then pass that same object **as a constructor argument** to the components that must share it.
5. Derive shared addresses/paths centrally and inject them explicitly, along with ports, identity-provider origin, cookie/session names, web assets and other dependencies. Each class's `::method init\n  use strict arg ...` owns its supplied values; it must not re-read the configuration file or reach into unrelated globals.
6. Assemble related service instances into an `.Array` and apply their common setup in one loop (e.g. `do app over .array~of(claude,chatgpt,idp)`). Bind distinct listener configuration per instance while retaining the **same injected** shared state.
7. Keep network listeners loopback-only for fixtures; use the existing Alchemy `.HttpsServerConfig` and `.HttpsServer`, not a Python/Node/Java stand-in.

## Source pattern (transcribed and normalised from the screenshot)

```rexx
parse arg kit
if kit='' then kit=directory()

conf=fxReadProps(kit'/etc/fixtures.conf')
do k over .array~of('claude_port','chatgpt_port','idp_port', -
    'certificate','private_key','bridge_dir','wasm_assets', -
    'test_user','test_password','test_code')
  if conf[k]=.nil then do
    .error~lineout('fixture_host: etc/fixtures.conf has no' k)
    exit 2
  end
  conf[k]=conf[k]~changeStr('$KIT',kit)
end

store=.FixtureStore~new(conf)
idpOrigin='https://127.0.0.1:'||conf['idp_port']
web=kit'/fixtures/web'
claude=.FixtureClaudeShaped~new('fc',conf['claude_port'],store, -
    'fxc_sid',idpOrigin,conf['wasm_assets'],web)
chatgpt=.FixtureChatGptShaped~new('fg',conf['chatgpt_port'],store, -
    'fxg_sid',idpOrigin,conf['wasm_assets'],web)
idp=.FixtureIdp~new('idp',conf['idp_port'],store, -
    'fxi_sid',idpOrigin,conf['wasm_assets'],web)
idp~addApp(claude)
idp~addApp(chatgpt)

servers=.array~new
do app over .array~of(claude,chatgpt,idp)
  config=.HttpsServerConfig~new
  /* Supply per-app bind/port and TLS settings; build server. */
end
```

The screenshot shows the start of the server-construction loop only; its complete server initialisation is **not** reconstructed here.

## House rule / design implications

**Pass arguments downward; do not make dependencies hunt upward.** The executable resolves startup inputs and builds the object graph once. Constructors receive dependencies and validated settings. A component's behaviour must not depend on implicit current-directory paths, secretly selected global singletons, or an undeclared ambient service.

This is explicitly an **ooRexx object-composition discipline**, distinct from forwarding a raw command-line string unvalidated through every layer. It gives predictable wiring, testability, multiple instances in one process and consistent identity/session boundaries.

Security qualification: `test_password` / `test_code` are fixture-only keys. Production secrets belong in the existing protected secret/identity authority, not a broadly readable properties file. Configuration validation should also reject blank and invalid values, not just missing keys; HTTPS listener, session and authorization rules remain enforced by their owning components.

## Application

Apply this convention to the native Rasen Falcon operator desk's server composition, authenticated MCP client, Wire UI binding and user-session components; and to future Alchemy components where one entry point assembles multiple collaborating ooRexx objects. Retain native transports and genuine verified identity instead of replacing them with convenience shims.

**Provenance:** User-supplied screenshot of Claude-created `fixture_host.rex` (8 November 2026), lines 1-31. Architecture credited in that source to Tom Dyer; implementation example credited there to Claude (Opus 5.5).
