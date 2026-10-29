/* Compile a real Wire Builder semantic skeleton against accepted dependencies.
 * This is NOT the public website nor a CMS approval authority. */
b=.RasenFalconWireFixture~build
compiler=.WireUICompiler~new
result=compiler~compile(b['workspace'],b['release'])
if \result~ok then do
  say 'WIRE_COMPILATION_DENIED' result~code result~detail
  exit 1
end
package=result~value
say 'WIRE_COMPILATION_OK RASEN_FALCON_AUTHORING_SKELETON@1'
say 'DEFINITIONS' package~definitions~items
say 'JOURNEY_PLANS' package~journeyPlans~items
say 'NOTE semantic skeleton only, not CMS-approved content, deployment or production editor'
exit 0
::requires 'RasenFalconWireFixture.cls'
