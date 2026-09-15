/*
 * LibrarianTextAlgorithmProvider.cls
 * v0.11 deterministic text-analysis adapter for the salvaged ooRexx Librarian.
 *
 * Librarian emits evidence/categorisation only.  It does not create HardWorld
 * facts and carries no approval/authority semantics.
 *
 * v0.11 hardening:
 *   - complete manifest + frozen analyzer-factory contract
 *   - fresh frozen analyzer per materialisation
 *   - explicit invocation limits
 *   - duplicate-input provenance via INPUT_ROW_ORDINAL
 *   - selected sense identity
 *   - Soundex candidate evidence
 *   - target contribution vs multi-path provenance relations
 *   - bounded summaries; full target evidence remains normalised
 */

::class LibrarianInvocationLimits public
::attribute maxDocuments get
::attribute maxDocumentBytes get
::attribute maxTokensPerDocument get
::attribute maxObservations get
::attribute maxTargetHits get
::attribute maxTargetProvenanceRows get
::attribute maxResolutionCandidates get

::method init
  expose maxDocuments maxDocumentBytes maxTokensPerDocument maxObservations maxTargetHits maxTargetProvenanceRows maxResolutionCandidates
  use arg docs = 100, bytes = 262144, tokens = 4096, observations = 50000, hits = 50000, provenanceRows = 100000, resolutionCandidates = 100000
  maxDocuments = docs
  maxDocumentBytes = bytes
  maxTokensPerDocument = tokens
  maxObservations = observations
  maxTargetHits = hits
  maxTargetProvenanceRows = provenanceRows
  maxResolutionCandidates = resolutionCandidates

::method canonicalText
  expose maxDocuments maxDocumentBytes maxTokensPerDocument maxObservations maxTargetHits maxTargetProvenanceRows maxResolutionCandidates
  return 'DOCS=' || maxDocuments || ';BYTES=' || maxDocumentBytes || ';TOKENS=' || maxTokensPerDocument || ';OBS=' || maxObservations || ';HITS=' || maxTargetHits || ';PROVENANCE=' || maxTargetProvenanceRows || ';CANDIDATES=' || maxResolutionCandidates


::class LibrarianTextAlgorithmProvider public
::attribute invocationCount
::attribute sourceManifest get
::attribute modelId get
::attribute modelVersion get
::attribute modelFingerprint get
::attribute modelManifest get
::attribute limits get

::method init
  expose sourceManifest analyzerFactory modelId modelVersion modelFingerprint modelManifest invocationCount limits factoryContractOk
  use arg analyzerFactoryArg, modelIdArg, modelVersionArg, modelManifestArg, packageRoot = '', limitsArg = .nil

  invocationCount = 0
  analyzerFactory = analyzerFactoryArg
  modelId = modelIdArg
  modelVersion = modelVersionArg
  modelManifest = modelManifestArg
  limits = limitsArg
  if limits == .nil then limits = .LibrarianInvocationLimits~new

  factoryContractOk = 0
  if analyzerFactory \== .nil then do
    if analyzerFactory~hasMethod('FACTORYCONTRACTVERSION') then do
      if analyzerFactory~hasMethod('ISFROZENFACTORY') then do
        if analyzerFactory~hasMethod('CURRENTMODELCLOSUREHASH') then do
          factoryContractOk = analyzerFactory~isFrozenFactory
          if modelManifest \== .nil then do
            if analyzerFactory~hasMethod('BINDMODELMANIFEST') then do
              if \analyzerFactory~bindModelManifest(modelManifest) then factoryContractOk = 0
            end
            if modelManifest~hasMethod('FREEZECLOSURE') then do
              if \modelManifest~freezeClosure then factoryContractOk = 0
            end
          end
        end
      end
    end
  end

  if modelManifest == .nil then modelFingerprint = 'UNBOUND_MODEL_MANIFEST'
  else modelFingerprint = self~currentModelFingerprint

  sourceManifest = .AlgorithmSourceManifest~new
  if packageRoot == '' then do
    sourceManifest~mode = 'LOGICAL_UNBOUND'
    sourceManifest~add('PROVIDER', 'LibrarianTextAlgorithmProvider.cls')
    sourceManifest~add('LIBRARIAN_CORE', 'LibrarianCore.cls')
    sourceManifest~add('MODEL_CLOSURE_HASH', modelFingerprint)
  end
  else do
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'PROVIDER', 'integration/LibrarianTextAlgorithmProvider.cls')
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'LIBRARIAN_CORE', 'librarian/LibrarianCore.cls')
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'LIBRARIAN_ORIGINAL', 'librarian/source/librarian_wordnet_oorexx.rex.original')
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'ALGORITHM_INPUT', 'algorithm/AlgorithmInputRelation.cls')
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'ALGORITHM_INPUT_CONSISTENCY', 'algorithm/AlgorithmInputConsistency.cls')
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'ALGORITHM_RELATION', 'algorithm/AlgorithmRelation.cls')
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'LIBRARIAN_MODEL_MANIFEST', 'librarian/LibrarianModelManifest.cls')
    ignore = self~addSourceFile(sourceManifest, packageRoot, 'LIBRARIAN_MODEL_CLOSURE_CONTRACT', 'librarian/LibrarianModelClosureContract.cls')
    sourceManifest~add('MODEL_CLOSURE_CONTRACT_HASH', .LibrarianModelClosureContract~hash)
    sourceManifest~add('MODEL_CLOSURE_HASH', modelFingerprint)
    sourceManifest~add('INVOCATION_LIMITS_SHA256', .AlgorithmDigest~sha256Text(limits~canonicalText))
    if \bySourceIsSha256(modelFingerprint) then sourceManifest~mode = 'INCOMPLETE'
    if modelManifest == .nil then sourceManifest~mode = 'INCOMPLETE'
    else if modelManifest~mode \= 'FILE_HASHED_COMPLETE' then sourceManifest~mode = 'INCOMPLETE'
    if \factoryContractOk then sourceManifest~mode = 'INCOMPLETE'
  end

::method addSourceFile private
  use arg manifest, packageRoot, label, relativePath
  if packageRoot~right(1) == '/' then filePath = packageRoot || relativePath
  else filePath = packageRoot || '/' || relativePath
  return manifest~addFile(label, filePath)

::method algorithmId
  return 'LIBRARIAN_TEXT'

::method algorithmVersion
  return 'LIBRARIAN-ALGREL-0.14'

::method sourceComponent
  return 'LIBRARIAN_WORDNET_OOREXX'

::method sourceVersion
  return 'V27-SALVAGE-HARDENED-0.11'

::method currentModelFingerprint private
  expose modelManifest modelFingerprint analyzerFactory
  if modelManifest == .nil then return modelFingerprint
  manifestHash = modelManifest~currentHash
  factoryHash = 'UNBOUND_FACTORY_CLOSURE'
  if analyzerFactory \== .nil then do
    if analyzerFactory~hasMethod('CURRENTMODELCLOSUREHASH') then factoryHash = analyzerFactory~currentModelClosureHash
  end
  return .AlgorithmDigest~sha256Text('LIBRARIAN_MODEL_CLOSURE_V011' || '0a'x || 'MANIFEST=' || manifestHash || '0a'x || 'FACTORY=' || factoryHash || '0a'x)

::method sourceFingerprint
  return self~currentModelFingerprint

::method sourceManifestHash
  expose sourceManifest
  baseHash = sourceManifest~hash
  currentModelHash = self~currentModelFingerprint
  return .AlgorithmDigest~sha256Text('LIBRARIAN_PROVIDER_SOURCE_V014' || '0a'x || 'BASE=' || baseHash || '0a'x || 'MODEL=' || currentModelHash || '0a'x)

::method sourceManifestMode
  expose sourceManifest
  return sourceManifest~mode

::method determinism
  expose modelManifest analyzerFactory factoryContractOk
  if self~sourceManifestMode \= 'FILE_HASHED' then return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
  if modelManifest == .nil then return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
  if modelManifest~mode \= 'FILE_HASHED_COMPLETE' then return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
  if \factoryContractOk then return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
  if analyzerFactory == .nil then return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
  if \analyzerFactory~isFrozenFactory then return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
  if analyzerFactory~currentModelClosureHash \= modelManifest~currentHash then return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
  return .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT

::method sideEffectClass
  return 'NONE'

::method defaultMaterializePolicy
  return .AlgorithmRelationConstant~MATERIALIZE_ONCE

::method inputContract
  return 'AlgorithmInputRelationSnapshot:LIBRARIAN_TEXT_SOURCE_V4;CONSISTENCY=EXPLICIT;ORDER_MODE=EXPLICIT;BAG_UNORDERED=INDEPENDENT_DOCUMENTS;ORDERED=CALLER_SEQUENCE;LIMITS=EXPLICIT'

::method canonicalInput
  expose limits
  use arg inputSnapshot, context
  canonical = inputSnapshot~algorithmCanonicalText
  canonical = canonical || 'LIBRARIAN_MODEL_ID=' || self~modelId || '0a'x
  canonical = canonical || 'LIBRARIAN_MODEL_VERSION=' || self~modelVersion || '0a'x
  canonical = canonical || 'LIBRARIAN_MODEL_CLOSURE_HASH=' || self~currentModelFingerprint || '0a'x
  canonical = canonical || 'INPUT_ORDER_MODE=' || inputSnapshot~orderMode || '0a'x
  canonical = canonical || 'INVOCATION_LIMITS=' || limits~canonicalText || '0a'x
  return canonical

::method declaredSchemas
  schemas = .array~new
  schemas~append(self~documentSchema)
  schemas~append(self~sentenceSchema)
  schemas~append(self~wordSchema)
  schemas~append(self~targetHitSchema)
  schemas~append(self~targetHitProvenanceSchema)
  schemas~append(self~resolutionCandidateSchema)
  schemas~append(self~errorSchema)
  schemas~append(self~traceSchema)
  return schemas

::method documentSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_DOCUMENT_ANALYSIS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_ROW_ORDINAL', 'INTEGER', .false)
  schema~add('INPUT_SNAPSHOT_OID', 'OID', .false)
  schema~add('INPUT_CONTENT_HASH', 'TEXT', .false)
  schema~addEnum('INPUT_CONSISTENCY_GRADE', 'TEXT', .false, .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT'))
  schema~add('INPUT_CONSISTENCY_HASH', 'TEXT', .false)
  schema~add('MODEL_ID', 'TEXT', .false)
  schema~add('MODEL_VERSION', 'TEXT', .false)
  schema~add('MODEL_FINGERPRINT', 'TEXT', .false)
  schema~add('INPUT_ORDER_MODE', 'TEXT', .false)
  schema~add('DOCUMENT_ID', 'TEXT', .false)
  schema~add('ARTICLE_SCORE', 'NUMBER', .false)
  schema~add('TARGET_SCORE', 'NUMBER', .false)
  schema~add('PARAGRAPH_COUNT', 'INTEGER', .false)
  schema~add('TARGET_HIT_COUNT', 'INTEGER', .false)
  schema~add('TARGET_SECTIONS', 'TEXT', .false)
  schema~add('CONCEPTS', 'TEXT', .false)
  schema~add('INDICATORS', 'TEXT', .false)
  return schema

::method sentenceSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_SENTENCE_ANALYSIS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_ROW_ORDINAL', 'INTEGER', .false)
  schema~addEnum('INPUT_CONSISTENCY_GRADE', 'TEXT', .false, .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT'))
  schema~add('INPUT_CONSISTENCY_HASH', 'TEXT', .false)
  schema~add('DOCUMENT_ID', 'TEXT', .false)
  schema~add('PARAGRAPH_NO', 'INTEGER', .false)
  schema~add('SENTENCE_NO', 'INTEGER', .false)
  schema~add('TEXT', 'TEXT', .false)
  schema~add('SCORE', 'NUMBER', .false)
  schema~add('TARGET_SCORE', 'NUMBER', .false)
  schema~add('TARGET_HIT_COUNT', 'INTEGER', .false)
  schema~add('SEQUENCE', 'TEXT', .false)
  schema~add('CONCEPTS', 'TEXT', .false)
  schema~add('INDICATOR', 'TEXT', .false)
  return schema

::method wordSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_WORD_OBSERVATIONS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_ROW_ORDINAL', 'INTEGER', .false)
  schema~addEnum('INPUT_CONSISTENCY_GRADE', 'TEXT', .false, .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT'))
  schema~add('INPUT_CONSISTENCY_HASH', 'TEXT', .false)
  schema~add('DOCUMENT_ID', 'TEXT', .false)
  schema~add('PARAGRAPH_NO', 'INTEGER', .false)
  schema~add('SENTENCE_NO', 'INTEGER', .false)
  schema~add('WORD_NO', 'TEXT', .false)
  schema~add('COORDINATE', 'TEXT', .false)
  schema~add('RAW_TEXT', 'TEXT', .false)
  schema~add('NORMALISED_SURFACE', 'TEXT', .false)
  schema~add('CLEAN_TEXT', 'TEXT', .false)
  schema~add('COMPACT_MATCH_KEY', 'TEXT', .false)
  schema~add('RESOLVED_KEY', 'TEXT', .false)
  schema~add('RESOLVED_POS', 'TEXT', .false)
  schema~add('RESOLVED_SENSE_OFFSET', 'TEXT', .true)
  schema~add('RESOLVED_LEX_CATEGORY', 'TEXT', .true)
  schema~add('RESOLVED_SENSE_SOURCE', 'TEXT', .true)
  schema~add('PERCEIVED_ROLE', 'TEXT', .false)
  schema~add('RELATION_ROLE', 'TEXT', .false)
  schema~add('RESOLUTION_SOURCE', 'TEXT', .false)
  schema~add('CONFIDENCE', 'NUMBER', .false)
  schema~add('LEXICAL_SCORE', 'NUMBER', .false)
  schema~add('TARGET_SCORE', 'NUMBER', .false)
  schema~add('TARGET_HIT_COUNT', 'INTEGER', .false)
  return schema

::method targetHitSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_TARGET_HITS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_ROW_ORDINAL', 'INTEGER', .false)
  schema~addEnum('INPUT_CONSISTENCY_GRADE', 'TEXT', .false, .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT'))
  schema~add('INPUT_CONSISTENCY_HASH', 'TEXT', .false)
  schema~add('DOCUMENT_ID', 'TEXT', .false)
  schema~add('PARAGRAPH_NO', 'INTEGER', .false)
  schema~add('SENTENCE_NO', 'INTEGER', .false)
  schema~add('WORD_NO', 'TEXT', .false)
  schema~add('COORDINATE', 'TEXT', .false)
  schema~add('RAW_TEXT', 'TEXT', .false)
  schema~add('NORMALISED_SURFACE', 'TEXT', .false)
  schema~add('CLEAN_TEXT', 'TEXT', .false)
  schema~add('COMPACT_MATCH_KEY', 'TEXT', .false)
  schema~add('RESOLVED_KEY', 'TEXT', .false)
  schema~add('RESOLVED_POS', 'TEXT', .false)
  schema~add('RESOLVED_SENSE_OFFSET', 'TEXT', .true)
  schema~add('RESOLVED_LEX_CATEGORY', 'TEXT', .true)
  schema~add('RESOLVED_SENSE_SOURCE', 'TEXT', .true)
  schema~add('RESOLUTION_SOURCE', 'TEXT', .false)
  schema~add('CONFIDENCE', 'NUMBER', .false)
  schema~add('MATCH_BASIS', 'TEXT', .false)
  schema~add('SECTION', 'TEXT', .false)
  schema~add('TARGET_KEY', 'TEXT', .false)
  schema~add('TARGET_POS', 'TEXT', .false)
  schema~add('WEIGHT', 'NUMBER', .false)
  schema~add('SOURCE_SEED', 'TEXT', .false)
  schema~add('EXPANSION_RULE', 'TEXT', .false)
  schema~add('CONTRIBUTION_KEY', 'TEXT', .false)
  return schema

::method targetHitProvenanceSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_TARGET_HIT_PROVENANCE')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_ROW_ORDINAL', 'INTEGER', .false)
  schema~addEnum('INPUT_CONSISTENCY_GRADE', 'TEXT', .false, .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT'))
  schema~add('INPUT_CONSISTENCY_HASH', 'TEXT', .false)
  schema~add('DOCUMENT_ID', 'TEXT', .false)
  schema~add('COORDINATE', 'TEXT', .false)
  schema~add('SECTION', 'TEXT', .false)
  schema~add('TARGET_KEY', 'TEXT', .false)
  schema~add('TARGET_POS', 'TEXT', .false)
  schema~add('WEIGHT', 'NUMBER', .false)
  schema~add('SOURCE_SEED', 'TEXT', .false)
  schema~add('EXPANSION_RULE', 'TEXT', .false)
  schema~add('CONTRIBUTION_KEY', 'TEXT', .false)
  schema~add('CONTRIBUTES_SCORE', 'BOOLEAN', .false)
  return schema

::method resolutionCandidateSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_RESOLUTION_CANDIDATES')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_ROW_ORDINAL', 'INTEGER', .false)
  schema~add('DOCUMENT_ID', 'TEXT', .false)
  schema~add('COORDINATE', 'TEXT', .false)
  schema~add('CANDIDATE_KEY', 'TEXT', .false)
  schema~add('CANDIDATE_POS', 'TEXT', .true)
  schema~add('METHOD', 'TEXT', .false)
  schema~add('DISTANCE', 'INTEGER', .false)
  schema~add('ACCEPTED', 'BOOLEAN', .false)
  schema~add('SELECTED', 'BOOLEAN', .false)
  return schema

::method errorSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_ANALYSIS_ERRORS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_ROW_NO', 'INTEGER', .false)
  schema~add('ERROR_CODE', 'TEXT', .false)
  schema~add('DETAIL', 'TEXT', .false)
  return schema

::method traceSchema
  schema = .AlgorithmSchema~new('LIBRARIAN_TRACE')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('SEQUENCE', 'INTEGER', .false)
  schema~add('EVENT_TEXT', 'TEXT', .false)
  return schema

::method evaluate
  expose analyzerFactory invocationCount limits modelManifest
  use arg inputSnapshot, context
  invocationCount = invocationCount + 1

  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId, self~algorithmVersion, self~sourceComponent, self~sourceVersion, self~sourceFingerprint, self~sourceManifestHash, context)
  documents = .AlgorithmRelation~new(self~documentSchema)
  sentences = .AlgorithmRelation~new(self~sentenceSchema)
  observations = .AlgorithmRelation~new(self~wordSchema)
  targetHits = .AlgorithmRelation~new(self~targetHitSchema)
  hitProvenance = .AlgorithmRelation~new(self~targetHitProvenanceSchema)
  resolutionCandidates = .AlgorithmRelation~new(self~resolutionCandidateSchema)
  errors = .AlgorithmRelation~new(self~errorSchema)
  traceRelation = .AlgorithmRelation~new(self~traceSchema)

  algorithmResult~addTrace('PROVIDER LIBRARIAN_TEXT invocation=' || invocationCount)
  algorithmResult~addTrace('INPUT relation=' || inputSnapshot~relationName || ' rows=' || inputSnapshot~rowCount || ' content_hash=' || inputSnapshot~contentHash || ' consistency=' || inputSnapshot~consistencyGrade || ' consistency_hash=' || inputSnapshot~consistencyHash)
  algorithmResult~addTrace('LIMITS ' || limits~canonicalText)

  acceptedRows = self~preflightRows(inputSnapshot, errors, context~invocationId)
  if acceptedRows~items = 0 then return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)

  if analyzerFactory == .nil then do
    ignore = self~appendError(errors, context~invocationId, 0, 'ANALYZER_FACTORY_MISSING', 'No analyzer factory')
    return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)
  end

  if modelManifest \== .nil then do
    if analyzerFactory~hasMethod('CURRENTMODELCLOSUREHASH') then do
      if analyzerFactory~currentModelClosureHash \= modelManifest~currentHash then do
        ignore = self~appendError(errors, context~invocationId, 0, 'MODEL_CLOSURE_DRIFT', 'Analyzer factory closure no longer matches published model manifest')
        return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)
      end
    end
  end

  analyzer = analyzerFactory~newAnalyzer
  if analyzer == .nil then do
    ignore = self~appendError(errors, context~invocationId, 0, 'ANALYZER_FACTORY_FAILED', 'Factory returned NIL analyzer')
    return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)
  end
  if \analyzer~hasMethod('MODELFROZEN') then do
    ignore = self~appendError(errors, context~invocationId, 0, 'MODEL_NOT_FROZEN', 'Analyzer does not expose frozen model state')
    return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)
  end
  if \analyzer~modelFrozen then do
    ignore = self~appendError(errors, context~invocationId, 0, 'MODEL_NOT_FROZEN', 'Analyzer model closure is mutable')
    return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)
  end
  if analyzer~targetModel~hasMethod('ISVALID') then do
    if \analyzer~targetModel~isValid then do
      ignore = self~appendError(errors, context~invocationId, 0, 'TARGET_MODEL_INVALID', 'Target model contains conflicting declarations')
      return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)
    end
  end

  totalObservations = 0
  totalHits = 0
  totalProvenanceRows = 0
  totalResolutionCandidates = 0
  traceSequence = 0

  do accepted over acceptedRows
    inputRowNo = accepted~at(1)
    inputRow = accepted~at(2)
    documentId = inputRow~value('DOCUMENT_ID')
    documentText = inputRow~value('TEXT')

    article = .LibrarianArticle~new(documentId, documentText)
    analysisError = self~analyseSafely(analyzer, article)
    if analysisError <> '' then do
      ignore = self~appendError(errors, context~invocationId, inputRowNo, 'ANALYSIS_RUNTIME_ERROR', analysisError)
      iterate
    end

    docHitCount = 0
    docSections = ''
    overflowed = 0
    do paragraph over article~paragraphs
      do sentence over paragraph~sentences
        sentenceHitCount = 0
        do wordUse over sentence~uses
          useHitCount = wordUse~targetHitsArray~items
          sentenceHitCount = sentenceHitCount + useHitCount
          docHitCount = docHitCount + useHitCount
          totalObservations = totalObservations + 1
          totalHits = totalHits + useHitCount
          totalProvenanceRows = totalProvenanceRows + wordUse~targetHitProvenanceArray~items
          if wordUse~resolutionSource~left(8) == 'soundex:' then totalResolutionCandidates = totalResolutionCandidates + wordUse~candidateWords~items
          do term over wordUse~targetHitsArray
            docSections = AddUniqueWord(docSections, term~section)
          end
        end

        if totalObservations > limits~maxObservations then do
          ignore = self~appendError(errors, context~invocationId, inputRowNo, 'LIMIT_OBSERVATIONS', 'Maximum emitted observations exceeded')
          overflowed = 1
          leave
        end
        if totalHits > limits~maxTargetHits then do
          ignore = self~appendError(errors, context~invocationId, inputRowNo, 'LIMIT_TARGET_HITS', 'Maximum emitted target hits exceeded')
          overflowed = 1
          leave
        end
        if totalProvenanceRows > limits~maxTargetProvenanceRows then do
          ignore = self~appendError(errors, context~invocationId, inputRowNo, 'LIMIT_TARGET_PROVENANCE', 'Maximum emitted target-hit provenance rows exceeded')
          overflowed = 1
          leave
        end
        if totalResolutionCandidates > limits~maxResolutionCandidates then do
          ignore = self~appendError(errors, context~invocationId, inputRowNo, 'LIMIT_RESOLUTION_CANDIDATES', 'Maximum emitted resolution candidates exceeded')
          overflowed = 1
          leave
        end

        sentenceRow = sentences~newRow
        ignore = sentenceRow~put('INVOCATION_ID', context~invocationId)
        ignore = sentenceRow~put('INPUT_ROW_ORDINAL', inputRowNo)
        ignore = sentenceRow~put('INPUT_CONSISTENCY_GRADE', inputSnapshot~consistencyGrade)
        ignore = sentenceRow~put('INPUT_CONSISTENCY_HASH', inputSnapshot~consistencyHash)
        ignore = sentenceRow~put('DOCUMENT_ID', documentId)
        ignore = sentenceRow~put('PARAGRAPH_NO', paragraph~paragraphNo)
        ignore = sentenceRow~put('SENTENCE_NO', sentence~sentenceNo)
        ignore = sentenceRow~put('TEXT', sentence~text)
        ignore = sentenceRow~put('SCORE', sentence~score)
        ignore = sentenceRow~put('TARGET_SCORE', sentence~targetScore)
        ignore = sentenceRow~put('TARGET_HIT_COUNT', sentenceHitCount)
        ignore = sentenceRow~put('SEQUENCE', sentence~sequence)
        ignore = sentenceRow~put('CONCEPTS', sentence~concepts)
        ignore = sentenceRow~put('INDICATOR', sentence~indicator)
        ignore = sentences~addRow(sentenceRow)

        do wordUse over sentence~uses
          ignore = self~appendWordObservation(observations, context~invocationId, inputRowNo, inputSnapshot~consistencyGrade, inputSnapshot~consistencyHash, documentId, wordUse)
          do term over wordUse~targetHitsArray
            ignore = self~appendTargetHit(targetHits, context~invocationId, inputRowNo, inputSnapshot~consistencyGrade, inputSnapshot~consistencyHash, documentId, wordUse, term)
          end
          do term over wordUse~targetHitProvenanceArray
            ignore = self~appendTargetHitProvenance(hitProvenance, context~invocationId, inputRowNo, inputSnapshot~consistencyGrade, inputSnapshot~consistencyHash, documentId, wordUse, term)
          end
          if wordUse~resolutionSource~left(8) == 'soundex:' then do
            do candidate over wordUse~candidateWords
              ignore = self~appendResolutionCandidate(resolutionCandidates, context~invocationId, inputRowNo, documentId, wordUse, candidate)
            end
          end
        end
      end
      if overflowed then leave
    end

    if overflowed then iterate

    docRow = documents~newRow
    ignore = docRow~put('INVOCATION_ID', context~invocationId)
    ignore = docRow~put('INPUT_ROW_ORDINAL', inputRowNo)
    ignore = docRow~put('INPUT_SNAPSHOT_OID', inputSnapshot~sourceOid)
    ignore = docRow~put('INPUT_CONTENT_HASH', inputSnapshot~contentHash)
    ignore = docRow~put('INPUT_CONSISTENCY_GRADE', inputSnapshot~consistencyGrade)
    ignore = docRow~put('INPUT_CONSISTENCY_HASH', inputSnapshot~consistencyHash)
    ignore = docRow~put('MODEL_ID', self~modelId)
    ignore = docRow~put('MODEL_VERSION', self~modelVersion)
    ignore = docRow~put('MODEL_FINGERPRINT', self~currentModelFingerprint)
    ignore = docRow~put('INPUT_ORDER_MODE', inputSnapshot~orderMode)
    ignore = docRow~put('DOCUMENT_ID', documentId)
    ignore = docRow~put('ARTICLE_SCORE', article~score)
    ignore = docRow~put('TARGET_SCORE', article~targetScore)
    ignore = docRow~put('PARAGRAPH_COUNT', article~paragraphs~items)
    ignore = docRow~put('TARGET_HIT_COUNT', docHitCount)
    ignore = docRow~put('TARGET_SECTIONS', docSections)
    ignore = docRow~put('CONCEPTS', article~concepts)
    ignore = docRow~put('INDICATORS', article~indicators)
    ignore = documents~addRow(docRow)

    traceSequence = traceSequence + 1
    traceRow = traceRelation~newRow
    ignore = traceRow~put('INVOCATION_ID', context~invocationId)
    ignore = traceRow~put('SEQUENCE', traceSequence)
    eventText = 'DOCUMENT row=' || inputRowNo || ' id=' || documentId || ' score=' || article~score || ' target=' || article~targetScore || ' hits=' || docHitCount
    ignore = traceRow~put('EVENT_TEXT', eventText)
    ignore = traceRelation~addRow(traceRow)
  end

  return self~finishResult(algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation)

::method preflightRows private
  expose limits
  use arg inputSnapshot, errors, invocationId
  acceptedRows = .Array~new
  inputRowNo = 0
  do inputRow over inputSnapshot~rows
    inputRowNo = inputRowNo + 1
    if inputRowNo > limits~maxDocuments then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'LIMIT_DOCUMENTS', 'Maximum documents per invocation exceeded')
      iterate
    end
    if \inputRow~hasValue('DOCUMENT_ID') then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'MISSING_DOCUMENT_ID', 'DOCUMENT_ID column is required')
      iterate
    end
    if \inputRow~hasValue('TEXT') then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'MISSING_TEXT', 'TEXT column is required')
      iterate
    end

    documentId = inputRow~value('DOCUMENT_ID')
    documentText = inputRow~value('TEXT')
    if documentId == .nil then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'INVALID_DOCUMENT_ID', 'DOCUMENT_ID must be non-empty TEXT')
      iterate
    end
    if documentId~class \== .String then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'INVALID_DOCUMENT_ID', 'DOCUMENT_ID must be non-empty TEXT')
      iterate
    end
    if documentId~strip == '' then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'INVALID_DOCUMENT_ID', 'DOCUMENT_ID must be non-empty TEXT')
      iterate
    end
    if documentText == .nil then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'INVALID_TEXT', 'TEXT must be TEXT and may be empty')
      iterate
    end
    if documentText~class \== .String then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'INVALID_TEXT', 'TEXT must be TEXT and may be empty')
      iterate
    end
    if documentText~length > limits~maxDocumentBytes then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'LIMIT_DOCUMENT_BYTES', 'Document exceeds maximum byte/character envelope')
      iterate
    end
    tokenCount = words(Tokenise(documentText))
    if tokenCount > limits~maxTokensPerDocument then do
      ignore = self~appendError(errors, invocationId, inputRowNo, 'LIMIT_TOKENS_PER_DOCUMENT', 'Document token count exceeds limit')
      iterate
    end
    acceptedRows~append(.Array~of(inputRowNo, inputRow))
  end
  return acceptedRows

::method analyseSafely private
  use arg analyzer, article
  signal on syntax name AnalysisFailed
  analyzer~analyseArticle(article)
  signal off syntax
  return ''
AnalysisFailed:
  signal off syntax
  return 'ooRexx syntax failure while analysing document'

::method appendWordObservation private
  use arg relation, invocationId, inputRowNo, consistencyGrade, consistencyHash, documentId, wordUse
  row = relation~newRow
  ignore = row~put('INVOCATION_ID', invocationId)
  ignore = row~put('INPUT_ROW_ORDINAL', inputRowNo)
  ignore = row~put('INPUT_CONSISTENCY_GRADE', consistencyGrade)
  ignore = row~put('INPUT_CONSISTENCY_HASH', consistencyHash)
  ignore = row~put('DOCUMENT_ID', documentId)
  ignore = row~put('PARAGRAPH_NO', wordUse~paragraphNo)
  ignore = row~put('SENTENCE_NO', wordUse~sentenceNo)
  ignore = row~put('WORD_NO', wordUse~wordNo || '')
  ignore = row~put('COORDINATE', wordUse~coordinate)
  ignore = row~put('RAW_TEXT', wordUse~rawText)
  ignore = row~put('NORMALISED_SURFACE', translate(strip(wordUse~rawText)))
  ignore = row~put('CLEAN_TEXT', wordUse~cleanText)
  ignore = row~put('COMPACT_MATCH_KEY', CompactKey(wordUse~cleanText))
  ignore = row~put('RESOLVED_KEY', wordUse~resolvedKey)
  ignore = row~put('RESOLVED_POS', wordUse~resolvedPos)
  ignore = self~putSenseColumns(row, wordUse)
  ignore = row~put('PERCEIVED_ROLE', wordUse~perceivedRole)
  ignore = row~put('RELATION_ROLE', wordUse~relationRole)
  ignore = row~put('RESOLUTION_SOURCE', wordUse~resolutionSource)
  ignore = row~put('CONFIDENCE', wordUse~confidence)
  ignore = row~put('LEXICAL_SCORE', wordUse~score)
  ignore = row~put('TARGET_SCORE', wordUse~targetScore)
  ignore = row~put('TARGET_HIT_COUNT', wordUse~targetHitsArray~items)
  return relation~addRow(row)

::method appendTargetHit private
  use arg relation, invocationId, inputRowNo, consistencyGrade, consistencyHash, documentId, wordUse, term
  row = relation~newRow
  ignore = row~put('INVOCATION_ID', invocationId)
  ignore = row~put('INPUT_ROW_ORDINAL', inputRowNo)
  ignore = row~put('INPUT_CONSISTENCY_GRADE', consistencyGrade)
  ignore = row~put('INPUT_CONSISTENCY_HASH', consistencyHash)
  ignore = row~put('DOCUMENT_ID', documentId)
  ignore = row~put('PARAGRAPH_NO', wordUse~paragraphNo)
  ignore = row~put('SENTENCE_NO', wordUse~sentenceNo)
  ignore = row~put('WORD_NO', wordUse~wordNo || '')
  ignore = row~put('COORDINATE', wordUse~coordinate)
  ignore = row~put('RAW_TEXT', wordUse~rawText)
  ignore = row~put('NORMALISED_SURFACE', translate(strip(wordUse~rawText)))
  ignore = row~put('CLEAN_TEXT', wordUse~cleanText)
  ignore = row~put('COMPACT_MATCH_KEY', CompactKey(wordUse~cleanText))
  ignore = row~put('RESOLVED_KEY', wordUse~resolvedKey)
  ignore = row~put('RESOLVED_POS', wordUse~resolvedPos)
  ignore = self~putSenseColumns(row, wordUse)
  ignore = row~put('RESOLUTION_SOURCE', wordUse~resolutionSource)
  ignore = row~put('CONFIDENCE', wordUse~confidence)
  ignore = row~put('MATCH_BASIS', self~targetMatchBasis(wordUse, term))
  ignore = row~put('SECTION', term~section)
  ignore = row~put('TARGET_KEY', term~key)
  ignore = row~put('TARGET_POS', term~posKind)
  ignore = row~put('WEIGHT', term~weight)
  ignore = row~put('SOURCE_SEED', term~sourceSeed)
  ignore = row~put('EXPANSION_RULE', term~expansionSource)
  ignore = row~put('CONTRIBUTION_KEY', self~contributionKey(term))
  return relation~addRow(row)

::method appendTargetHitProvenance private
  use arg relation, invocationId, inputRowNo, consistencyGrade, consistencyHash, documentId, wordUse, term
  row = relation~newRow
  ignore = row~put('INVOCATION_ID', invocationId)
  ignore = row~put('INPUT_ROW_ORDINAL', inputRowNo)
  ignore = row~put('INPUT_CONSISTENCY_GRADE', consistencyGrade)
  ignore = row~put('INPUT_CONSISTENCY_HASH', consistencyHash)
  ignore = row~put('DOCUMENT_ID', documentId)
  ignore = row~put('COORDINATE', wordUse~coordinate)
  ignore = row~put('SECTION', term~section)
  ignore = row~put('TARGET_KEY', term~key)
  ignore = row~put('TARGET_POS', term~posKind)
  ignore = row~put('WEIGHT', term~weight)
  ignore = row~put('SOURCE_SEED', term~sourceSeed)
  ignore = row~put('EXPANSION_RULE', term~expansionSource)
  ignore = row~put('CONTRIBUTION_KEY', self~contributionKey(term))
  ignore = row~put('CONTRIBUTES_SCORE', self~termContributes(wordUse, term))
  return relation~addRow(row)

::method appendResolutionCandidate private
  use arg relation, invocationId, inputRowNo, documentId, wordUse, candidate
  row = relation~newRow
  ignore = row~put('INVOCATION_ID', invocationId)
  ignore = row~put('INPUT_ROW_ORDINAL', inputRowNo)
  ignore = row~put('DOCUMENT_ID', documentId)
  ignore = row~put('COORDINATE', wordUse~coordinate)
  ignore = row~put('CANDIDATE_KEY', candidate~key)
  candidatePos = .nil
  sense = candidate~primarySense('')
  if sense \== .nil then candidatePos = sense~posKind
  ignore = row~put('CANDIDATE_POS', candidatePos)
  ignore = row~put('METHOD', wordUse~resolutionSource)
  ignore = row~put('DISTANCE', EditDistance(wordUse~cleanText, candidate~key))
  ignore = row~put('ACCEPTED', 1)
  selected = candidate~key == wordUse~resolvedKey
  ignore = row~put('SELECTED', selected)
  return relation~addRow(row)

::method putSenseColumns private
  use arg row, wordUse
  sense = wordUse~senseObj
  if sense == .nil then do
    ignore = row~put('RESOLVED_SENSE_OFFSET', .nil)
    ignore = row~put('RESOLVED_LEX_CATEGORY', .nil)
    ignore = row~put('RESOLVED_SENSE_SOURCE', .nil)
    return 1
  end
  ignore = row~put('RESOLVED_SENSE_OFFSET', sense~offset || '')
  ignore = row~put('RESOLVED_LEX_CATEGORY', sense~lexCategory)
  ignore = row~put('RESOLVED_SENSE_SOURCE', sense~sourceFile)
  return 1

::method contributionKey private
  use arg term
  return term~section || ':' || term~sourceSeed || ':' || term~key || '/' || term~posKind

::method termContributes private
  use arg wordUse, provenanceTerm
  key = self~contributionKey(provenanceTerm)
  do selectedTerm over wordUse~targetHitsArray
    if self~contributionKey(selectedTerm) == key then return 1
  end
  return 0

::method targetMatchBasis private
  use arg wordUse, term
  targetKey = term~key
  if wordUse~cleanText == targetKey then return 'CANONICAL_LEXICAL_KEY'
  if CompactKey(wordUse~cleanText) == targetKey then return 'COMPACT_MATCH_KEY'
  if wordUse~resolvedKey == targetKey then return 'RESOLVED_KEY'
  if CompactKey(wordUse~resolvedKey) == targetKey then return 'RESOLVED_COMPACT'
  if wordUse~wordObj \== .nil then do
    if wordUse~wordObj~key == targetKey then return 'WORD_OBJECT_KEY'
  end
  if BasicMorphKey(wordUse~cleanText) == targetKey then return 'BASIC_MORPH'
  return 'TARGET_PROBE'

::method finishResult private
  use arg algorithmResult, documents, sentences, observations, targetHits, hitProvenance, resolutionCandidates, errors, traceRelation
  ignore = algorithmResult~addRelation(documents)
  ignore = algorithmResult~addRelation(sentences)
  ignore = algorithmResult~addRelation(observations)
  ignore = algorithmResult~addRelation(targetHits)
  ignore = algorithmResult~addRelation(hitProvenance)
  ignore = algorithmResult~addRelation(resolutionCandidates)
  ignore = algorithmResult~addRelation(errors)
  ignore = algorithmResult~addRelation(traceRelation)
  return algorithmResult

::method appendError private
  use arg errorsRelation, invocationId, rowNo, errorCode, detailText
  errorRow = errorsRelation~newRow
  ignore = errorRow~put('INVOCATION_ID', invocationId)
  ignore = errorRow~put('INPUT_ROW_NO', rowNo)
  ignore = errorRow~put('ERROR_CODE', errorCode)
  ignore = errorRow~put('DETAIL', detailText)
  return errorsRelation~addRow(errorRow)

::routine bySourceIsSha256
  use arg value
  if value == .nil then return .false
  value = value~lower
  if value~length \== 64 then return .false
  do i = 1 to value~length
    if pos(value~substr(i, 1), '0123456789abcdef') == 0 then return .false
  end
  return .true

::requires '../librarian/LibrarianCore.cls'
::requires '../librarian/LibrarianModelManifest.cls'
::requires '../librarian/LibrarianModelClosureContract.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
