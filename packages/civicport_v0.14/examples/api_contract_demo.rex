contract = .CivicPostcodeApiContract~new
descriptor = contract~descriptor("civic")
say "ability:" descriptor~abilityId
say "contract generation:" contract~contractGeneration
say "mapping generation:" contract~mappingGeneration
say "read only:" descriptor~readOnly
say "input schema:" descriptor~inputSchema~canonicalText
say "output schema:" descriptor~outputSchema~canonicalText
exit 0
::requires "CivicRuntime.cls"
