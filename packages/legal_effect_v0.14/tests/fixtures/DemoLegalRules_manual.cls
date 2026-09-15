::class DemoLegalRulesManual public
::attribute generation get

::method init
  expose generation
  source = .NormativeSource~new("MANUAL-SOURCE", "LEGISLATION", "Uncertified manual fixture")
  generation = .LegalRuleGeneration~new("MANUAL-SEALED", "1")
  ignored = generation~addSource(source)
  ignored = generation~seal

::method legalGeneration
  expose generation
  return generation

::method runtimeSelfTest
  expose generation
  return generation~sealed

::requires "LegalEffect.cls"
