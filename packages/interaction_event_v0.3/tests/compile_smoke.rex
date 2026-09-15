say .InteractionEventBuild~PRODUCT .InteractionEventBuild~VERSION .InteractionEventBuild~API_VERSION
lib = .InteractionCaptureLibrary~new
if lib == .nil then exit 1
say 'PASS compile_smoke'
exit 0
::requires 'InteractionEvent.cls'
