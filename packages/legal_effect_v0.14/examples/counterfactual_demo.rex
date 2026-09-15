say "LEGAL EFFECT V0.14 COUNTERFACTUAL / SENSITIVITY DEMO"

source = .NormativeSource~new("DEMO-LICENCE-ACT", "LEGISLATION", "Synthetic licence provision", "PARLIAMENT", "ENGLAND")
gen = .LegalRuleGeneration~new("DEMO-CF-G1", "0.14")
ignored = gen~addSource(source)
norm = .LegalNorm~new("DEMO-LICENCE-NORM", source~sourceId, "20", "PROHIBITION", "SHIP_GOODS", "PROHIBITED", "LICENSING", "synthetic rule: active licence blocks this shipment")
ignored = norm~addCondition(.LegalPredicate~new("LICENCE_ACTIVE", "KNOWN_TRUE"))
ignored = norm~addEvidence(.LegalEvidenceAnchor~new(source~sourceId, "LEGAL_PROVISION", "s.20", .nil, "PARLIAMENT"))
ignored = gen~addNorm(norm)
ignored = gen~seal

baseResult = .LegalEffectEngine~new~evaluate(.LegalAction~new("SHIP_GOODS"), gen, .LegalContext~new("DEMO-CF-EVENT", "2026-08-24"))
if \baseResult~ok then do
  say "base evaluation failed:" baseResult~code baseResult~detail
  exit 1
end
base = baseResult~value
say "base_status=" || base~status

counterfactuals = .LegalCounterfactualEvaluator~new~evaluateBoolean(base, "LICENCE_ACTIVE")
if \counterfactuals~ok then do
  say "counterfactual evaluation failed:" counterfactuals~code counterfactuals~detail
  exit 1
end

set = counterfactuals~value
do comparison over set~comparisons
  say "assume LICENCE_ACTIVE=" || comparison~assumption~value || -
      " scope=" || comparison~assumption~scope || -
      " -> status=" || comparison~counterfactualStatus || -
      " changed=" || comparison~statusChanged || -
      " authoritative=" || comparison~authoritative
  say "  counterfactual_identity=" || comparison~counterfactualIdentity~left(72) || "..."
  say "  added_dispositions=" || selfJoin(comparison~addedDispositions)
  say "  added_controlling_norms=" || selfJoin(comparison~addedControllingNorms)
end
say "set_identity=" || set~setIdentity~left(72) || "..."
say "LEGAL EFFECT V0.14 COUNTERFACTUAL / SENSITIVITY DEMO: OK"
exit 0

selfJoin: procedure
  use arg items
  out = ""
  do item over items
    if out <> "" then out ||= ","
    out ||= item
  end
  if out = "" then out = "NONE"
  return out

::requires "LegalEffect.cls"
