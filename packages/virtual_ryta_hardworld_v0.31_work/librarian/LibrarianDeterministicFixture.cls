/*
 * LibrarianDeterministicFixture.cls
 * Tiny deterministic Librarian model used only by the integration testbed.
 * It is deliberately not a replacement for a real WordNet/target corpus.
 */

::class LibrarianDeterministicFixture public

::method canonicalModelText class
  use arg topicsPath
  modelText = 'LIBRARIAN_FIXTURE_MODEL_V1' || '0a'x
  modelText = modelText || 'SENSE|SELL|V|VERB.COMMUNICATION|1' || '0a'x
  modelText = modelText || 'SENSE|PRODUCT|N|NOUN.ARTIFACT|2' || '0a'x
  modelText = modelText || 'SENSE|UPSELL|V|VERB.COMMUNICATION|3' || '0a'x
  modelText = modelText || 'SENSE|WARNING|N|NOUN.COMMUNICATION|4' || '0a'x
  modelText = modelText || 'SENSE|DANGER|N|NOUN.STATE|5' || '0a'x
  modelText = modelText || 'SENSE|MEDICATION|N|NOUN.ARTIFACT|6' || '0a'x
  modelText = modelText || 'GRAMMAR_BUILTINS=LIBRARIAN_CORE' || '0a'x
  modelText = modelText || 'GAZETTEER_DEFAULTS=LIBRARIAN_CORE' || '0a'x
  if topicsPath <> '' then do
    topicsHash = .AlgorithmDigest~sha256File(topicsPath)
    modelText = modelText || 'TOPICS_SHA256=' || topicsHash || '0a'x
  end
  return modelText

::method buildModelManifest class
  use arg packageRoot, topicsPath
  manifest = .LibrarianModelManifest~new('LIBRARIAN-FIXTURE', '1')
  if packageRoot == '' then do
    manifest~addLogical('FIXTURE_MODEL', self~canonicalModelText(topicsPath))
    -- Without file identity the model closure is intentionally incomplete.
    return manifest
  end
  root = packageRoot
  if root~right(1) <> '/' then root = root || '/'
  ignore = manifest~addFile('LIBRARIAN_CORE', root || 'librarian/LibrarianCore.cls')
  ignore = manifest~addFile('FIXTURE_CODE', root || 'librarian/LibrarianDeterministicFixture.cls')
  ignore = manifest~addFile('TOPICS', topicsPath)
  ignore = manifest~addLogical('FIXTURE_MODEL', self~canonicalModelText(topicsPath))
  ignore = manifest~markComplete
  return manifest

::method modelFingerprint class
  use arg topicsPath, packageRoot = ''
  if packageRoot <> '' then return self~buildModelManifest(packageRoot, topicsPath)~hash
  return .AlgorithmDigest~sha256Text(self~canonicalModelText(topicsPath))

::method buildAnalyzer class
  use arg topicsPath
  lexicon = .LibrarianLexicon~new
  graph = .LibrarianRelationGraph~new
  grammar = .LibrarianGrammar~new(lexicon)
  grammar~installBuiltins

  addedSense = lexicon~addSense('SELL', 'V', 'verb.communication', '1', 'SELL', 'sell a product', 'fixture')
  addedSense = lexicon~addSense('PRODUCT', 'N', 'noun.artifact', '2', 'PRODUCT', 'a product', 'fixture')
  addedSense = lexicon~addSense('UPSELL', 'V', 'verb.communication', '3', 'UPSELL', 'offer a larger sale', 'fixture')
  addedSense = lexicon~addSense('WARNING', 'N', 'noun.communication', '4', 'WARNING', 'a warning', 'fixture')
  addedSense = lexicon~addSense('DANGER', 'N', 'noun.state', '5', 'DANGER', 'a dangerous state', 'fixture')
  addedSense = lexicon~addSense('MEDICATION', 'N', 'noun.artifact', '6', 'MEDICATION', 'medicine', 'fixture')
  lexicon~buildSoundexIndex

  resolver = .LibrarianResolver~new(lexicon, grammar)
  targetModel = .LibrarianTargetModel~new(lexicon, graph)
  if topicsPath <> '' then targetModel~loadFile(topicsPath)
  targetModel~expand

  gazetteer = .LibrarianGazetteer~new(lexicon)
  gazetteer~installDefaults

  analyzer = .LibrarianAnalyzer~new(lexicon, graph, grammar, resolver, targetModel, gazetteer)
  analyzer~freezeModel
  return analyzer

::class LibrarianDeterministicAnalyzerFactory public
::attribute topicsPath get
::attribute buildCount get
::attribute boundModelManifest get

::method init
  expose topicsPath buildCount boundModelManifest
  use arg topicsPathArg
  topicsPath = topicsPathArg
  buildCount = 0
  boundModelManifest = .nil

::method factoryContractVersion
  return 'LIBRARIAN_ANALYZER_FACTORY_V011'

::method isFrozenFactory
  return 1

::method bindModelManifest
  expose boundModelManifest
  use arg manifest
  if boundModelManifest \== .nil then do
    if boundModelManifest~currentHash \= manifest~currentHash then return 0
    return 1
  end
  boundModelManifest = manifest
  return 1

::method currentModelClosureHash
  expose boundModelManifest topicsPath
  if boundModelManifest \== .nil then return boundModelManifest~currentHash
  return .AlgorithmDigest~sha256Text(.LibrarianDeterministicFixture~canonicalModelText(topicsPath))

::method newAnalyzer
  expose topicsPath buildCount
  buildCount = buildCount + 1
  return .LibrarianDeterministicFixture~buildAnalyzer(topicsPath)

::requires 'LibrarianCore.cls'
::requires 'LibrarianModelManifest.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
