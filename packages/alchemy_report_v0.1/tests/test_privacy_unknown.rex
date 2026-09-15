/* UNKNOWN privacy is retained on the binding; customer projection omits it. */
b = .ReportBinding~new("b-p", "PRIMARY", "CIVIC_DOCUMENT", "CIVIC:doc-1")
if b~privacyClass \= "UNKNOWN" then do
  say "FAIL default privacy" b~privacyClass
  exit 1
end
doc = .ReportDocument~new("priv-1", "Customer projection")
c = .ReportClaim~new("c1", "Passenger named in source.", "FACT")
ignore = c~addBindingId("b-p")
ignore = doc~addBinding(b)
ignore = doc~addClaim(c)
ignore = doc~groundAll
/* Customer projection: drop claims whose bindings are UNKNOWN. */
shown = 0
do id over doc~claims
  cl = doc~claim(id)
  hide = 0
  do i = 1 to cl~bindingIds~items
     bd = doc~binding(cl~bindingIds[i])
     if bd \= .nil, bd~privacyClass = "UNKNOWN" then hide = 1
  end
  if hide = 0 then shown = shown + 1
end
if shown \= 0 then do
  say "FAIL UNKNOWN leaked into customer projection"
  exit 1
end
if doc~claim("c1") = .nil then do
  say "FAIL sealed store lost the claim"
  exit 1
end
say "PASS test_privacy_unknown"
exit 0

::requires "../src/AlchemyReport.cls"
