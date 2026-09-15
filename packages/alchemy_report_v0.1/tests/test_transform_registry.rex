reg = .ReportTransformRegistry~new
doc = .ReportDocument~new("xf-1", "Unknown transform")
doc~transformRegistry = reg
b = .ReportBinding~new("b1", "PRIMARY", "NOTAM_AIXM", "NOTAM:X", "", "", "",,
      "invented.projection/9.9")
c = .ReportClaim~new("c1", "Something happened.", "FACT")
ignore = c~addBindingId("b1")
ignore = doc~addBinding(b)
ignore = doc~addClaim(c)
signal on syntax name good
ignore = doc~seal
say "FAIL unregistered transform sealed"
exit 1
good:
  say "PASS test_transform_registry"
  exit 0

::requires "../src/AlchemyReport.cls"
