signal on syntax name nomaths
ignore = .Maths~exact("0")
doc = .ReportDocumentChecked~new("math-1", "Maths mixin")
sum = doc~addAmount("2/3", "1/3")
proof = doc~proveEqual(sum, "1")
if \proof~verified then do
  say "FAIL 2/3+1/3 proof" proof~outcome
  exit 1
end
p = .array~new
d1 = .directory~new; d1["side"] = "DR"; d1["amount"] = "6"
d2 = .directory~new; d2["side"] = "CR"; d2["amount"] = "6"
p~append(d1); p~append(d2)
bal = doc~debitCredit(p)
if \bal["balanced"] | bal["outcome"] \= "PROVED" then do
  say "FAIL books proof" bal["outcome"]
  exit 1
end
na = doc~notAdditive("6", "4")
if \na["ok"] then do
  say "FAIL notAdditive proof"
  exit 1
end
say "PASS test_maths_mixin" bal["outcome"]
exit 0
nomaths:
  say "SKIP test_maths_mixin — oorexx_maths not on the path"
  exit 0

::requires "../src/ReportDocumentChecked.cls"
