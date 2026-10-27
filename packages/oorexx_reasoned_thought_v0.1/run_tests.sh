#!/bin/sh
# Reasoned Thought v0.1 qualification (strawman): two worked examples.
#   1. the RexxLA attribution re-evaluation (acceptance vectors A-E)
#   2. a hierarchy of universals for discussion (Tom's men/boys/girls example)
#   3. proof-of-analysis exchange (one proof, a second instance re-runs and diffs it)
#   4. retroactive revision (replay a claim under a new model; trace what decisions fall)
#   5. circular dogfood (the module audits its own development)
#   6. self-contained proof bundle (serialize -> parse -> rebuild -> verify, in a second process)
#   7. a real conversation's logic (psychic-spies/bitcoin chat): falsified assumptions -> revisions
#   8. a job's facts matrix under a measurement (rx2cpp cache: slowdown -> which fact was wrong)
#   9. the sycophancy audit (Gemini): scope separation vs unwarranted flip; no new model needed
#  10. audit another model's answer (Gemini bitcoin) against the shared scenario premises
#  11. audit a third model (ChatGPT bitcoin) - convergence + each model.s one readable-secret slip
#  12. cross-model audit (Byzantine Oracle): each design.s safety invariant vs the scenario.s f=4
#  13. three-way cross-model audit (Claude / ChatGPT / Gemini) of the Byzantine Oracle
#  14. everyday-domain application (the underperforming salesman): leaps fall, admission enforced, not partisan
#  15. disparate-treatment / even-handedness probe (Sonnet #5): same stated standard applied evenly?
#  16. fairness falsifier: the disparate-treatment auditor is itself label- and order-invariant (Sonnet #6)
#  17. premise typing (Sonnet #3): descriptive/normative/definitional; is-ought gap; thick concepts decomposed
# Pure ooRexx 5.3, no native dependencies.
# Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo "== 1. attribution re-evaluation"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_attribution_reeval.rex"
echo ""
echo "== 2. hierarchy / discussion"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_hierarchy_discussion.rex"
echo ""
echo "== 3. proof-of-analysis exchange"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_proof_exchange.rex"
echo ""
echo "== 4. retroactive revision / dependency trace"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_retro_revision.rex"
echo ""
echo "== 5. circular dogfood (the module audits its own development)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_dogfood_development.rex"
echo ""
echo "== 6. self-contained proof bundle (independent-process replay + verify)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_proof_bundle.rex"
echo ""
echo "== 7. a real conversation's logic (psychic-spies / bitcoin chat)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_psychic_spies_logic.rex"
echo ""
echo "== 8. a job's facts matrix under a measurement (rx2cpp cache)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_rx2cpp_cache.rex"
echo ""
echo "== 9. the sycophancy audit (Gemini ooREXX/philosophy transcript)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_gemini_sycophancy.rex"
echo ""
echo "== 10. audit another model's answer (Gemini bitcoin) vs shared premises"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_gemini_bitcoin.rex"
echo ""
echo "== 11. audit a third model (ChatGPT bitcoin): convergence + recovery slip"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_chatgpt_bitcoin.rex"
echo ""
echo "== 12. cross-model audit (Byzantine Oracle): safety invariant vs f=4"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_byzantine_compare.rex"
echo ""
echo "== 13. three-way cross-model audit (Claude / ChatGPT / Gemini)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_byzantine_3way.rex"
echo ""
echo "== 14. everyday-domain application (the underperforming salesman)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_underperforming_salesman.rex"
echo ""
echo "== 15. disparate-treatment / even-handedness probe (Sonnet #5)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_standard_application_audit.rex"
echo ""
echo "== 16. fairness falsifier: auditor is label- and order-invariant (Sonnet #6)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_standard_application_fairness.rex"
echo ""
echo "== 17. premise typing: descriptive/normative/definitional; is-ought gap (Sonnet #3)"
REXX_PATH="$ROOT/src" rexx "$ROOT/tests/test_premise_typing.rex"
echo ""
echo "REASONED THOUGHT v0.1 QUALIFICATION: PASS"
