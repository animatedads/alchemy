catalog = .CivicSourceCatalog~defaultCatalog
say "catalogue:" catalog~identity~left(80) || "..."
do descriptor over catalog~descriptors
  say descriptor~sourceId
  say "  mapping:" descriptor~mappingGeneration
  say "  projection:" descriptor~projectionKind
  say "  credential:" descriptor~credentialPolicy
  say "  endpoint:" descriptor~scheme || "://" || descriptor~host || descriptor~pathTemplate
  say "  ability:" descriptor~abilityId descriptor~contractGeneration
  if descriptor~requestHeaders~items > 0 then do name over descriptor~requestHeaders
    say "  fixed header:" name || ":" descriptor~requestHeaders[name]
  end
end

accepted = .array~of("postcodes.io.postcode/9.9", "postcodes.io.postcode/0.2")
selection = catalog~select("postcodes.io.postcode", accepted)
if selection~ok then say "selected exact mapping:" selection~selection~descriptor~mappingGeneration
else say "selection failed:" selection~errorCode selection~message
exit 0

::requires "CivicCatalog.cls"
