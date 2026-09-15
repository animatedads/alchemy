/* Loading only the core must not define aviation classes. */
signal on syntax name absent
ignore = .ReportNotamAdapter~transformId
say "FAIL ReportNotamAdapter visible from core-only program"
exit 1
absent:
  say "PASS test_core_has_no_notam_class"
  exit 0

::requires "../src/AlchemyReport.cls"
