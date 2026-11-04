examiner = .SemanticSourceCodeExaminer~new(.CompileAuthority~new)
view = examiner~initialView("compile")
say view["view_id"]
exit 0
::class CompileAuthority
::method examinerCatalog
  use arg userId, moduleId = "", branchId = ""
  return .array~new
::requires "../src/SemanticSourceCodeExaminer.cls"
