/* Runtime Registry v0.3 - deterministic generation-private source bundler.
 *
 * Purpose:
 *   Convert a reloadable multi-file ooRexx source closure into one immutable
 *   package source.  Bundle-local ::REQUIRES directives are replaced by
 *   provenance comments because all bundled classes/routines live in the same
 *   generated package.  Non-local ::REQUIRES directives are preserved.
 *
 * This is deliberately a build/staging primitive, not an excuse to flatten
 * application data.  The bundle concerns CODE identity only.
 */

::class RuntimeBundleUnit public
::attribute logicalName get
::attribute baseName get

::method init
  expose logicalName baseName lines
  use arg logicalName, sourceLines
  logicalName = logicalName~string~strip
  if logicalName = "" then raise syntax 88.900 array("RuntimeBundleUnit logicalName must not be empty")
  baseName = self~pathBaseName(logicalName)
  if sourceLines == .nil then raise syntax 88.900 array("RuntimeBundleUnit sourceLines must not be .nil")
  lines = self~copyLines(sourceLines)

::method sourceLines
  expose lines
  return self~copyLines(lines)

::method copyLines private
  use arg source
  a = .array~new
  do i = 1 to source~items
    a~append(source~at(i)~string)
  end
  return a

::method pathBaseName private
  use arg path
  slash = lastPos("/", path)
  backslash = lastPos("\\", path)
  cut = slash
  if backslash > cut then cut = backslash
  if cut = 0 then return path
  return substr(path, cut + 1)

::class RuntimeBundleMapEntry public
::attribute logicalName get
::attribute startLine get
::attribute endLine get

::method init
  expose logicalName startLine endLine
  use arg logicalName, startLine, endLine

::class RuntimeBundle public
::attribute localRequiresRemoved get
::attribute transformVersion get

::method init
  expose sourceLines mapEntries localRequiresRemoved transformVersion
  use arg sourceLinesArg, mapEntriesArg, removedArg, transformVersionArg = "runtime.bundle/1"
  sourceLines = self~copyLines(sourceLinesArg)
  mapEntries = self~copyObjects(mapEntriesArg)
  localRequiresRemoved = self~copyStrings(removedArg)
  transformVersion = transformVersionArg~string

::method sourceLines
  expose sourceLines
  return self~copyLines(sourceLines)

::method sourceMap
  expose mapEntries
  return self~copyObjects(mapEntries)

::method sourceLineCount
  expose sourceLines
  return sourceLines~items

::method unitCount
  expose mapEntries
  return mapEntries~items

::method canonicalSource
  expose sourceLines
  return .RuntimeCanonical~joinLines(sourceLines)

::method writeFile
  expose sourceLines
  use arg path
  stream = .Stream~new(path)
  openStatus = stream~open("WRITE REPLACE")
  if \openStatus~caselessEquals("READY:") then return .RuntimeResult~failure("BUNDLE_WRITE_FAILED", path || " status=" || openStatus)
  do i = 1 to sourceLines~items
    count = stream~lineOut(sourceLines~at(i))
  end
  closeStatus = stream~close
  return .RuntimeResult~success(path, "bundle written")

::method copyLines private
  use arg source
  a = .array~new
  if source == .nil then return a
  do i = 1 to source~items; a~append(source~at(i)~string); end
  return a

::method copyObjects private
  use arg source
  a = .array~new
  if source == .nil then return a
  do i = 1 to source~items; a~append(source~at(i)); end
  return a

::method copyStrings private
  use arg source
  a = .array~new
  if source == .nil then return a
  do i = 1 to source~items; a~append(source~at(i)~string); end
  return a

::class RuntimeBundleBuilder public
::attribute transformVersion get

::method init
  expose units baseNames transformVersion
  units = .table~new
  baseNames = .table~new
  transformVersion = "runtime.bundle/1"

::method addFile
  use arg path, logicalName = .nil
  if logicalName == .nil then logicalName = path
  readResult = .RuntimeSourceLoader~readFile(path)
  if \readResult~ok then return readResult
  return self~addUnit(logicalName, readResult~value)

::method addUnit
  expose units baseNames
  use arg logicalName, sourceLines
  signal on syntax name addError
  unit = .RuntimeBundleUnit~new(logicalName, sourceLines)
  signal off syntax
  if units~at(unit~logicalName) \== .nil then return .RuntimeResult~failure("BUNDLE_UNIT_DUPLICATE", unit~logicalName)
  existing = baseNames~at(unit~baseName~lower)
  if existing \== .nil then return .RuntimeResult~failure("BUNDLE_BASENAME_DUPLICATE", unit~baseName || " already supplied by " || existing)
  units~put(unit, unit~logicalName)
  baseNames~put(unit~logicalName, unit~baseName~lower)
  return .RuntimeResult~success(unit, "bundle unit added")
addError:
  conditionObject = condition("O")
  return .RuntimeResult~failure("BUNDLE_UNIT_INVALID", self~conditionMessage(conditionObject))

::method build
  expose units baseNames transformVersion
  logicalNames = .array~new
  do logicalName over units
    logicalNames~append(logicalName)
  end
  logicalNames = .RuntimeCanonical~sortStrings(logicalNames)
  if logicalNames~items = 0 then return .RuntimeResult~failure("BUNDLE_EMPTY", "No source units supplied")

  out = .array~new
  mapEntries = .array~new
  removed = .array~new
  out~append("-- RUNTIME-BUNDLE/1 transform=" || transformVersion)

  do i = 1 to logicalNames~items
    logicalName = logicalNames~at(i)
    unit = units~at(logicalName)
    out~append("-- RUNTIME-BUNDLE-SOURCE-BEGIN: " || logicalName)
    startLine = out~items + 1
    lines = unit~sourceLines
    do j = 1 to lines~items
      line = lines~at(j)
      requiredName = self~quotedRequireName(line)
      if requiredName <> "" then do
        requiredBase = self~pathBaseName(requiredName)~lower
        if baseNames~at(requiredBase) \== .nil then do
          out~append("-- RUNTIME-BUNDLE-LOCAL-REQUIRES: " || requiredName)
          removed~append(logicalName || " -> " || requiredName)
          iterate
        end
      end
      out~append(line)
    end
    endLine = out~items
    mapEntries~append(.RuntimeBundleMapEntry~new(logicalName, startLine, endLine))
    out~append("-- RUNTIME-BUNDLE-SOURCE-END: " || logicalName)
    out~append("")
  end

  return .RuntimeResult~success(.RuntimeBundle~new(out, mapEntries, removed, transformVersion), "bundle built")

::method quotedRequireName private
  use arg line
  stripped = line~strip
  if length(stripped) < 10 then return ""
  if left(stripped~upper, 10) <> "::REQUIRES" then return ""
  rest = substr(stripped, 11)~strip
  if rest = "" then return ""
  quote = left(rest, 1)
  if quote <> '"' then do
    if quote <> "'" then return ""
  end
  endQuote = pos(quote, rest, 2)
  if endQuote = 0 then return ""
  return substr(rest, 2, endQuote - 2)

::method pathBaseName private
  use arg path
  slash = lastPos("/", path)
  backslash = lastPos("\\", path)
  cut = slash
  if backslash > cut then cut = backslash
  if cut = 0 then return path
  return substr(path, cut + 1)

::method conditionMessage private
  use arg conditionObject
  if conditionObject == .nil then return "unknown ooRexx condition"
  message = conditionObject["MESSAGE"]
  code = conditionObject["CODE"]
  if message == .nil then message = "ooRexx condition"
  if code == .nil then return message~string
  return code~string || ": " || message~string

::requires "RuntimeRegistry.cls"
