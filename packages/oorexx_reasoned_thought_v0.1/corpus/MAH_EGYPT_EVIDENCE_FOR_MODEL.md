# Evidence dossier: MAH (Egypt) v SSHD [2023] EWCA Civ 216

**Prepared for ChatGPT to build a Reasoned Thought model. Evidence research & write-up: Claude (Opus 4.8). Architecture: Tom Dyer.**

## Provenance & access

- **Case:** MAH (Egypt) v Secretary of State for the Home Department **[2023] EWCA Civ 216**, Court of Appeal (Civil Division), 28 Feb 2023. Singh LJ (leading); Warby LJ and King LJ agreed.
- **BAILII (canonical cite):** https://www.bailii.org/ew/cases/EWCA/Civ/2023/216.html — BAILII served an anti-bot wall to automated fetch, so the text below was read from the **identical official judgment** on The National Archives Find Case Law: https://caselaw.nationalarchives.gov.uk/ewca/civ/2023/216
- This is a **public, anonymised, published** appellate judgment — no privacy constraint (unlike the pending application case). It may be committed and shared.
- **QUOTE vs SUMMARY convention:** lines marked `Q[para]` are verbatim quotes with the paragraph number as extracted; lines marked `S` are my paraphrase. A modeller should verify quotes and paragraph numbers against the primary before relying on them in a published model — the extraction is faithful but secondary.

## The case in brief (S)

Egyptian appellant; father arrested 2014 over alleged Muslim Brotherhood links, convicted, died in prison; appellant left in 2015 aged 14. The Upper Tribunal, sitting as fact-finder, **accepted** material context — that the arrest fit the crackdown and that the prison held political prisoners (paras 14, 60) — but found him **not credible** on three matters: not asking his mother or father's lawyer about the indictment, not contacting a human-rights organisation, and not obtaining family evidence (paras 15, 83-85). The Court of Appeal **allowed** the appeal, set aside the UT, and **re-made** the decision: he is a refugee (paras 102, 104).

---

## The reasoning anatomy, mapped to the operators (modelling candidates for ChatGPT)

### A. Stated standard vs applied standard → PremiseTyping (is/ought) + StandardApplicationAudit
- `Q[49]` "a reasonable degree of likelihood" — the correct standard.
- `S[81]` the UT used "lower standard of proof" repeatedly but never defined it.
- `Q[37]` "the UT was in substance imposing a high threshold of proof"
- **Model target:** the refusal is a NORMATIVE conclusion; its load-bearing premise is the standard of proof. The *declared* normative bridge ("lower standard") and the *operative* one ("high threshold") diverge. This is the stated-vs-applied discrepancy — a `POLICY/DEFINITION` mismatch, and exactly the is/ought seam PremiseTyping exposes when the operative standard is unstated.

### B. Corroboration bar vs no legal duty + country conditions → StandardApplicationAudit (UNMEETABLE_BAR / self-standard gap)
- `Q[86]` "there is no requirement that the applicant must adduce corroborative evidence"
- `Q[87]` "the UT required more of him than was necessary."
- `S[84,87]` the UT said there was no legal duty to corroborate but in substance proceeded as if there was.
- `Q[94]` evidence described "the mass arrests of human rights lawyers and activists" (2017-18 crackdown; state of emergency).
- **Model target:** a corroboration bar set above both the legal requirement and what the context made obtainable — asking the *father's lawyer* when human-rights lawyers were being arrested. This is the UNMEETABLE_BAR / self-standard-gap shape: the bar must be assessed against the real-world reachability of corroboration. Note the correct rule to encode: Art 4(5) Qualification Directive / para 339L — corroboration not required where criteria met; **it does not follow that it is required where they are not met** (benefit of the doubt still applies).

### C. Credibility vs reliability conflated → PremiseTyping (proposition identity / thick-concept decomposition)
- `Q[88]` "'reliability' is not the same thing as 'credibility'"
- `S[67,88]` the UT rejected the "reliability" of the account of why the father was arrested; Singh LJ held this was a conclusion that the *claim failed*, not a finding of *untruthfulness* — the appellant had said nothing untruthful.
- `Q[87]` (the UT's conflation) "the Appellant has not been truthful in respect of his claim of ongoing adverse interest"
- **Model target:** two distinct propositions — *the account is untrue* (descriptive, about the speaker) and *the fear is not well-founded* (evaluative, about the claim) — collapsed into one. This is the proposition-identity rule (don't let one proposition inherit another's status) and the thick-concept decomposition: "credible" must split into its descriptive (truthfulness/consistency) and evaluative (claim made out) parts before either is adjudicated.

### D. Overlooked material evidence → proposition-selection / omitted node
- `S[93,17]` the appellant's first witness statement described authorities visiting the family home five or six times, roughly every one or two weeks before the father's arrest, searching and damaging property and pressing his mother. The UT did not mention this.
- `Q[93]` "This was a material omission"
- **Model target:** a load-bearing fact absent from the reasoning — the same open-world / omitted-node failure as the vanishing-dinner silence and the Daria missing-finding. Absence from the decision's account is not absence from the evidence.

### E. The remaking → EvidenceRevisionAudit (POLICY_CHANGE_REQUIRES_REVIEW, warranted revision)
- `Q[99]` applying the correct standard, the evidence "could reasonably lead only to one conclusion"
- `S[102-104]` appeal allowed, UT set aside, decision re-made (refugee); remittal rejected as "highly unsatisfactory" (para 103).
- **Model target:** the outcome flips **not because new facts appeared** but because the *standard (policy/criterion)* was corrected. That is textbook `POLICY_CHANGE_REQUIRES_REVIEW` → re-settlement under the corrected floor, a WARRANTED revision distinct from an unsupported flip. A clean real-world instance of the EvidenceRevisionAudit distinction.

### F. The governing principle (epigraph for the whole project)
- `Q` (Green LJ in *SB (Sri Lanka)* [2019] EWCA Civ 160, cited): "A material error in logic is an error of law."
- `Q` (Lord Wilson in *KV (Sri Lanka)* [2019] UKSC 10, cited): "the conclusion about credibility always rests with the decision-maker following a critical survey of all the evidence."
- `S` Singh LJ: a tribunal should be cautious about finding an account inherently implausible, since its views may be shaped by its own background; *Faryna v Chorny* was not an asylum case; the *Y* line was distinguishable because the UT had not found any part inherently implausible.

---

## Candidate structure for the model (neutral — ChatGPT to build and set any values)

Standards in play (for StandardApplicationAudit): **standard of proof** (THRESHOLD: reasonable likelihood, as stated vs as applied); **corroboration** (THRESHOLD: not legally required; reachability conditioned on country conditions). Propositions to keep distinct (for PremiseTyping / proposition identity): *account untrue* vs *fear not well-founded* vs *corroboration obtainable*. Findings the UT made vs omitted (for proposition-selection): accepted context (paras 14, 60) vs the unmentioned family-home visits (para 93). Revision to classify (for EvidenceRevisionAudit): the CA remaking as a criterion-change re-settlement, not a new-fact update.

**Scope ceiling, as always:** a model of this case audits the *UT's reasoning structure* — stated-vs-applied standard, bar reachability, proposition conflation, omission, warranted-vs-unwarranted revision. It does not re-decide whether MAH is a refugee; the Court of Appeal already did, and that outcome is an input to be represented, not a verdict for the tool to reach.

I have NOT assigned severities/tiers here — that is the modelling step, and it is ChatGPT's lane (StandardApplicationAudit owner). This dossier hands over the judge's actual findings with citations so the model rests on the judgment, not on my numbers.
