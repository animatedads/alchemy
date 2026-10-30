/* Headless completion contract.
 * Completion follows the same bounded language-block rule as execution.
 * Wire selects a provider from the caret's containing code block and supplies
 * only the named variables that execution would project at that boundary.
 * The provider is responsible for language-native spelling and MUST expose
 * only capabilities available through the actual language projection.
 *
 * Completion is descriptive: it must not execute user code, invoke arbitrary
 * getters, widen capabilities, or replace the application's live objects.
 */
::class WireCompletionRequest public
::method init
  expose language source cursor variables
  use strict arg language, source, cursor, variables
::attribute language get
::attribute source get
::attribute cursor get
::attribute variables get

::class WireCompletionItem public
::method init
  expose label kind insertText
  use strict arg label, kind = "symbol", insertText = ""
  if insertText == "" then insertText = label
::attribute label get
::attribute kind get
::attribute insertText get

/* A language adapter implements this from its real projection metadata.
 * For Alchemy languages this means the projected capability surface, not raw
 * ooRexx reflection.  A hidden/unprojected capability must remain invisible.
 */
::class WireCompletionProvider public
::method complete abstract

::class WireCompletionService public
::method init
  expose providers
  providers = .directory~new

::method register
  expose providers
  use strict arg language, provider
  if language == "" | provider == .nil then raise syntax 88.900 array("WIRE_COMPLETION_PROVIDER_INVALID")
  providers[language~lower] = provider
  return self

::method complete
  expose providers
  use strict arg request
  key = request~language~lower
  if \providers~hasIndex(key) then return .array~new
  /* Provider receives exactly the request and execution-visible variables. */
  return providers[key]~complete(request)
