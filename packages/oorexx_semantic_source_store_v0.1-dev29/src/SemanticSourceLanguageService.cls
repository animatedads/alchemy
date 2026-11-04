/*
 * Semantic Source Control - language profile and reconstructability service.
 *
 * Semantic identity is language-neutral, but spelling/lookup rules are not.
 * Every adapter must preserve exact source/runtime spelling separately from
 * the lookup key used by that language/runtime.
 */

::class SemanticSourceLanguageProfile public
::method init
  use strict arg languageId, displayName, adapterId, rebuildable = 0, caseSensitive = 1, lookupPolicy = "EXACT"
  self~languageId = languageId
  self~displayName = displayName
  self~adapterId = adapterId
  self~rebuildable = rebuildable
  self~caseSensitive = caseSensitive
  self~lookupPolicy = lookupPolicy
  self~preserveSpelling = 1
  self~extensions = .array~new
  self~objectKinds = .array~new
  self~dependencyKinds = .array~new
  self~exportKinds = .array~new
::attribute languageId
::attribute displayName
::attribute adapterId
::attribute rebuildable
::attribute caseSensitive
::attribute lookupPolicy
::attribute preserveSpelling
::attribute extensions
::attribute objectKinds
::attribute dependencyKinds
::attribute exportKinds

::class SemanticSourceLanguageService public

::method init
  self~profiles = .directory~new
  self~installBuiltins

::attribute profiles get
::attribute profiles set private

::method addKinds private
  use strict arg profile, kinds
  do kind over kinds
    profile~objectKinds~append(kind)
  end

::method installBuiltins private
  -- ooRexx lookup is case-insensitive for symbolic program names.  Preserve
  -- source spelling exactly; use uppercase only as the separate lookup key.
  o = .SemanticSourceLanguageProfile~new("oorexx", "ooRexx", "oorexx-structural-v4", 1, 0, "UPPER")
  o~extensions~append(".cls")
  o~extensions~append(".rex")
  kinds = .array~of("PACKAGE_SOURCE", "EXECUTABLE_SECTION", "OPTIONS", "REQUIRES", "RESOURCE", "ROUTINE", "CLASS", "CONSTANT", "ATTRIBUTE", "ATTRIBUTE_GETTER", "ATTRIBUTE_SETTER", "METHOD")
  self~addKinds(o, kinds)
  o~dependencyKinds~append("REQUIRES")
  o~exportKinds~append("PUBLIC_CLASS")
  o~exportKinds~append("PUBLIC_ROUTINE")
  o~exportKinds~append("PUBLIC_RESOURCE")
  self~profiles[o~languageId] = o

  j = .SemanticSourceLanguageProfile~new("java", "Java", "java-structural-v3", 1, 1, "EXACT")
  j~extensions~append(".java")
  kinds = .array~of("PACKAGE", "CLASS", "INTERFACE", "ENUM", "RECORD", "CONSTANT", "ATTRIBUTE", "METHOD", "CONSTRUCTOR", "INITIALIZER")
  self~addKinds(j, kinds)
  j~dependencyKinds~append("IMPORTS")
  j~dependencyKinds~append("USES")
  j~exportKinds~append("PUBLIC_TYPE")
  j~exportKinds~append("PUBLIC_MEMBER")
  self~profiles[j~languageId] = j

  c = .SemanticSourceLanguageProfile~new("cpp", "C++", "cpp-structural-v2", 1, 1, "EXACT")
  do ext over .array~of(".cpp", ".cc", ".cxx", ".c++", ".hpp", ".hh", ".hxx", ".h")
    c~extensions~append(ext)
  end
  kinds = .array~of("NAMESPACE", "MODULE", "CLASS", "STRUCT", "UNION", "ENUM", "CONSTANT", "ATTRIBUTE", "METHOD", "CONSTRUCTOR", "DESTRUCTOR", "FREE_FUNCTION", "TYPE_ALIAS", "TEMPLATE", "CONCEPT", "DECLARATION", "DEFINITION")
  self~addKinds(c, kinds)
  c~dependencyKinds~append("TEXTUAL_INCLUDE")
  c~dependencyKinds~append("MODULE_IMPORT")
  c~dependencyKinds~append("HEADER_UNIT_IMPORT")
  c~dependencyKinds~append("FORWARD_DECLARATION")
  c~exportKinds~append("EXPORTED_MODULE")
  c~exportKinds~append("PUBLIC_SYMBOL")
  self~profiles[c~languageId] = c

  r = .SemanticSourceLanguageProfile~new("rust", "Rust", "rust-structural-v2", 1, 1, "EXACT")
  r~extensions~append(".rs")
  kinds = .array~of("CRATE", "MODULE", "STRUCT", "ENUM", "TRAIT", "IMPLEMENTATION", "CONSTANT", "STATIC", "ATTRIBUTE", "METHOD", "ASSOCIATED_FUNCTION", "FREE_FUNCTION", "TYPE_ALIAS", "MACRO")
  self~addKinds(r, kinds)
  r~dependencyKinds~append("SOURCE_IMPORT")
  r~dependencyKinds~append("MODULE_DECLARATION")
  r~dependencyKinds~append("CRATE_DEPENDENCY")
  r~dependencyKinds~append("TRAIT_IMPLEMENTATION")
  r~exportKinds~append("PUB_ITEM")
  r~exportKinds~append("REEXPORT")
  self~profiles[r~languageId] = r

  -- Python is admitted through its structural source adapter.  Runtime
  -- introspection uses __mro__ + class __dict__ and therefore preserves exact
  -- case and dispatch order rather than normalising names.
  p = .SemanticSourceLanguageProfile~new("python", "Python", "python-structural-v1", 1, 1, "EXACT")
  p~extensions~append(".py")
  p~extensions~append(".pyi")
  kinds = .array~of("MODULE", "CLASS", "ATTRIBUTE", "PROPERTY", "PROPERTY_GETTER", "PROPERTY_SETTER", "PROPERTY_DELETER", "METHOD", "CLASSMETHOD", "STATICMETHOD", "FUNCTION", "CONSTANT", "DECORATOR")
  self~addKinds(p, kinds)
  p~dependencyKinds~append("IMPORT")
  p~dependencyKinds~append("FROM_IMPORT")
  p~dependencyKinds~append("BASE_CLASS")
  p~exportKinds~append("MODULE_EXPORT")
  p~exportKinds~append("__ALL__")
  self~profiles[p~languageId] = p

::method profile
  use strict arg languageId
  key = languageId~lower
  if \self~profiles~hasIndex(key) then raise syntax 88.900 array("unsupported semantic language: " || languageId)
  return self~profiles[key]

::method languageForPath
  use strict arg path
  lower = path~lower
  ids = self~profiles~allIndexes
  do id over ids
    p = self~profiles[id]
    do ext over p~extensions
      if lower~right(ext~length) = ext then return id
    end
  end
  return ""

::method isRebuildable
  use strict arg languageId
  return self~profile(languageId)~rebuildable

::method assertRebuildable
  use strict arg languageId
  if \self~isRebuildable(languageId) then raise syntax 88.900 array("language cannot be deterministically rebuilt: " || languageId)
  return 1

::method supportsObjectKind
  use strict arg languageId, objectKind
  p = self~profile(languageId)
  wanted = objectKind~upper
  do kind over p~objectKinds
    if kind = wanted then return 1
  end
  return 0

::method semanticGranularity
  use strict arg languageId
  self~assertRebuildable(languageId)
  select
    when languageId~lower = "oorexx" then return "method"
    when languageId~lower = "java" then return "member"
    when languageId~lower = "cpp" then return "member"
    when languageId~lower = "rust" then return "item"
    when languageId~lower = "python" then return "member"
    otherwise return "object"
  end

::method adapterId
  use strict arg languageId
  return self~profile(languageId)~adapterId

::method sourceUnitKind
  use strict arg languageId
  self~assertRebuildable(languageId)
  if languageId~lower = "oorexx" then return "PACKAGE_SOURCE"
  if languageId~lower = "java" then return "COMPILATION_UNIT"
  if languageId~lower = "cpp" then return "TRANSLATION_UNIT"
  if languageId~lower = "rust" then return "RUST_SOURCE_UNIT"
  if languageId~lower = "python" then return "PYTHON_MODULE_SOURCE"
  return "SOURCE_UNIT"

::method lookupKey
  use strict arg languageId, spelling
  p = self~profile(languageId)
  select
    when p~lookupPolicy = "UPPER" then return spelling~upper
    when p~lookupPolicy = "LOWER" then return spelling~lower
    otherwise return spelling
  end

::method nameIdentity
  use strict arg languageId, sourceSpelling, runtimeSpelling = ""
  if runtimeSpelling = "" then runtimeSpelling = sourceSpelling
  d = .directory~new
  d["source_spelling"] = sourceSpelling
  d["runtime_spelling"] = runtimeSpelling
  d["lookup_key"] = self~lookupKey(languageId, runtimeSpelling)
  d["case_sensitive"] = self~profile(languageId)~caseSensitive
  d["lookup_policy"] = self~profile(languageId)~lookupPolicy
  return d

::method oorexxImportContract
  p = self~profile("oorexx")
  d = .directory~new
  d["language"] = "oorexx"
  d["adapter_id"] = p~adapterId
  d["source_unit_kind"] = "PACKAGE_SOURCE"
  d["extensions_are_semantic"] = 0
  d["executable_section_kind"] = "EXECUTABLE_SECTION"
  d["directives"] = "OPTIONS,REQUIRES,RESOURCE,ROUTINE,CLASS,CONSTANT,ATTRIBUTE,METHOD"
  d["attribute_accessors"] = "GET,SET"
  d["dependency_construct"] = "::REQUIRES"
  d["case_rule"] = "preserve source spelling; runtime/lookup key may be uppercase"
  d["projection_rule"] = ".rex and .cls share semantics; preserve executable section, directive order and all interstitial source text"
  d["lossless_required"] = 1
  return d

::method javaImportContract
  p = self~profile("java")
  d = .directory~new
  d["language"] = "java"
  d["adapter_id"] = p~adapterId
  d["semantic_granularity"] = "member"
  d["package_construct"] = "package declaration"
  d["dependency_construct"] = "import declaration"
  d["type_constructs"] = "class,interface,enum,record"
  d["member_constructs"] = "constant,attribute,method,constructor,initializer"
  d["export_rule"] = "Java visibility; public types/members are exports"
  d["case_rule"] = "case-sensitive; preserve exact spelling"
  d["projection_rule"] = "preserve package/import/type/member order and all interstitial source text"
  d["lossless_required"] = 1
  return d

::method cppImportContract
  p = self~profile("cpp")
  d = .directory~new
  d["language"] = "cpp"
  d["adapter_id"] = p~adapterId
  d["semantic_granularity"] = "member"
  d["scope_constructs"] = "namespace,C++20 module"
  d["type_constructs"] = "class,struct,union,enum"
  d["dependency_constructs"] = "include,module import,header-unit import,forward declaration"
  d["ownership_rule"] = "declaration and out-of-class definition may bind to one semantic method with separate projection owners"
  d["method_qualifiers"] = "const,static,virtual,override,final,noexcept,constexpr,consteval,ref-qualifier,template,access"
  d["case_rule"] = "case-sensitive; preserve exact spelling"
  d["projection_rule"] = "preserve preprocessor state, declaration/definition placement, order and interstitial source text"
  d["lossless_required"] = 1
  return d

::method rustImportContract
  p = self~profile("rust")
  d = .directory~new
  d["language"] = "rust"
  d["adapter_id"] = p~adapterId
  d["semantic_granularity"] = "item"
  d["package_constructs"] = "crate,module"
  d["type_constructs"] = "struct,enum,trait"
  d["implementation_construct"] = "impl; semantic owner may differ from projection owner"
  d["receiver_model"] = "&self=IMMUTABLE,&mut self=MUTABLE,self=CONSUMING,no receiver=NONE"
  d["dependency_constructs"] = "use,mod,crate dependency,trait implementation"
  d["export_rule"] = "pub/pub(crate)/pub(super)/pub(in); pub use is a re-export"
  d["case_rule"] = "case-sensitive; preserve exact spelling"
  d["projection_rule"] = "preserve impl blocks, module/item order, macros/attributes and all interstitial source text"
  d["lossless_required"] = 1
  return d

::method pythonImportContract
  p = self~profile("python")
  d = .directory~new
  d["language"] = "python"
  d["adapter_id"] = p~adapterId
  d["semantic_granularity"] = "member"
  d["package_constructs"] = "module,package"
  d["type_constructs"] = "class"
  d["member_constructs"] = "attribute,property,method,classmethod,staticmethod"
  d["dependency_constructs"] = "import,from import,base class"
  d["runtime_resolution"] = "__mro__ dispatch order + exact class __dict__ spelling"
  d["export_rule"] = "__all__ when present; otherwise module visibility convention is recorded, not invented"
  d["case_rule"] = "case-sensitive; preserve exact spelling"
  d["projection_rule"] = "preserve decorators, indentation, comments, order and interstitial source text"
  d["lossless_required"] = 1
  return d

