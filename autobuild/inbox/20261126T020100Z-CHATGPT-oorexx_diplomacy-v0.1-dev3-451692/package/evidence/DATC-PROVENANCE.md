# Movement fixture provenance and policy deviations

Architecture: Tom Dyer. Implementation and adaptation: ChatGPT (GPT-6.2).

References:
* Lucas Kruijswijk, The Math of Adjudication, chapters 2 and 6:
  https://diplom.org/Zine/S2009M/Kruijswijk/DipMath_Chp2.htm
  https://diplom.org/Zine/S2009M/Kruijswijk/DipMath_Chp6.htm
* DATC v3.0, sections 6.A–6.G: https://webdiplomacy.net/doc/DATC_v3_0.html
* TedDriggs/diplomacy, diplomacy/tests/datc.rs, Git blob
  5abc740a3ab51a5ca3596ab113d6682351801f01 (MIT; license below).
  This generated Rust corpus is the independent source of most positions
  and explicit success/failure assertions. They have been transcribed into
  the framework's own line grammar; no Rust or Python game execution.

Coverage: 129 named movement positions from A–G, plus G.11 explicit-convoy
variant = 130. A12 B14 C9 D34 E15 F25 G20; B.14 is an adjustment test and
is deferred with sections H onward. Each position tests the imported or
reviewed explicit outcomes, conservation of units and reversed-insertion
replay. It does NOT assert every outcome, dislodgement and retreat option in
all positions; full DATC conformance is not established. 6.F.7 and other
retreat expectations are deferred to the retreat gate. The original
positions have not been copied with narrative descriptions.

Explicit adaptations:
* A.5: the public DATC text says the self-move and its supporting order are
  illegal; use the stated dislodgement, not the imported support success.
* B.2: infer the unique coast, per approved policy.
* B.7/B.8/B.15: an unspecified support coast matches the province, including
  another power's move. B.10/B.12 follow strict coast grammar as in dev2;
  DATC discusses alternate interpretations. B.14 remains a build case.
* D.16 and E.11: added from DATC movement positions not included by the
  automated simple-macro extraction.
* D.32: physically impossible convoy orders are illegal holds; absent
  matching orders on a physically possible route still constitute a move.
  This is the DATC 4.E.1 distinction. Added explicitly to rules.conf.
* G.1, G.5–G.7, G.9, G.11, G.19: follow explicit land-unless-VIA-CONVOY
  policy rather than automatically inferring intent from fleet orders.
* G.10, G.14, G.15: an unsuccessful convoyed move retains prevent strength
  even when dislodged, following DATC choice 4.A.7(b). G.20 no land fallback.
* G.13: the army's origin remains the origin for the support-cut exception.

The solver uses recursive decision queries with explicit GUESSING state,
trial consistency checks and deterministic cycle backup. It is an original
trial-based adaptation of Kruijswijk's equations, not a literal translation
of his C implementation. Ambiguity with convoy path dependencies invokes
Szykman; a pure movement cycle chooses a consistent moving solution. A
4096-trial cap and final equation checks fail closed on unresolved positions.
Independent review of the dependency solver and broad stress testing remain
outstanding; no arbitrary guessed board is returned on an unresolved cycle.

## MIT license for the external test corpus

Copyright (c) 2025 Ted Driggs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
