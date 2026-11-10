# browser_ui_kit

Drive the Claude and ChatGPT web pages from native ooRexx, test every adapter **signed out and signed on**
against local test fixtures, hand a sign-in over from a person to a headless browser, and fetch
allowlisted documents (SourceForge) for an agent that cannot reach them.

Architecture: Tom Dyer. Coding: Claude (Opus 5.5), 8 November 2026.
Runs on Chromium over the DevTools protocol, with the estate WebSocket client. No Node, no Playwright.
The fixtures' page script runs on Josep Maria Blasco's ooRexx/WASM.

## Layout

| Path | What |
|---|---|
| `src/CdpBrowser.cls` | Chromium over DevTools: launch on a named profile, pages, evaluate, waitFor, click, typeText, clean close |
| `src/UiKit.cls` | `UiSelectorMap`, `UiAdapter` (state, open, conversations, openConversation, send), `UiAdapters` registry, `UiFindings`, `UiHandover` |
| `etc/adapters/*.ui` | each site's landmarks as data, dated; re-capture when a test starts failing |
| `bin/browser-ui.rex` | `doctor`, `adapters`, `handover NAME`, `state NAME`, `conversations NAME`, `capture NAME`, `send NAME [--in TITLE] -- TEXT` |
| `src/FetchForMe.cls`, `bin/fetch-for-me.rex`, `etc/fetch.conf` | fetch-for-me |
| `src/OrderGate.cls`, `src/FetchOrders.cls`, `bin/fetch-order.rex`, `bin/alchemyfetch.rex`, `src/MailboxClient.cls`, `etc/nudge.conf` | the four-step order gate and ALCHEMYFETCH's reader, rules and executor |
| `tests/test_order_gate.rex` | the gate with a fake curl |
| `src/BostonCrabReader.cls`, `etc/fetch.catalogue`, `tests/test_crab_reader.rex` | free-text orders read by Boston Crab |
| `fixtures/` | the test apps: Claude-shaped, ChatGPT-shaped, and an outside identity provider (password, then code) |
| `tests/run_matrix.sh` | starts the fixtures, runs `tests/test_uikit.rex`, stops them |
| `tests/test_cli.rex` | `browser-ui.rex` run through `sh` exactly as typed at a prompt (run by `run_matrix.sh`) |
| `tests/test_fetch.rex` | fetch-for-me against a fake curl |
| `bin/kit.sh` | sets `REXX_PATH` / `LD_LIBRARY_PATH` from `var/kit.env` |

## Setup

```
cp etc/kit.env.example var/kit.env
```

Edit `var/kit.env`: the package directory, Foreign Runtime, Chrome, and if needed `CHROME_FLAGS` and
`BROWSER_PROFILES`. A **flatpak Chrome** may write only inside its own area, so set
`BROWSER_PROFILES=$HOME/.var/app/com.google.Chrome/alchemy-profiles` (a plain Chrome or Chromium needs neither).
Then check the machine before anything else:

```
sh bin/kit.sh rexx bin/browser-ui.rex doctor
```

`doctor` checks every path, then launches Chrome headless on a scratch profile and evaluates `6*7` over
DevTools. A STOP says exactly what to fix.

The test fixtures also need `var/fixtures.local.conf`:

```
bridge_dir=<packages>/oorexx_https_server/bridge
wasm_assets=<an ooRexx/WASM web build: the 7 files of build-wasm/bin-web>
```

Every script is run through `sh`, so a copy that has lost its execute bits still works.

## Signing in: the hand-over

```
sh bin/kit.sh rexx bin/browser-ui.rex handover claude
```

A visible browser opens on `~/.config/alchemy/browser-profiles/claude` (mode 700). **You** sign in: Google,
then the authenticator. The kit types nothing; it only watches the page state:
`SIGNED_OUT` → `AWAY` (at Google) → `SIGNED_ON`. Once you are signed on it closes the window, so the profile is
written. It then opens the same profile headless and checks that it is signed on, and records the result in
`var/handover.tsv`. The profile holds your session cookies, so treat it like a password.

## The test matrix

```
sh tests/run_matrix.sh
sh bin/kit.sh rexx tests/test_fetch.rex
```

For each adapter, pointed at its fixture:

- **signed out:** the state is `SIGNED_OUT`, and send refuses with a STOP that names the hand-over;
- **hand-over:** a simulated person signs in through the test identity provider on a second DevTools
  connection while `UiHandover` watches;
- **signed on:** three conversations are listed, one is opened by title, and two sends each return their own
  streamed reply;
- **profile:** a new headless browser on the same profile is signed on;
- **sign-out:** `/logout` returns the state to `SIGNED_OUT`.

The matrix also tests the fixture's own password form and two safety checks.

Results 8 Nov 2026 (container): **39/39** browser tests and **25/25** fetch tests.

The fixtures copy only page *structure* (the landmarks the adapters read). They have a neutral look, a TEST
FIXTURE banner and test accounts only. `--ignore-certificate-errors` is set only by the tests (the
fixtures' self-signed 127.0.0.1 certificate) and is never the default.

## Adapter status

| Adapter | Signed out | Signed on |
|---|---|---|
| chatgpt | NOT yet captured (`/auth/login`, `login-button` assumed) | captured 8 Nov; the reply-text container needs confirming |
| claude | captured 8 Nov | **from memory, unverified**: capture after Tom's hand-over |

## Declared automation

Every page that `state`, `conversations`, `send` or `capture` opens says it is automated. The kit
**appends** a token to the browser's own user agent, and never removes anything the browser says about itself:

```
AlchemyAgent/0.1 (LLM-driven request; requested-by=CLAUDE; +https://rasenfalcon.com)
```

- **requested-by** is the agent that asked: `--for AGENT`, else `AGENT_REQUESTED_BY` in `var/kit.env`. With
  neither, it is `operator` and the token says `scripted request`.
- The contact address is `AGENT_CONTACT` (default `https://rasenfalcon.com`).
- The token is recorded in `var/events-YYYYMMDD.log`.
- The hand-over carries no token: a person signs in.

The kit does not imitate a person. It never hides automation, answers bot checks or mimics a human's typing
rhythm. A site that refuses declared automation has decided, and its own API is the route there. For fields
that act on key events (search boxes with suggestions), a map can set `typing=keys`: real key events at a
steady `key_interval_ms`.

## ALCHEMYFETCH and the OrderGate

Every instruction ALCHEMYFETCH receives is handled as an order, in four steps (`src/OrderGate.cls`, generic,
so other recipients can use it too):

1. **Is it an order?** The reader says CLEAR, REQUIRES CLARIFICATION or NOT AN ORDER. Today ALCHEMYFETCH reads
   `FETCH URL` and `FETCH svn URL`. Free text goes to Boston Crab once it reads fetch orders; until then it is
   REQUIRES CLARIFICATION, never a guess.
2. **Is it lawful?** Legal Effect v0.14 (ChatGPT) evaluates `FETCH_URL` against a sealed rule generation built
   from `etc/fetch.conf`:
   - **ROE-ISSUER**: only `order_issuers` may order a fetch;
   - **ROE-HTTPS**: HTTPS only;
   - **ROE-HOST**: allowlisted hosts only;
   - **ROE-KIND**: allowed kinds only;
   - **ROE-URL**: no shell metacharacters in the address.

   Each rule is a prohibition with a condition, so a fact that couldn't be established gives REVIEW_REQUIRED,
   referred to TOM.
3. **Execute.** Only CLEAR plus ADMISSIBLE runs. Every redirect is a new target, assessed again before it is
   followed. The hard checks in `FetchRun` stay as the last safety.
4. **Report.** Both verdicts, the deciding rules, the decision-trace id (the sha256 of Legal Effect's trace,
   kept under `<store_dir>/traces`) and the result.

**Free text (Boston Crab v0.21+, `src/BostonCrabReader.cls`).** When `BOSTON_CRAB_DIR` in `var/kit.env` names a
compiled copy of Boston Crab, an order that isn't the exact `FETCH URL` form is read by Boston Crab:

- The situation comes from `etc/fetch.catalogue` (`NAME|SITE|URL`): "SITE was a website." and "The NAME was on
  SITE.".
- A `url` reference is fetched as written. A named document is fetched only if its name is in the catalogue
  exactly; its address comes from there, never from a guess.
- An order that only says what not to do is NOTED: recorded, with nothing to execute.
- Anything Boston Crab doesn't find CLEAR goes back to the sender in Boston Crab's own words.
- Without `BOSTON_CRAB_DIR`, free text gets REQUIRES CLARIFICATION.

```
sh bin/kit.sh rexx bin/fetch-order.rex --from CLAUDE --id req-1 -- FETCH https://sourceforge.net/...
sh bin/kit.sh rexx bin/fetch-order.rex --from CLAUDE -- Fetch the ooRexx README.
sh bin/kit.sh rexx tests/test_order_gate.rex
sh bin/kit.sh rexx tests/test_crab_reader.rex
```

Needs `legal_effect_v0.14` and `alchemy_objects_v0.8` under `ALCHEMY_PACKAGES`.

### The inbox loop (`bin/alchemyfetch.rex`)

ALCHEMYFETCH reads its own mailbox. For each unread request addressed to it, it:

1. puts the request through the OrderGate (the issuer is the sender);
2. replies to the sender with the report;
3. marks the request read;
4. nudges the sender's chat, if `etc/nudge.conf` maps the request's lane (`LANE|ADAPTER|CONVERSATION TITLE`).

The nudge carries only the request id: "The event you registered a request for REQ-… has occurred, check Rasen Falcon MCP." A request that was already answered (a mark-read that failed) is marked read and nothing more, so it is never executed twice.

- The token lives in `token_file` (default `~/.config/alchemy/alchemyfetch.token`). The file must be mode 600 or 400.
- curl reads the Authorization header from a mode-600 file on stdin, so the token is never on a command line.
- Settings: `mailbox_url`, `token_file` and `poll_seconds` in `etc/fetch.conf`, overridden by `var/fetch.local.conf`.

```
sh bin/kit.sh rexx bin/alchemyfetch.rex --once      # one pass, then stop
sh bin/kit.sh rexx bin/alchemyfetch.rex             # keep polling
sh bin/kit.sh rexx tests/test_alchemyfetch.rex      # fake mailbox, fake curl, fake nudge
```

## Fetch-for-me ("excuse me, can you read me this document?")

```
sh bin/kit.sh rexx bin/fetch-for-me.rex REQ-ID URL [svn] [--for CLAUDE]
```

- Fetches only `https://` URLs on allowlisted hosts (`etc/fetch.conf`: sourceforge.net, svn.code.sf.net,
  downloads.sourceforge.net and their subdomains).
- Follows every redirect **by hand** and checks it: a redirect to an unlisted host stops the fetch.
- Has a size limit. Nothing fetched is run or unpacked.
- Stores the result in `~/alchemy-autobuild/fetched/REQ-ID/` (mode 700): the file, `SHA256SUMS`,
  `excerpt.txt` and `reply.md`, plus a row in `fetch-ledger.tsv`.
- `reply.md` is the text that goes back to the asker. It is marked as data, not instructions.

The mailbox principal for this is ALCHEMYFETCH (since 10 Nov 2026): `bin/alchemyfetch.rex` posts the report and nudges
the sender's chat (see "The inbox loop" above).

## Package and acceptance

The kit is published as `packages/oorexx_browser_ui_kit_v0.1` through Autobuild's Git intake (`integration.json`).

- `run_tests.sh` copies the package to a temporary folder and runs there, so no test output reaches the
  published tree. It takes its dependencies from the repo's `packages/` folder (`ALCHEMY_REPO_ROOT`).
- Always run, with no network and no browser: fetch, order gate, the ALCHEMYFETCH inbox loop, and the Boston Crab
  reader (which skips unless `BOSTON_CRAB_DIR` names a compiled Boston Crab).
- The browser matrix (Chromium plus the local fixtures, signed out and signed on) runs only when
  `KIT_BROWSER_TESTS=1`, `CHROME` and `KIT_FIXTURES_CONF` are set. A browser that cannot start under a service
  must not become a final FAIL receipt.
- A working copy needs `var/kit.env` (copy `etc/kit.env.example`). `var/` is never published.

```
ALCHEMY_REPO_ROOT=~/alchemy-autobuild/repo sh run_tests.sh
```

## Credits

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Legal Effect v0.14 (the OrderGate's rules engine): ChatGPT.
Boston Crab (reads free-text orders): its own chat. ooRexx/WASM: Josep Maria Blasco. HTTPS server, WebSocket
client, socket provider, crypto: the alchemy estate packages.
