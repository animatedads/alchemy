# Review: oorexx_diplomacy v0.1-dev6 (step 6, private press)

- Architecture: Tom Dyer.
- Implementation: ChatGPT (GPT-6.2).
- Review and tools: Claude (Opus 5.5), 27 Nov 2026.
- Question asked by Tom: does whoever uses the loudest megaphone win?

## Verdict

PASS for step-6 mechanics. Fix P1 before step 7 makes live calls. P2 is a rules
error in my own tie-break wording and needs Tom's ruling. N1-N3 from the dev5
review are still open, because dev6 was built before that review arrived.

## What I ran (ooRexx 5.3.0, GitHub mirror head; r13196 stays official)

1. dev6 `tests/run.sh`: every check passes (3,311 referee assertions, 63 game and
   276 press checks), lint 0. The press journal hashes match ChatGPT's exactly:
   DIRECTED `42588628...`, FULL `e33afd96...`.
2. This package's `tests/run.sh`, now pointed at dev6: DATC v3.4 additions, fuzz,
   mutation, and the RICH and RANDOM full-game audits. All pass.
3. New tool `review/megaphone.rex` with `review/DiplomacyMegaphoneSource.cls`.
   Every unit holds, so only press differs between runs. It measures every inbox a
   player is shown: in each press call and in each movement order call.
   - QUIET: every power sends one short note to all the others.
   - LOUD-x: power x sends six messages to all the others, each at the
     1,500 code point cap. Run once for each of the seven powers.
   Its journals (up to 144 full-size MAIL frames a year) replay byte for byte.

## P1 - Seat order: the referee gives one power the first word and another the last

`DiplomacyPress~finishRound` delivers mail in `responses~allIndexes~sort` order,
which is alphabetical by sender. The QUIET result, identical for 1 and 25 years:

| Sender | Mean rank in other inboxes | First | Last |
| --- | --- | --- | --- |
| AUS | 1.00 | 100% | 0% |
| ENG | 1.83 | 17% | 0% |
| FRA | 2.67 | 0% | 0% |
| GER | 3.50 | 0% | 0% |
| ITA | 4.33 | 0% | 0% |
| RUS | 5.17 | 0% | 17% |
| TUR | 6.00 | 0% | 100% |

The same holds in press inboxes and order-call inboxes. The order-call inbox is
the last text a player reads before it writes orders. So Turkey holds the last
word in every inbox and Austria the first, in every round of every game. Models
weight the start and the end of their input differently, so this is an advantage
the referee assigns to a seat, not something a player earned.

The Latin-square rotation spreads it across prompts, but it stays tied to the
power, which adds a fixed bias to every power's result.

Fix: order each recipient's inbox by a seeded draw, separately for each recipient
and each round. Record it in the journal, and have replay regenerate it. Keep each
sender's own messages in their original order. One option is the recipient's own
player-list numbering for the round just finished: it is already random and
already recorded.

Acceptance test: in megaphone QUIET, no sender is first or last 100% of the time,
and every mean rank is close to 3.5 over 25 years.

## P2 - Tie-break counts other players' mail as your tokens (rules error: Claude)

Section 4 of the rules says the tie-break counts "all input and output tokens of
that prompt's calls". Mail a player receives is part of its input. Measured, for
one LOUD power:

- 9,552 bytes (about 2,400 tokens) in each opponent's order-call inbox.
- 6,368 bytes on average in each opponent's press inbox. Round 1 is always empty,
  because mail is delivered at the end of a round.
- Over 1901-1925, about 1.43 MB, or roughly 358,000 tokens, added to each of the
  six opponents' counts. The loud power pays a similar amount in its own output.

So a prompt's efficiency figure depends on what its opponents choose to send.
That is not what the tie-break was meant to measure. Options for Tom:

- (a) Count input and output, minus the delivered mail frames. The journal holds
  every frame exactly. Each frame needs its tokens counted with that engine's
  tokenizer.
- (b) Count output tokens plus the prompt's own length times its number of calls.
  Both numbers are exact, and no tokenizer call is needed.

Claude recommends (b).

## P3 - Volume itself: legal, symmetric, no change proposed

A LOUD power fills 94.9% of each opponent's order-call inbox, whichever seat it
holds: all seven LOUD runs give the same figures. The cap is the same for every
seat, so the megaphone is a trick available equally to all seats. Tom's standing
direction is not to rule out tricks, so this review proposes no extra cap.

Budget note for the open runtime item: if all seven powers are loud, each power
receives about 2.1 million input tokens of mail per game, and the game as a whole
about 15 million.

## Carried over from the dev5 review (REQ-00006391), still open

- N1: the coverage gate (RICH audit) is not yet in dev6 `run.sh`.
- N2: `+ 0` coercion is now on four lines, `src/DiplomacyGame.cls` 23-26
  (`pressRounds` was added).
- N3: the silent handlers now include `badPress`. Measured: the RICH test player
  has no `press` method, and all 1,050 press calls in a game come back `ERROR`
  with no diagnostic anywhere. In step 7, a bug in an engine adapter will look the
  same as a model failure. Log the condition (message, rc, sigl) to the operator
  log, and leave the journal line unchanged.

## My own gap

The RICH player does not send press, so my full-game auditor does not yet test
press content (bad addresses, forged frames, the cap) inside full games. ChatGPT's
`tests/press.rex` covers those directly. The megaphone tool covers order and
volume. I will add press to RICH in the next version of this package.
