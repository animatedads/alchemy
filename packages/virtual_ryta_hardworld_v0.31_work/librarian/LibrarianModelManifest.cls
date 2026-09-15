/*
 * LibrarianModelManifest.cls
 * Explicit closure identity for all model artefacts that may affect Librarian output.
 *
 * The manifest is intentionally caller-built. Completeness is an assertion the
 * caller must make after adding the complete model closure; the provider will not
 * infer that an arbitrary directory is complete.
 *
 * File paths are retained so currentHash/currentMode re-hash the closure. This lets
 * a lazy NoSQL external engine detect model drift between catalog/registration and
 * first materialisation.
 */

::class LibrarianModelManifest public
::attribute modelId get
::attribute modelVersion get
::attribute complete get

::method init
  expose modelId modelVersion complete filePaths directoryPaths staticFingerprints frozenClosure
  use arg modelIdArg, modelVersionArg
  modelId = modelIdArg
  modelVersion = modelVersionArg
  complete = .false
  frozenClosure = .false
  filePaths = .directory~new
  directoryPaths = .directory~new
  staticFingerprints = .directory~new
  staticFingerprints['MODEL_ID_SHA256'] = .AlgorithmDigest~sha256Text(modelId)
  staticFingerprints['MODEL_VERSION_SHA256'] = .AlgorithmDigest~sha256Text(modelVersion)
  staticFingerprints['MODEL_CLOSURE_CONTRACT_SHA256'] = .LibrarianModelClosureContract~hash

::method addFile
  expose filePaths complete frozenClosure
  use arg label, path
  if frozenClosure then raise syntax 93.900 array('Librarian model manifest closure is frozen')
  complete = .false
  filePaths[label~upper] = path
  return .AlgorithmDigest~sha256File(path)


::method addDirectory
  expose directoryPaths complete frozenClosure
  use arg label, path
  if frozenClosure then raise syntax 93.900 array('Librarian model manifest closure is frozen')
  complete = .false
  directoryPaths[label~upper] = path
  return .true

::method addLogical
  expose staticFingerprints complete frozenClosure
  use arg label, canonicalText
  if frozenClosure then raise syntax 93.900 array('Librarian model manifest closure is frozen')
  complete = .false
  fingerprint = .AlgorithmDigest~sha256Text(canonicalText)
  staticFingerprints[label~upper] = fingerprint
  return fingerprint

::method addFingerprint
  expose staticFingerprints complete frozenClosure
  use arg label, fingerprint
  if frozenClosure then raise syntax 93.900 array('Librarian model manifest closure is frozen')
  complete = .false
  staticFingerprints[label~upper] = fingerprint~string~lower
  return fingerprint

::method buildCurrentManifest private
  expose filePaths directoryPaths staticFingerprints
  current = .AlgorithmSourceManifest~new
  names = staticFingerprints~allIndexes
  names~sort
  do name over names
    fingerprint = staticFingerprints[name]
    if \byLibrarianIsSha256(fingerprint) then current~mode = 'INCOMPLETE'
    current~add(name, fingerprint)
  end
  names = filePaths~allIndexes
  names~sort
  do name over names
    ignore = current~addFile(name, filePaths[name])
  end

  names = directoryPaths~allIndexes
  names~sort
  do name over names
    paths = self~directoryFiles(directoryPaths[name])
    if paths == .nil then do
      current~mode = 'INCOMPLETE'
      current~add(name || '_DIRECTORY_ERROR', 'DIRECTORY_SCAN_ERROR')
      iterate
    end
    current~add(name || '_COUNT_SHA256', .AlgorithmDigest~sha256Text(paths~items))
    ordinal = 0
    do path over paths
      ordinal = ordinal + 1
      label = name || '_' || ('00000' || ordinal)~right(5)
      ignore = current~addFile(label, path)
      current~add(label || '_NAME_SHA256', .AlgorithmDigest~sha256Text(filespec('N', path)))
    end
  end
  return current

::method directoryFiles private
  use arg directoryPath
  paths = .array~new
  signal on syntax name DirectoryScanFailed
  call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
  call SysLoadFuncs
  call SysFileTree directoryPath || '/*', 'librarianManifestFiles.', 'FO'
  signal off syntax
  do i = 1 to librarianManifestFiles.0
    paths~append(librarianManifestFiles.i)
  end
  paths~sort
  return paths
DirectoryScanFailed:
  signal off syntax
  return .nil

::method freezeClosure
  expose frozenClosure complete
  if \complete then do
    current = self~buildCurrentManifest
    complete = current~mode == 'FILE_HASHED'
  end
  if \complete then return 0
  frozenClosure = .true
  return 1

::method isFrozen
  expose frozenClosure
  return frozenClosure

::method markComplete
  expose complete
  current = self~buildCurrentManifest
  complete = current~mode == 'FILE_HASHED'
  return complete

::method mode
  expose complete
  if \complete then return 'INCOMPLETE'
  current = self~buildCurrentManifest
  if current~mode == 'FILE_HASHED' then return 'FILE_HASHED_COMPLETE'
  return 'INCOMPLETE'

::method hash
  return self~currentHash

::method currentHash
  current = self~buildCurrentManifest
  return current~hash

::method canonicalText
  current = self~buildCurrentManifest
  return current~canonicalText

::method render
  current = self~buildCurrentManifest
  return current~render

::routine byLibrarianIsSha256
  use arg value
  if value == .nil then return .false
  value = value~string~lower
  if value~length \== 64 then return .false
  do i = 1 to value~length
    if pos(value~substr(i, 1), '0123456789abcdef') == 0 then return .false
  end
  return .true

/*
 * Convenience builder for the recovered Librarian WordNet loader contract.
 * Code identity remains in the provider source manifest; this builder covers
 * the model/data closure consumed by the analyzer.
 */
::class LibrarianWordNetModelManifestBuilder public

::method build class
  use arg modelId, modelVersion, dictRoot, topicsPath = '', gazetteerPath = '', cachePath = '', skipDbFiles = 0, configurationText = ''
  modelManifest = .LibrarianModelManifest~new(modelId, modelVersion)

  if cachePath <> '' then do
    ignore = modelManifest~addFile('LEXICON_CACHE', cachePath)
    ignore = modelManifest~addLogical('LEXICON_SOURCE_MODE', 'CACHE')
  end
  else do
    ignore = modelManifest~addLogical('LEXICON_SOURCE_MODE', 'WORDNET_FILES')
    ignore = modelManifest~addFile('WORDNET_DATA_NOUN', dictRoot || '/data.noun')
    ignore = modelManifest~addFile('WORDNET_DATA_VERB', dictRoot || '/data.verb')
    ignore = modelManifest~addFile('WORDNET_DATA_ADJ', dictRoot || '/data.adj')
    ignore = modelManifest~addFile('WORDNET_DATA_ADV', dictRoot || '/data.adv')
    ignore = modelManifest~addFile('WORDNET_EXC_NOUN', dictRoot || '/noun.exc')
    ignore = modelManifest~addFile('WORDNET_EXC_VERB', dictRoot || '/verb.exc')
    ignore = modelManifest~addFile('WORDNET_EXC_ADJ', dictRoot || '/adj.exc')
    ignore = modelManifest~addFile('WORDNET_EXC_ADV', dictRoot || '/adv.exc')

    if skipDbFiles = 0 then do
      ignore = modelManifest~addDirectory('DBFILES', dictRoot || '/dbfiles')
      ignore = modelManifest~addLogical('DBFILES_MODE', 'INCLUDED')
    end
    else ignore = modelManifest~addLogical('DBFILES_MODE', 'SKIPPED')
  end

  if topicsPath <> '' then ignore = modelManifest~addFile('TARGET_DEFINITIONS', topicsPath)
  else ignore = modelManifest~addLogical('TARGET_DEFINITIONS', 'NONE')

  if gazetteerPath <> '' then ignore = modelManifest~addFile('GAZETTEER_DEFINITIONS', gazetteerPath)
  else ignore = modelManifest~addLogical('GAZETTEER_DEFINITIONS', 'BUILTIN_OR_NONE')

  config = 'SKIP_DBFILES=' || skipDbFiles || '0a'x || configurationText
  ignore = modelManifest~addLogical('ANALYZER_CONFIGURATION', config)
  ignore = modelManifest~markComplete
  return modelManifest


::requires 'LibrarianModelClosureContract.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
