# Reader v0.5 / Reasoned Thought: independent adversarial cases (ChatGPT)

Architecture: Tom Dyer. Original input fixtures and oracle: ChatGPT GPT-6, 2026-11-04.
**Status:** Prepared, **NOT RUN**. Not a claim of Reader or RT PASS. No runtime code changes.

These six cases are independent of Claude's four self-authored adversarial variants. Treat each `Source:` as a separate statement/record; the name is the source ID. All are fictional. Lines are deliberately simple. Preserve exact source and claim provenance.

## A1 — Admission does not upgrade adjacent denial

**Source: LIAM (testimony)**
```text
My name is Liam Carter.
On Tuesday, I took the money from the bank.
On Tuesday, I did not have a gun.
Noah had a gun on Tuesday.
```

**Source: NOAH (testimony)**
```text
My name is Noah Carter.
I did not bring a gun to the bank on Tuesday.
```

**Source: RECORD1 (official record)**
```text
Official police record.
On Tuesday at 3:20 pm, police arrested Liam at the bank.
At 3:20 pm, police saw a black gun in Liam's hand.
```

**Oracle:** Liam at bank at 3:20 is settled from RECORD1. Liam with gun at 3:20 is settled from RECORD1, rebutting his general Tuesday denial. His taking money is an admission at TESTIMONY tier with an against-interest note, not a promotion. Noah's gun possession must not be settled because of Liam's separate admission.

## A2 — Impeachment does not destroy independent record

**Source: EMMA (testimony)**
```text
My name is Emma Price.
On Tuesday at 3:15 pm, I was at the supermarket.
Noah was with me.
Liam was with me.
```

**Source: NOAH (testimony)**
```text
My name is Noah Carter.
On Tuesday at 3:15 pm, I was at the supermarket.
```

**Source: RECORD1 (official record)**
```text
Official police record.
On Tuesday at 3:15 pm, police arrested Liam at the bank.
```

**Source: RECORD2 (official record)**
```text
Official supermarket camera record.
On Tuesday at 3:15 pm, the camera showed Emma at the supermarket.
```

**Oracle:** Liam at the supermarket at 3:15 is rebutted by incompatible official location; Emma's joint-alibi assertion is impeached. Emma at the supermarket is nevertheless settled by RECORD2. Noah at the supermarket remains undetermined unless independently corroborated; do not transfer Emma's observed presence to Noah.

## A3 — Different weekdays are different time points

**Source: LIAM (testimony)**
```text
My name is Liam Carter.
On Tuesday at 3:15 pm, I was at the bank.
On Wednesday at 3:15 pm, I was at the supermarket.
```

**Source: RECORD1 (official record)**
```text
Official police record.
On Tuesday at 3:15 pm, an officer saw Liam at the bank.
```

**Source: RECORD2 (official record)**
```text
Official supermarket camera record.
On Wednesday at 3:15 pm, the camera showed Liam at the supermarket.
```

**Oracle:** Both location-time facts may be settled; they must not contradict each other. Preserve weekday and am/pm in the time key. This intentionally targets the reported v0.5 one-day assumption.

## A4 — Hearsay, sounds, inside/outside and chronology

**Source: SARA (testimony)**
```text
My name is Sara Lane.
On Tuesday at 3:15 pm, I was outside the bank.
I saw Noah outside the bank.
I heard a loud bang.
I did not see a gun.
```

**Source: NOAH (testimony)**
```text
My name is Noah Carter.
Someone told me that Liam fired a gun.
```

**Source: LIAM (testimony)**
```text
My name is Liam Carter.
I did not fire a gun.
```

**Source: RECORD1 (official record)**
```text
Official police record.
On Wednesday, an officer found a hole in the bank ceiling.
```

**Oracle:** Sara supports Noah being *outside* the bank, not inside it. A bang is not proof of a shot; a later ceiling hole does not establish who or when; Noah's claim is hearsay, not his own observation. Liam firing a gun must not be settled.

## A5 — Names, relationship roles, copulas and mixed claims

**Source: LIAM (testimony)**
```text
My name is Liam Carter.
Noah Carter is my brother.
I took the money from the bank.
I did not carry a gun.
```

**Source: SARA (testimony)**
```text
My name is Sara Lane.
I saw Liam carry a gun in the bank.
```

**Source: RECORD1 (official record)**
```text
Official police record.
On Tuesday at 3:20 pm, police arrested Liam outside the bank.
```

**Oracle:** Name and brother relation must not automatically place Noah at the bank or turn him into a crime suspect. Liam's admission of taking money remains TESTIMONY and must not upgrade his gun denial; any interest undercut on the denial still applies. Sara's conflicting gun account is also TESTIMONY; absent stronger evidence, do not settle the gun claim. Arrest *outside* at 3:20 does not itself establish *inside* at earlier time.

## A6 — Quantified negative: “none of us”

**Source: EMMA (testimony)**
```text
My name is Emma Price.
Liam, Noah and I were at the bank on Tuesday.
None of us had a gun.
```

**Source: RECORD1 (official record)**
```text
Official police record.
On Tuesday at 3:15 pm, an officer saw Liam holding a gun in the bank.
```

**Oracle:** The universal negative “none of us had a gun” is contradicted by Liam's documented gun, but its falsity must not create a positive gun claim for Noah or Emma. This intentionally targets an unread v0.5 construction.

## Cross-case acceptance / output contract

- Report per case: claims derived; sentences or clauses unread; source-to-ground provenance; final verdicts; undercut reason(s); and any changed result after SLAM correction.
- An admission against interest is a **ground note**, never a tier and never a witness-wide credibility upgrade.
- The self-serving adjacent denial keeps its interest UNDERCUT, independently of the admission.
- Independent record and witness impeachment remain distinguishable; an impeached speaker does not invalidate unrelated official records.
- Do not count unread text as a correctly decided claim; distinguish reader coverage faults from RT logical faults.
- Keep claims about different people, times, objects and locations distinct. Do not infer bank interior from outside, a shooter from a bang, or a partner's presence from an observed person's presence.
- Apply revision provenance safeguards: preserve ground ID, exact statement, source, scope, tier, and undercut edge. An apparent state change without supporting input or policy delta should not silently pass.
- Report precise PASS/FAIL/NOT_RUN without backfilling expectations into the implementation.

For machine-friendly per-source text files, the companion ZIP is also supplied to the project coordinator separately.
