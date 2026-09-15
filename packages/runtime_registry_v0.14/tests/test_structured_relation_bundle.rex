parse arg registryRoot pluginRoot
if registryRoot = "" then registryRoot = "."
if pluginRoot = "" then do
  say "STRUCTURED RELATION BUNDLE INTEGRATION: SKIP (no plugin root)"
  exit 0
end
call main registryRoot, pluginRoot
exit 0

main:
  use arg registryRoot, pluginRoot
  say "RUNTIME REGISTRY V0.5 STRUCTURED RELATION BUNDLE START"

  readmeResult = .RuntimeSourceLoader~readFile(pluginRoot || "/README.md")
  call mustOk readmeResult, "read structured relation README"
  readmeLines = readmeResult~value
  call assertTrue readmeLines~items > 0, "structured relation README non-empty"
  versionWord = word(readmeLines~at(1), words(readmeLines~at(1)))
  call assertTrue left(versionWord~lower, 1) = "v", "structured relation README declares v-version"
  pluginVersion = substr(versionWord, 2)

  builder = .RuntimeBundleBuilder~new
  call SysFileTree pluginRoot || "/src/*.cls", sourceFiles., "FO"
  call assertTrue sourceFiles.0 > 0, "structured relation src closure discovered"
  do i = 1 to sourceFiles.0
    path = sourceFiles.i
    name = fileBaseName(path)
    call mustOk builder~addFile(path, name), "add " || name
  end

  wrapper = .array~new
  wrapper~append("::class StructuredRelationRuntimeCapability public")
  wrapper~append("::method runtimeSelfTest")
  wrapper~append('  xml = .XmlDocumentContext~fromText("<Order><Quantity>50</Quantity></Order>", "registry:selftest")')
  wrapper~append('  selection = xml~xpath("/Order/Quantity")')
  wrapper~append("  node = selection~firstNode")
  wrapper~append("  if node == .nil then return .false")
  wrapper~append('  if node~text <> "50" then return .false')
  wrapper~append("  return .true")
  wrapper~append("::method capabilityCount")
  wrapper~append("  return 5")
  wrapper~append("::method xmlQuantityFact")
  wrapper~append('  use arg text, source = "registry:xml"')
  wrapper~append("  doc = .XmlDocumentContext~fromText(text, source)")
  wrapper~append("  provider = .XmlRelationProvider~new(.nil)")
  wrapper~append('  definition = provider~defineRelation("orders", doc, "/Order")')
  wrapper~append('  definition~columnMap("quantity", "Quantity", "INTEGER")')
  wrapper~append('  rows = provider~table("orders")~readRows')
  wrapper~append("  if rows~items = 0 then return .nil")
  wrapper~append('  return rows~at(1)~fact("quantity")')
  call mustOk builder~addUnit("RuntimeStructuredRelationCapability.cls", wrapper), "add runtime wrapper"

  built = builder~build; call mustOk built, "build structured relation closure"; bundle = built~value
  call assertEq sourceFiles.0 + 1, bundle~unitCount, "plugin source closure plus wrapper"
  call assertTrue bundle~localRequiresRemoved~items > 0, "plugin-local requires were closure-bound"

  artifactId = "structured-relation:v" || pluginVersion || ":bundle"
  verifier = .RuntimePinnedSourceVerifier~new
  call mustOk verifier~pin(artifactId, bundle~sourceLines), "pin structured relation bundle"
  kernel = .RuntimeKernel~new(verifier)
  artifact = .RuntimeArtifact~new("structured.relation", "CAPABILITY", pluginVersion, artifactId, "StructuredRelationRuntimeCapability", bundle~sourceLines)
  staged = kernel~stage("test", artifact); call mustOk staged, "stage structured relation bundle"; generation = staged~value
  call mustOk kernel~activate("test", "structured.relation", generation~generationId), "activate structured relation bundle"
  leaseResult = kernel~acquire("test", "structured.relation"); call mustOk leaseResult, "acquire structured relation bundle"; lease = leaseResult~value

  call assertEq 5, lease~module~capabilityCount, "runtime wrapper active"
  fact = lease~module~xmlQuantityFact("<Order><Quantity>50</Quantity></Order>", "integration:order-1")
  call assertTrue fact \== .nil, "rich XML fact returned across generation boundary"
  call assertEq 50, fact~value, "fact typed value preserved"
  call assertEq "50", fact~lexicalValue, "fact lexical value preserved"
  call assertTrue fact~isEvidenceBearing, "fact remains evidence-bearing"
  source = fact~source
  call assertTrue source \== .nil, "fact retains native source object"
  call assertTrue source~path~pos("Quantity") > 0, "native XML source path retained"
  call assertEq "integration:order-1", source~document~source, "source document identity retained"

  call mustOk lease~release, "release structured relation lease"
  say "  plugin_version=" || pluginVersion
  say "  source_units=" || sourceFiles.0
  say "  bundle_units=" || bundle~unitCount
  say "  bundle_lines=" || bundle~sourceLineCount
  say "  local_requires_bound=" || bundle~localRequiresRemoved~items
  say "  fact_source_path=" || source~path
  say "RUNTIME REGISTRY V0.5 STRUCTURED RELATION BUNDLE: OK"
  return

fileBaseName:
  procedure
  use arg path
  slash = lastPos("/", path)
  backslash = lastPos("\\", path)
  cut = slash
  if backslash > cut then cut = backslash
  if cut = 0 then return path
  return substr(path, cut + 1)

mustOk:
  procedure
  use arg r, label
  if \r~ok then do
    say "FAILED:" label r~code r~detail
    exit 60
  end
  return

assertTrue:
  procedure
  use arg value, label
  if \value then do; say "FAILED:" label; exit 61; end
  return

assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 62
  end
  return

::requires "RuntimeBundleBuilder.cls"
