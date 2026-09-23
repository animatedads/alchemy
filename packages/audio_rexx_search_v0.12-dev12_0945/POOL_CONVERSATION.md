# ED209 pool conversation / evidence loop

The ED209 pool is not a collection of independent brute-force workers that never exchange what they learn. v0.12-dev8 uses **ed209h** as stable public HTTPS ingress and durable conversation/evidence rendezvous, while controller/ed209c is the first natural coordinator (“bigger monkey”).

## Evidence is not execution authority

The separation is deliberate:

- `audio.pool.observation/1` is read-only evidence: results, Pareto frontiers, voice detections, hypotheses, requests, replies, reviews and warnings.
- `audio.h.refinement.control/2` is an admitted H work instruction and enters the durable `/v1/jobs` spool.
- a conversational `REQUEST` never mutates a worker or authorizes execution merely because it says REQUEST;
- a coordinator consumes observations and may emit a separate explicit admitted job.

This follows ooRexx Observation v0.5: semantic observation sequence, delivery/checkpoint identity and execution authority are distinct concepts.

## H roles

`ed209h` has three separate roles:

1. **HTTPS ingress** — ooRexx HTTPS Server v0.4.4 on the public Vultr host.
2. **Observation hub** — durable worker conversation backed by ooRexx Observation v0.5 semantics.
3. **Strategy H refinement** — separate single serial DSP worker draining the H job spool.

The HTTPS process authenticates, validates, durably commits and responds. DSP is never performed in a request handler.

## Endpoints

- `GET /v1/health`
- `GET /v1/capabilities`
- `POST /v1/jobs` — authoritative admitted H refinement instruction
- `GET /v1/status?job_id=...`
- `POST /v1/observations` — evidence/conversation publication
- `GET /v1/observations?node_id=ed209a&after=0&max=50` — bounded replay
- `GET /v1/streams`

All endpoints are behind the HTTPS authorization interceptor.

## Observation envelope

```text
schema=audio.pool.observation/1
message_id=obs-a-001
node_id=ed209a
kind=VOICE_DETECTED
thread_id=campaign-0945-quality-v1
in_reply_to=
candidate_id=ed209a:A:<pcm-hash>
score=4.21
summary=voice-like structure is audible but not yet intelligible
evidence_ref=collected_results/ed209a/rank_01.wav
```

Supported kinds are `RESULT`, `VOICE_DETECTED`, `FRONTIER`, `HYPOTHESIS`, `REQUEST`, `REPLY`, `CAPABILITY`, `REVIEW`, `WARNING` and `STATUS`.

Large evidence remains in artifacts referenced by `evidence_ref`. `message_id` is idempotent: exact replay returns the existing sequence; changed content under the same ID returns `MESSAGE_ID_CONFLICT`.

## Pareto conversation

ooRexx ML dev5 gives the coordinator independent objective evidence rather than one magic score. `publish_collected_observation.sh` therefore publishes, when available:

- a `RESULT` carrying the historical scalar winner, clearly described as experimental pending perceptual calibration;
- a separate `FRONTIER` carrying the front-1 count and a bounded summary of up to three non-dominated candidates, with `pareto_candidates.tsv` as evidence.

The frontier objectives remain `reference_distance`, `pre_limiter_over_fraction` and `post_limiter_clip_fraction`. In dev12, `reference_distance` is calibrated against `AUDIO-QUALITY-TARGETS-V2`; it is therefore not numerically comparable with pre-V2 reference-distance values. Human listening may choose among non-dominated trade-offs without rewriting those objective values.

## Restart/replay

Each node has its own Observation stream (`audio.pool.ed209a`, etc.). H durably stores accepted envelopes. On HTTPS-server restart the journal reconstructs the in-memory Observation service and preserves replayable evidence.

The server uses one small control-plane connection worker. That intentionally serializes tiny durable commits, not audio execution; `h_api_worker.sh` is a separate process.

## Bigger-monkey loop

```text
A/B/C/D/E search
       |
       | RESULT + FRONTIER + VOICE_DETECTED ...
       v
H HTTPS / Observation journal
       |
       v
controller / ed209c coordinator
   |          |             |
   |          |             +--> bounded F/G GPU judgement
   |          +----------------> human REVIEW / objective calibration
   +---------------------------> explicit H rolling-refinement job
                                      |
                                      v
                                  H result
                                      |
                                      +---- observations continue
```

No edge in this diagram converts conversation directly into mutation authority. Work still crosses the explicit job/admission boundary.

## Trust and producer proof

Gopher's current authoritative guidance is explicit:

- Observation producer registrations and stream descriptors can carry node identity, capability generation and `proofRef`, but those fields are **seams, not self-validation**.
- Access Permissions separates authentication/attribution from authority: a valid authentication assertion proves attribution/integrity, not Access Control or Permission.
- therefore the current pool bearer authenticates the H ingress/controller connection; a body field such as `node_id=ed209a` is not by itself cryptographic proof that A originated the observation.

Controller-proxied publication is acceptable under that stated limitation. Direct autonomous worker posting will later bind producer identity through the common trust/Permissions seam. This package does not invent a parallel per-node bearer authority system.

## Controller integration

Automatic publication after normal A-E collection is optional and non-destructive:

```bash
AUDIO_POOL_AUTO_OBSERVE=1 \
ED209H_API_URL=https://ed209h-api:9443 \
ED209H_API_CA=/path/ed209h-ca.pem \
ED209H_API_TOKEN_FILE=/path/ed209h-api.token \
./deploy_all.sh --qualification
```

Observation publication failure never invalidates or removes the already-collected search result.

Manual operations:

```bash
./h_api.sh streams -
./h_api.sh observe /path/message.obs
./h_api.sh replay ed209c:0:50
```


## 11:15 campaign thread

Use `thread_id=campaign-1115` for A-E/H observations from this retarget.
Recording-boundary stitching is fixture provenance only and does not
change Observation semantics or execution authority. Human
intelligibility labels remain REVIEW/VOICE_DETECTED evidence and never
cause implicit execution.

## 11:30 campaign thread

Use `thread_id=campaign-0945-quality-v1` for A-E/H observations from this retarget. Preserve parent node/rank and H rolling-view provenance independently; conversation remains evidence rather than execution authority.


## 11:22:30 campaign thread

Use `thread_id=campaign-0945-quality-v1`. Preserve parent node/rank and H rolling-view provenance independently.
