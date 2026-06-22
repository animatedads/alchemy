# Gateway/EventController log review

Reviewed the gateway log plus `alchemy_gateway(26).zip`.

## 1. Highest-risk issue: collector registration race

`HttpGateway~handleMessage` currently does:

```text
post MSG into EventController
EventController fans out to subscribers
stub agents may post RESPONSE immediately
only after post returns: collector~expect(eid,...)
```

The log shows RESPONSE posts beginning before the gateway reaches `collector~expect`:

```text
[EC] post called token=EVENT|{"src":"CLAUDE"...
[EC] post called token=EVENT|{"src":"CHATGPT"...
[EC] post done, returning eid=USE-...
[GW] calling collector~expect...
```

In this run the RESPONSE fan-out happened late enough that the collector caught them, but this is timing-dependent. A faster handler can deliver a RESPONSE before `_pending[eid]` exists; `GatewayCollector~collect` will then return and the response is lost.

Recommended fix: register pending before subscriber fan-out. Options:

- EventController provides `reserve/postWithReservedId` or `postAndExpect`.
- Gateway creates a request id first, registers collector under that id, sends it as root/crf, and responders use that request id.
- EventController offers a hook/callback after stamping eid but before `fanOut`.

Do not rely on `post()` returning before agents respond.

## 2. `txt=a Directory` likely comes from JSON parser path, not the event wire itself

The mesh node log says:

```text
[CLAUDE] msg knd=MSG txt=a Directory
[CHATGPT] msg knd=MSG txt=a Directory
```

`EventWireFormat~deserializeEvent` first tries:

```rexx
parsed = .json~fromJson(json)
ev["text"] = self~jget(parsed, "txt", "")
```

`jget` coerces whatever comes back with `"" || v`. If `parsed["txt"]` returns a Directory-like object from the runtime JSON package, it becomes the literal string `a Directory`.

For this flat `EVENT|{...}` envelope, prefer the manual field parser first, or harden `jget` so scalar fields must be strings/numbers and object values fall back to manual extraction.

Minimal safe direction:

```rexx
/* in deserializeEvent */
ev = self~deserializeEventManual(json)
if ev \= .nil then return ev
/* only then try .json~fromJson as fallback */
```

This should remove the `txt=a Directory` symptom.

## 3. Demo has both direct subscribers and mesh broadcast

`gateway_demo.rex` subscribes stub agents directly to `MSG`, then also subscribes `MeshBroadcaster` to `MSG`.

That is fine for a diagnostic demo, but production should choose one authority path:

```text
EventController -> direct local subscribers
or
EventController -> MeshBroadcaster -> mesh agents
```

Do not let the same real agent be both an EC direct subscriber and a mesh receiver unless duplicate handling is explicit.

## 4. SYNC response ownership is split

`GatewayCollector~expect` starts a timeout watcher for SYNC/STREAM. But `HttpGateway~handleMessage` also does its own poll loop and then calls `sendSyncDirect` and `clear`.

That means two code paths can decide to write/close the same socket:

```text
GatewayCollector~watchTimeout -> flush -> sendSyncResponse
HttpGateway poll loop -> sendSyncDirect
```

Pick one owner. Either collector owns flushing, or gateway owns polling/sending and `expect` should not start a watcher in that path.

## 5. SYNC mode is really first-response-plus-grace, not wait-for-all

The poll loop leaves as soon as `responses~items > 0`, sleeps 0.3 seconds, then sends. That can miss slow agents.

If the intended mode is “all agents or timeout,” collector needs `expected_count` or a completion policy. Otherwise document the mode as “first response plus grace window.”

## 6. JSON output escaping is not JSON escaping

Several response builders use doubled quotes:

```rexx
txt = changestr('"', txt, '""')
```

JSON needs backslash escaping:

```text
"  -> \"
\  -> \\
LF -> \n
CR -> \r
TAB -> \t
```

The current output will break if an AI response contains quotes or backslashes.

## 7. SSE chunk JSON has a typo

In `GatewayCollector~streamChunk`, the chunk string appears to miss the closing quote after agent:

```rexx
'{"agent":"' || src || ',"text":"' || txt || '"}'
```

It should be:

```rexx
'{"agent":"' || src || '","text":"' || txt || '"}'
```

## Priority order

1. Register pending request before response fan-out can happen.
2. Fix EventWireFormat scalar extraction / prefer manual parser for flat events.
3. Decide who owns SYNC socket completion.
4. Add expected-count/timeout policy.
5. Fix JSON escaping and SSE typo.

Short version: the event spine is working, but there is a collector race and a JSON-deserialization scalar bug. Fix those before debugging mesh routing.
