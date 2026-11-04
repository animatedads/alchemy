/*
 * Semantic Source Control - source unit semantics.
 *
 * A source unit is a projection container, not the authority identity of its
 * contained software objects.  Language adapters describe which structural
 * objects may be projected into it and whether semantic ownership differs from
 * textual/projection ownership.
 */

::class SemanticSourceSourceUnitService public
::method init
  use strict arg languageService
  if languageService == .nil then raise syntax 88.900 array("languageService is required")
  self~languages = languageService
::attribute languages get
::attribute languages set private

::method descriptorForPath
  use strict arg path
  language = self~languages~languageForPath(path)
  if language = "" then raise syntax 88.900 array("unsupported source-unit path: " || path)
  d = .directory~new
  d["language"] = language
  d["source_unit_kind"] = self~languages~sourceUnitKind(language)
  d["projection_path"] = path
  d["projection_extension"] = self~extensionOf(path)
  d["adapter_id"] = self~languages~adapterId(language)
  d["rebuildable"] = self~languages~isRebuildable(language)
  if language = "oorexx" then do
    d["extensions_are_semantic"] = 0
    d["may_have_executable_section"] = 1
    d["executable_object_kind"] = "EXECUTABLE_SECTION"
  end
  return d

::method oorexxComposition
  use strict arg executableObjectId = "", directiveObjectIds = .nil
  if directiveObjectIds == .nil then directiveObjectIds = .array~new
  d = .directory~new
  d["source_unit_kind"] = "PACKAGE_SOURCE"
  d["executable_object_id"] = executableObjectId
  d["directive_object_ids"] = directiveObjectIds
  d["projection_rule"] = "executable section first, then directives in recorded projection order"
  return d

::method projectionBinding
  use strict arg objectId, semanticOwnerId = "", projectionOwnerId = "", projectionRole = "DEFINITION", ordinal = 0
  d = .directory~new
  d["object_id"] = objectId
  d["semantic_owner_object_id"] = semanticOwnerId
  d["projection_owner_object_id"] = projectionOwnerId
  d["projection_role"] = projectionRole
  d["ordinal"] = ordinal
  return d

::method extensionOf private
  use strict arg path
  dot = path~lastpos(".")
  slash = path~lastpos("/")
  bslash = path~lastpos("\\")
  if dot = 0 | dot < slash | dot < bslash then return ""
  return path~substr(dot)~lower

::requires "SemanticSourceLanguageService.cls"
