/*
 * AlgorithmIntegrity.cls
 * Content-addressed identity helpers for Algorithm Relation v0.4.
 * SHA-256 is obtained through the host sha256sum utility; the digest service is
 * isolated here so a future platform-specific/native implementation can replace it.
 */

::class AlgorithmDigest public

::method sha256Text class
  use arg text
  tempPath = SysTempFileName(.File~new('algrel.????????', .File~temporaryPath)~string)
  streamObject = .Stream~new(tempPath)
  openStatus = streamObject~open('WRITE REPLACE')
  if openStatus \== 'READY:' then return 'HASH_ERROR_OPEN'
  written = streamObject~charout(text)
  closeStatus = streamObject~close
  digest = self~sha256File(tempPath)
  deleteStatus = SysFileDelete(tempPath)
  return digest

::method sha256File class
  use arg filePath
  if \SysFileExists(filePath) then return 'HASH_ERROR_NO_FILE'
  outputLines = .array~new
  errorLines = .array~new
  commandText = 'sha256sum -- "' || filePath || '"'
  address system commandText with output using (outputLines) error using (errorLines)
  if outputLines~items == 0 then return 'HASH_ERROR_COMMAND'
  hashLine = outputLines[1]
  parse var hashLine digest .
  if digest~length \== 64 then return 'HASH_ERROR_FORMAT'
  return digest~lower


::class AlgorithmSourceManifest public
::attribute entries get
::attribute mode

::method init
  expose entries
  entries = .directory~new
  self~mode = 'FILE_HASHED'

::method add
  expose entries
  use arg label, fingerprint
  key = label~upper
  entries[key] = fingerprint
  return fingerprint

::method addFile
  use arg label, filePath
  fingerprint = .AlgorithmDigest~sha256File(filePath)
  if fingerprint~left(10) == 'HASH_ERROR' then do
    self~mode = 'INCOMPLETE'
  end
  return self~add(label, fingerprint)

::method canonicalText
  expose entries
  names = entries~allIndexes
  names~sort
  canonical = ''
  do name over names
    canonical = canonical || name || '=' || entries[name] || '0a'x
  end
  return canonical

::method hash
  return .AlgorithmDigest~sha256Text(self~canonicalText)

::method render
  expose entries
  lines = .array~new
  names = entries~allIndexes
  names~sort
  do name over names
    lines~append(name || '=' || entries[name])
  end
  return lines
