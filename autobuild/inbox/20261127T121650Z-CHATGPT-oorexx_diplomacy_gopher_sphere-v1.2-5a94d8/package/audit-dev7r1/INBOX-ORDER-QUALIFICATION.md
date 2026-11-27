# Dev7r1 — P1 seat-order correction
Architecture: Tom Dyer; implementation: ChatGPT (GPT-6.2).
Independent dev6 review/measurements: Claude (Opus 5.5), REQ-00006401.

Dev6 mechanics independent PASS. P1 changed only host-side inbox presentation
order; same legal mail and caps. New format DIPLOG|3 selects each recipient's
own already-seeded player list for grouping incoming senders, preserving
each sender's chronological message order. INBOX_ORDER logs the IDs.
DIPLOG|1 and |2 retain their historical replay semantics. No effect on the
pinned referee, rules, map, or outcome calculations.

Full QUIET measuring player, 25 years, seed 7, P=3:
| Power | Press mean rank | Order mean rank |
| --- | ---: | ---: |
| AUS | 3.458 | 3.620 |
| ENG | 3.525 | 3.430 |
| FRA | 3.535 | 3.490 |
| GER | 3.487 | 3.523 |
| ITA | 3.522 | 3.553 |
| RUS | 3.382 | 3.457 |
| TUR | 3.592 | 3.427 |

Observed first/last proportions range 12.67–22.33%; none pinned at 0 or 100%.
Quiet/replay journal SHA-256:
cdb34587b601dc48685feaf4179deaefa07fb900cb0a7b7c872ef84cc732c472.
One-year player/replay SHA-256:
a75eedd4882b39739c7861c1ee5ec5158ae74302ca740ace5af41d93d7c2474f.
One-year LOUD scenarios across all seven powers (exact Claude script):
every seat has the same 94.9% share of opponent order-call inbox, 9552
bytes per opponent order call, 6368 per press call. Estimated tokens in
Claude's measurement are byte/4, not billing counts. No new volume cap.
P2 tie-break and exact runtime profile rulings remain open. No live calls.

Additional exact reviewer-script cross-check after official dev7r1 PASS:
`rexx review/megaphone.rex 25 <dir>` completed all eight 25-year scenarios
(QUIET and LOUD per each of seven powers), each 1050 press / 350 order calls;
all loud seats 94.9%, 9552 bytes/order inbox and 6368 bytes/press inbox.
See megaphone-25-years.txt; this is measurement, not a model outcome or
billing-token estimate. The independently measured rank matches the gate.
