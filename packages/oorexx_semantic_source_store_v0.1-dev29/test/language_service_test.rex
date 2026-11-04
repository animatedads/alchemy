svc = .SemanticSourceLanguageService~new
units = .SemanticSourceSourceUnitService~new(svc)

call assert svc~languageForPath("src/Family.cls") = "oorexx", "ooRexx cls recognised"
call assert svc~languageForPath("src/Family.rex") = "oorexx", "ooRexx rex recognised"
call assert svc~languageForPath("src/com/acme/Family.java") = "java", "Java recognised"
call assert svc~languageForPath("src/particle.cpp") = "cpp", "C++ source recognised"
call assert svc~languageForPath("include/particle.hpp") = "cpp", "C++ header recognised"
call assert svc~languageForPath("src/lib.rs") = "rust", "Rust recognised"
call assert svc~languageForPath("src/model.py") = "python", "Python recognised"

call assert svc~isRebuildable("oorexx") = 1, "ooRexx rebuildable"
call assert svc~isRebuildable("java") = 1, "Java rebuildable"
call assert svc~isRebuildable("cpp") = 1, "C++ rebuildable"
call assert svc~isRebuildable("rust") = 1, "Rust rebuildable"
call assert svc~isRebuildable("python") = 1, "Python rebuildable"

call assert svc~supportsObjectKind("oorexx", "EXECUTABLE_SECTION") = 1, "ooRexx runnable section semantic"
call assert svc~supportsObjectKind("oorexx", "OPTIONS") = 1, "ooRexx options semantic"
call assert svc~supportsObjectKind("oorexx", "RESOURCE") = 1, "ooRexx resource semantic"
call assert svc~supportsObjectKind("oorexx", "ATTRIBUTE_GETTER") = 1, "ooRexx attribute GET semantic"
call assert svc~supportsObjectKind("oorexx", "ATTRIBUTE_SETTER") = 1, "ooRexx attribute SET semantic"
call assert svc~supportsObjectKind("java", "METHOD") = 1, "Java method supported"
call assert svc~supportsObjectKind("cpp", "DEFINITION") = 1, "C++ declaration/definition supported"
call assert svc~supportsObjectKind("rust", "IMPLEMENTATION") = 1, "Rust impl supported"
call assert svc~supportsObjectKind("python", "PROPERTY_SETTER") = 1, "Python property setter supported"

call assert svc~semanticGranularity("oorexx") = "method", "ooRexx method granularity"
call assert svc~semanticGranularity("java") = "member", "Java member granularity"
call assert svc~semanticGranularity("cpp") = "member", "C++ member granularity"
call assert svc~semanticGranularity("rust") = "item", "Rust item granularity"
call assert svc~semanticGranularity("python") = "member", "Python member granularity"

orexx = svc~oorexxImportContract
call assert orexx["source_unit_kind"] = "PACKAGE_SOURCE", "ooRexx package source unit"
call assert orexx["extensions_are_semantic"] = 0, ".rex/.cls are projections"
call assert orexx["executable_section_kind"] = "EXECUTABLE_SECTION", "runnable section first class"
call assert orexx["attribute_accessors"] = "GET,SET", "ooRexx accessors captured"

java = svc~javaImportContract
call assert java["dependency_construct"] = "import declaration", "Java import dependency"
call assert java["lossless_required"] = 1, "Java lossless contract"

cpp = svc~cppImportContract
call assert cpp["ownership_rule"]~pos("one semantic method") > 0, "C++ declaration/definition association"
call assert cpp["lossless_required"] = 1, "C++ lossless contract"

rust = svc~rustImportContract
call assert rust["receiver_model"]~pos("IMMUTABLE") > 0, "Rust receiver semantics"
call assert rust["lossless_required"] = 1, "Rust lossless contract"

clsUnit = units~descriptorForPath("src/Family.cls")
rexUnit = units~descriptorForPath("src/Family.rex")
call assert clsUnit["source_unit_kind"] = rexUnit["source_unit_kind"], ".cls/.rex same semantic unit kind"
call assert clsUnit["may_have_executable_section"] = 1, ".cls may be runnable"
call assert rexUnit["may_have_executable_section"] = 1, ".rex may carry directives and runnable section"

binding = units~projectionBinding("method:Particle.position", "type:Particle", "impl:Particle:2", "DEFINITION", 4)
call assert binding["semantic_owner_object_id"] = "type:Particle", "semantic owner retained"
call assert binding["projection_owner_object_id"] = "impl:Particle:2", "projection owner retained"


orexxName = svc~nameIdentity("oorexx", "speak", "SPEAK")
call assert orexxName["source_spelling"] = "speak", "ooRexx source case preserved"
call assert orexxName["runtime_spelling"] = "SPEAK", "ooRexx runtime case retained"
call assert orexxName["lookup_key"] = "SPEAK", "ooRexx lookup normalised separately"
pythonName = svc~nameIdentity("python", "speak", "speak")
call assert pythonName["lookup_key"] = "speak", "Python lookup preserves case"
call assert svc~lookupKey("python", "Speak") \= svc~lookupKey("python", "speak"), "Python names are case distinct"

python = svc~pythonImportContract
call assert python["runtime_resolution"]~pos("__mro__") > 0, "Python runtime graph contract"
call assert python["case_rule"]~pos("case-sensitive") > 0, "Python case rule"

say "LANGUAGE SERVICE TEST: PASS"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires '../src/SemanticSourceLanguageService.cls'
::requires '../src/SemanticSourceSourceUnitService.cls'
