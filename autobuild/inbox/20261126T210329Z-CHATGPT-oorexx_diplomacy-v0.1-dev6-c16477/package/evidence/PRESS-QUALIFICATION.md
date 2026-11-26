# Dev6 step 6 — press controller qualification
Architecture: Tom Dyer. Implementation / native checks: ChatGPT GPT-6.2.
Built over official dev5. The four independently reviewed referee class
files and rules.conf still match the dev4r4/r5/dev5 production identities.
Existing 3311 referee assertions / 232 positions and 63 game assertions
remain in the integrated gate. Dev5 no-press replay hashes remain exact.

The dedicated step-6 test was run on native ooRexx 5.3.0 r13196:
276 assertions, zero failures, pitfall lint zero findings.
- 1901 directed game, 42 press + 14 order calls; same number maps to
  different recipients for AUS/ENG in round 1, and ENG round 1/2.
- Round barrier, true sender/recipient frame, self/group delivery, exact
  mail ordering and no prior-phase/round accumulation. Detached address
  list and board mutations do not affect authority or other players.
- Out-of-range, mixed invalid/valid, empty and nondecimal addresses drop
  without notification; 7th message drops; body >1500 codepoints cut;
  UTF-8 tested at boundary. Case-insensitive message grammar; CR/LF
  normalization and escaped forged === frames. Injection text delivered;
  deterministic marker recorded without penalty.
- Malformed SEND response atomically drops all mail; callback timeout,
  exception and malformed contract are logged without delivering.
- Simulated reverse response arrival via directory insertion: identical
  delivery journals. P=1 and two remaining powers tested.
- Full scripted 1901–1925 game: 125 phases, 1050 press calls, 350 order
  calls, 2100 delivered messages (one self and one numeric per call),
  1050 silently dropped bad addresses, zero invalid orders.
- Replay from raw recorded press and order calls is byte identical;
  tampered MAIL record is detected by regenerated journal comparison.

SHA-256 exact original and replay journal:
DIRECTED 4258862816cef26d85b47909329a01fb2d0c295f20a38405105f5acb2184f462
FULL     e33afd96a19ed8d7bf19d607304e2b1131b19551846c54e417dc7e9f5344d6ac
HOLD     6ada6be204824b8eb4f39c377b083639ca6e57c450614d25d8799c89543bf2d7
RANDOM   ba68d770498185e97363fea503c87b72a6f770751cbd3e65fe8dcde40049d29c

Reproduce: sh tests/run.sh with ALCHEMY_REPO_ROOT and native r13196.
This is local native qualification, not an independent review or live LLM run.
