# References for KL10 IPL ooRexx v0.23

External historical/reference material is used as an oracle, not vendored.

- DECsystem-10/DECSYSTEM-20 Processor Reference Manual definitions for `AOS`,
  `SOJ`, `AOBJP`, and `AOBJN`.
- The KL10 rule that AOBJ increments the left and right 18-bit halves
  independently. This deliberately differs at right-half rollover from the
  older KA10 whole-word `+1000001` implementation.
- Preserved DEC TOPS-20 V7.0 installation tape `BB-H137F-BM`, external fixture
  SHA-256 `7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7`.

## v0.23 historical observations

The tape now reproduces the previously unclaimed handoff. Step 34 executes
`000002 250611,,000000` (`EXCH 14,0(11)`) with E=`011000`; step 35 executes the
following `MOVEM`; steps 36 and 37 execute `AOS 0,11` and `AOS 0,12` directly
against the live fast-memory window, advancing AC11 from `011000` to `011001`
and AC12 from `742000` to `742001`.

Step 38 executes `367540,,000001` (`SOJG`) and branches back to AC1. The loop
advances AC11/AC12 and decrements AC13 from `036000` until the count reaches
zero. A complete debug single-step replay reaches the loop exit at step 92192,
then AC7's JRST transfers to `771044`.

For routine regression, `MTBootPostLoopAOBJ.rex` reproduces the loop's exact
memory transformation directly: each turn swaps the words at the current
AC11/AC12 addresses, advances both 18-bit addresses, and decrements the known
`036000` count. From the resulting real-tape memory state it starts at `771044`.
At `771077`, `AOBJN` advances AC2 from `777742,,000742` to
`777743,,000743` and branches to `771073`; subsequent iterations repeat the
same KL10 independent-half behavior.

AOS uses 36-bit ADD-one flag generation, writes E through `KL10AddressSpace`,
and copies the result to AC only when the instruction AC field is nonzero. SOJ
uses 36-bit subtract-one flag generation and tests the updated signed AC before
branching. AOBJ leaves arithmetic flags unchanged.
