/*
 * ooRexx Semantic Source Control v0.2.3
 *
 * Object-centric source history and impact analysis.
 * Files and archives are intake/export carriers; repository truth is expressed
 * as source entities, immutable revisions, semantic contracts, requirements,
 * external-operation tracking decisions, and compatibility/impact evidence.
 */

::class SSCBuild public
::constant PRODUCT "ooRexx Semantic Source Control"
::constant RELEASE "0.2.3"
::constant API_VERSION "semantic.source.control/0.2.3"

::class SSCUtil public

::method normalizeLine class
  use arg line
  if line == .nil then return ""
  line = line~string~changestr("09"x, " ")~strip
  return space(line)

::method upperNorm class
  use arg value
  return self~normalizeLine(value)~upper

::method beginMd5Batch class
  expose md5Cache md5Pending md5PendingIndex md5Collecting md5BatchInvocations
  md5Cache = .table~new
  md5Pending = .array~new
  md5PendingIndex = .table~new
  md5Collecting = .true
  md5BatchInvocations = 0

::method flushMd5Batch class
  expose md5Cache md5Pending md5PendingIndex md5Collecting md5BatchInvocations
  if \md5Pending~isA(.array) then return 0
  if md5Pending~items = 0 then return 0
  temp = SysTempFileName("/tmp/osc_md5_batch_??????")
  self~ensureDir(temp)
  do i = 1 to md5Pending~items
    name = "v" || right(i, 8, "0")
    self~writeAll(temp || "/" || name, md5Pending[i])
  end
  address system 'cd ' || self~shellQuote(temp) || ' && md5sum v* > hashes.out'
  hashRc = rc
  md5BatchInvocations += 1
  if hashRc = 0 then do
    rows = self~readLines(temp || "/hashes.out")
    do row over rows
      digest = word(row, 1)
      name = word(row, 2)
      if name~left(1) = "*" then name = name~substr(2)
      if name~left(1) <> "v" then iterate
      index = name~substr(2) + 0
      if index >= 1 & index <= md5Pending~items then md5Cache[md5Pending[index]] = digest
    end
  end
  /* Native md5sum is an acceleration, not a repository-format dependency. */
  if hashRc <> 0 then do value over md5Pending
    md5Cache[value] = .MD5~new(value)~digest
  end
  address system 'rm -rf ' || self~shellQuote(temp)
  return md5Pending~items

::method endMd5Batch class
  expose md5Pending md5PendingIndex md5Collecting
  md5Collecting = .false
  md5Pending = .array~new
  md5PendingIndex = .table~new

::method md5BatchInvocations class
  expose md5BatchInvocations
  if \datatype(md5BatchInvocations, "W") then return 0
  return md5BatchInvocations

::method md5 class
  expose md5Cache md5Pending md5PendingIndex md5Collecting
  use arg value
  value = value~string
  if \md5Cache~isA(.table) then md5Cache = .table~new
  if md5Cache~hasIndex(value) then return md5Cache[value]
  if md5Collecting = .true then do
    if \md5Pending~isA(.array) then md5Pending = .array~new
    if \md5PendingIndex~isA(.table) then md5PendingIndex = .table~new
    if \md5PendingIndex~hasIndex(value) then do
      md5Pending~append(value)
      md5PendingIndex[value] = md5Pending~items
    end
    /* The first analyzer pass is disposable.  Real contextual identities are
       constructed after this batch is flushed. */
    return copies("0", 32)
  end

  /* Safe isolated-call fallback. */
  input = SysTempFileName("/tmp/osc_md5_in_??????")
  output = SysTempFileName("/tmp/osc_md5_out_??????")
  s = .stream~new(input)
  s~open("write replace")
  s~charOut(value)
  s~close
  address system 'md5sum ' || self~shellQuote(input) || ' > ' || self~shellQuote(output)
  hashRc = rc
  digest = ""
  if hashRc = 0 then do
    rows = self~readLines(output)
    if rows~items > 0 then digest = word(rows[1], 1)
  end
  call SysFileDelete input
  call SysFileDelete output
  if digest = "" then digest = .MD5~new(value)~digest
  md5Cache[value] = digest
  return digest

::method beginContentHashBatch class
  expose contentHashCache contentHashPending contentHashPendingIndex contentHashCollecting
  contentHashCache = .table~new
  contentHashPending = .array~new
  contentHashPendingIndex = .table~new
  contentHashCollecting = .true

::method flushContentHashBatch class
  expose contentHashCache contentHashPending contentHashPendingIndex contentHashCollecting
  if \contentHashPending~isA(.array) then return 0
  if contentHashPending~items = 0 then return 0
  temp = SysTempFileName("/tmp/osc_hash_batch_??????")
  self~ensureDir(temp)
  do i = 1 to contentHashPending~items
    name = "v" || right(i, 8, "0")
    self~writeAll(temp || "/" || name, contentHashPending[i])
  end
  address system 'cd ' || self~shellQuote(temp) || ' && sha256sum v* > hashes.out'
  hashRc = rc
  if hashRc = 0 then do
    rows = self~readLines(temp || "/hashes.out")
    do row over rows
      digest = word(row, 1)
      name = word(row, 2)
      if name~left(1) = "*" then name = name~substr(2)
      if name~left(1) <> "v" then iterate
      index = name~substr(2) + 0
      if index >= 1 & index <= contentHashPending~items then contentHashCache[contentHashPending[index]] = digest
    end
  end
  address system 'rm -rf ' || self~shellQuote(temp)
  return contentHashPending~items

::method endContentHashBatch class
  expose contentHashPending contentHashPendingIndex contentHashCollecting
  contentHashCollecting = .false
  contentHashPending = .array~new
  contentHashPendingIndex = .table~new

::method releaseHashCaches class
  expose contentHashCache contentHashPending contentHashPendingIndex contentHashCollecting md5Cache md5Pending md5PendingIndex md5Collecting
  contentHashCache = .table~new
  contentHashPending = .array~new
  contentHashPendingIndex = .table~new
  contentHashCollecting = .false
  md5Cache = .table~new
  md5Pending = .array~new
  md5PendingIndex = .table~new
  md5Collecting = .false

::method contentHash class
  expose contentHashCache contentHashPending contentHashPendingIndex contentHashCollecting
  use arg value
  value = value~string
  if \contentHashCache~isA(.table) then contentHashCache = .table~new
  if contentHashCache~hasIndex(value) then return contentHashCache[value]
  if contentHashCollecting = .true then do
    if \contentHashPending~isA(.array) then contentHashPending = .array~new
    if \contentHashPendingIndex~isA(.table) then contentHashPendingIndex = .table~new
    if \contentHashPendingIndex~hasIndex(value) then do
      contentHashPending~append(value)
      contentHashPendingIndex[value] = contentHashPending~items
    end
    /* Warm-up snapshots are deliberately disposable; callers only need a
       deterministic placeholder until the batch is flushed. */
    return copies("0", 64)
  end

  /* Fallback for isolated API calls outside an analyzer batch. */
  input = SysTempFileName("/tmp/osc_hash_in_??????")
  output = SysTempFileName("/tmp/osc_hash_out_??????")
  s = .stream~new(input)
  s~open("write replace")
  s~charOut(value)
  s~close
  address system 'sha256sum ' || self~shellQuote(input) || ' > ' || self~shellQuote(output)
  hashRc = rc
  digest = ""
  if hashRc = 0 then do
    rows = self~readLines(output)
    if rows~items > 0 then digest = word(rows[1], 1)
  end
  call SysFileDelete input
  call SysFileDelete output
  if digest = "" then digest = .SHA512~new(value)~digest
  contentHashCache[value] = digest
  return digest

::method stableId class
  use arg prefix, value
  return prefix || "-" || self~contentHash(value)~left(20)

::method encode class
  use arg value
  if value == .nil then return ""
  value = value~string
  value = value~changestr("%", "%25")
  value = value~changestr("|", "%7C")
  value = value~changestr("0d"x, "%0D")
  value = value~changestr("0a"x, "%0A")
  return value

::method decode class
  use arg value
  if value == .nil then return ""
  value = value~string
  value = value~changestr("%0A", "0a"x)
  value = value~changestr("%0D", "0d"x)
  value = value~changestr("%7C", "|")
  value = value~changestr("%25", "%")
  return value

::method join class
  use arg values, separator = ","
  out = .MutableBuffer~new
  do i = 1 to values~items
    if i > 1 then out~append(separator)
    out~append(values[i])
  end
  return out~string

::method arraysEqual class
  use arg leftArray, rightArray
  if leftArray~items <> rightArray~items then return .false
  do i = 1 to leftArray~items
    if leftArray[i] <> rightArray[i] then return .false
  end
  return .true

::method arrayContainsCI class
  use arg values, wanted
  wanted = wanted~string~upper
  do value over values
    if value~string~upper = wanted then return .true
  end
  return .false

::method fileExists class
  use arg path
  s = .stream~new(path)
  return s~query("exists") <> ""

::method relativePath class
  use arg path, root
  rel = path
  marker = root
  if marker~right(1) <> "/" then marker ||= "/"
  rp = pos(marker, path)
  if rp > 0 then rel = path~substr(rp + marker~length)
  return rel

::method splitRexxStatements class
  use arg text
  out = .array~new
  current = ""
  quote = ""
  i = 1
  do while i <= text~length
    c = text~substr(i, 1)
    if quote <> "" then do
      current ||= c
      if c = quote then do
        if i < text~length & text~substr(i + 1, 1) = quote then do
          i += 1
          current ||= quote
        end
        else quote = ""
      end
    end
    else do
      if c = '"' | c = "'" then do
        quote = c
        current ||= c
      end
      else if c = ";" then do
        if current~strip <> "" then out~append(current~strip)
        current = ""
      end
      else current ||= c
    end
    i += 1
  end
  if current~strip <> "" then out~append(current~strip)
  return out

::method codeLines class
  /* Return one lexical-code line for every physical source line.  ooRexx
     block comments can span (and nest across) lines; comment delimiters inside
     quoted strings are ordinary characters.  Line comments are removed here
     too.  The result preserves physical line numbering for semantic evidence. */
  use arg lines
  out = .array~new
  depth = 0
  do line over lines
    text = line~string
    code = .MutableBuffer~new
    quote = ""
    i = 1
    do while i <= text~length
      c = text~substr(i, 1)
      n = ""
      if i < text~length then n = text~substr(i, 2)

      if depth > 0 then do
        if n = "/*" then do
          depth += 1
          i += 2
          iterate
        end
        if n = "*/" then do
          depth -= 1
          i += 2
          iterate
        end
        i += 1
        iterate
      end

      if quote <> "" then do
        code~append(c)
        if c = quote then do
          if i < text~length & text~substr(i + 1, 1) = quote then do
            code~append(quote)
            i += 2
            iterate
          end
          quote = ""
        end
        i += 1
        iterate
      end

      if c = '"' | c = "'" then do
        quote = c
        code~append(c)
        i += 1
        iterate
      end
      if n = "/*" then do
        depth = 1
        i += 2
        iterate
      end
      if n = "--" then leave
      code~append(c)
      i += 1
    end
    out~append(code~string)
  end
  return out

::method split class
  use arg text, separator = ","
  out = .array~new
  text = text~string
  if text = "" then return out
  rest = text
  do while rest <> ""
    p = pos(separator, rest)
    if p = 0 then do
      out~append(rest)
      leave
    end
    out~append(rest~left(p - 1))
    rest = rest~substr(p + separator~length)
  end
  return out

::method containsWord class
  use arg text, wanted
  text = translate(text~string, " ", "09"x)~upper
  wanted = wanted~string~upper
  padded = " " || self~wordish(text) || " "
  return pos(" " || wanted || " ", padded) > 0

::method wordish class
  use arg text
  chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$"
  out = ""
  do i = 1 to text~length
    c = text~substr(i, 1)
    if pos(c, chars) > 0 then out ||= c
    else out ||= " "
  end
  return space(out)

::method stripQuotes class
  use arg text
  text = text~string~strip
  do while text~length > 0 & (text~left(1) = '"' | text~left(1) = "'")
    text = text~substr(2)
  end
  do while text~length > 0 & (text~right(1) = '"' | text~right(1) = "'" | text~right(1) = ";")
    text = text~left(text~length - 1)~strip
  end
  return text

::method readLines class
  use arg path
  lines = .array~new
  s = .stream~new(path)
  if s~query("exists") = "" then return lines
  s~open("read")
  do while s~lines > 0
    lines~append(s~lineIn)
  end
  s~close
  return lines

::method readAll class
  use arg path
  s = .stream~new(path)
  if s~query("exists") = "" then return ""
  s~open("read")
  count = s~chars
  if count > 0 then content = s~charIn(1, count)
  else content = ""
  s~close
  return content

::method writeAll class
  use arg path, content
  self~ensureParent(path)
  s = .stream~new(path)
  s~open("write replace")
  s~charOut(content)
  s~close
  return path

::method writeLines class
  use arg path, lines
  self~ensureParent(path)
  call sysFileDelete path
  s = .stream~new(path)
  s~open("write replace")
  do i = 1 to lines~items
    s~lineOut(lines[i])
  end
  s~close
  return path

::method appendLine class
  use arg path, line
  self~ensureParent(path)
  s = .stream~new(path)
  s~open("write append")
  s~lineOut(line)
  s~close

::method ensureDir class
  use arg path
  if path = "" then return
  address system 'mkdir -p ' || self~shellQuote(path)

::method ensureParent class
  use arg path
  slash = path~lastPos("/")
  if slash > 1 then self~ensureDir(path~left(slash - 1))

::method shellQuote class
  use arg value
  /* Paths created by this package are controlled.  Reject the one character
     that would invalidate this simple POSIX single-quoted argument. */
  if pos("'", value) > 0 then raise syntax 88.900 array("single quote not permitted in archive/path argument", value)
  return "'" || value || "'"

::method basename class
  use arg path
  p = path~lastPos("/")
  if p = 0 then return path
  return path~substr(p + 1)

::method dirname class
  use arg path
  p = path~lastPos("/")
  if p <= 1 then return "."
  return path~left(p - 1)

::method stemWithoutVersion class
  use arg filename
  name = self~basename(filename)
  if name~right(4)~lower = ".zip" then name = name~left(name~length - 4)
  /* Do not use this as a source-level comparator.  It is only a legacy
     component-name hint for archives that predate SSC manifests. */
  u = name~upper
  p = u~lastPos("_V")
  if p > 1 then do
    suffix = name~substr(p + 2)
    if suffix <> "" then do
      first = suffix~left(1)
      if datatype(first, "N") then name = name~left(p - 1)
    end
  end
  return name

::method now class
  return date("S") || "T" || time("N")


::class SourceEntity public
::attribute entityId get
::attribute kind get
::attribute qualifiedName get
::attribute parentId get

::method init
  expose entityId kind qualifiedName parentId
  use arg entityId, kind, qualifiedName, parentId = ""


::class SourceFileRevision public
::attribute path get
::attribute blobHash get
::attribute content get

::method init
  expose path blobHash content
  use arg path, blobHash, content = ""


::class SourceClassRevision public
::attribute entityId get
::attribute qualifiedName get
::attribute className get
::attribute directiveContract get
::attribute contractHash get
::attribute path get
::attribute line get

::method init
  expose entityId qualifiedName className directiveContract contractHash path line
  use arg entityId, qualifiedName, className, directiveContract, contractHash, path, line

::method reassignEntityId
  expose entityId
  use arg stableId
  entityId = stableId

::method revisionId
  expose entityId contractHash
  return "SR-" || .SSCUtil~contentHash(entityId || "|" || contractHash)~left(24)


::class SourcePackageRevision public
::attribute entityId get
::attribute qualifiedName get
::attribute anchor get
::attribute optionsContract get
::attribute requiresContract get
::attribute contractHash get
::attribute path get
::attribute line get

::method init
  expose entityId qualifiedName anchor optionsContract requiresContract contractHash path line
  use arg entityId, qualifiedName, anchor, optionsContract, requiresContract, contractHash, path, line

::method revisionId
  expose entityId contractHash
  return "SR-" || .SSCUtil~contentHash(entityId || "|" || contractHash)~left(24)


::class SourceMethodRevision public
::attribute entityId get
::attribute qualifiedName get
::attribute className get
::attribute methodName get
::attribute scope get
::attribute visibility get
::attribute argSpec get
::attribute contractHash get
::attribute bodyHash get
::attribute path get
::attribute lineStart get
::attribute lineEnd get

::method init
  expose entityId qualifiedName className methodName scope visibility argSpec contractHash bodyHash path lineStart lineEnd
  use arg entityId, qualifiedName, className, methodName, scope, visibility, argSpec, contractHash, bodyHash, path, lineStart, lineEnd

::method canonical
  expose entityId qualifiedName className methodName scope visibility argSpec contractHash bodyHash path lineStart lineEnd
  return .SSCUtil~join(.array~of(entityId, qualifiedName, className, methodName, scope, visibility, argSpec, contractHash, bodyHash, path, lineStart, lineEnd), "|")

::method reassignEntityId
  expose entityId
  use arg stableId
  entityId = stableId

::method revisionId
  expose entityId contractHash bodyHash
  return "SR-" || .SSCUtil~contentHash(entityId || "|" || contractHash || "|" || bodyHash)~left(24)

::method identityKey
  /* Preserve the v0.1 instance-side key so existing external-operation
     decisions keep matching.  Non-instance sides are explicit selectors. */
  expose qualifiedName scope
  if scope = "INSTANCE" then return qualifiedName
  return qualifiedName || "#" || scope

::method displaySelector
  expose qualifiedName scope
  if scope = "INSTANCE" then return qualifiedName
  return qualifiedName || "#" || scope


::class SourceAttributeRevision public
::attribute entityId get
::attribute qualifiedName get
::attribute className get
::attribute attributeName get
::attribute scope get
::attribute getterContract get
::attribute setterContract get
::attribute getterBodyHash get
::attribute setterBodyHash get
::attribute contractHash get
::attribute path get
::attribute line get

::method init
  expose entityId qualifiedName className attributeName scope getterContract setterContract getterBodyHash setterBodyHash contractHash path line
  use arg entityId, qualifiedName, className, attributeName, scope, path = "", line = 0
  getterContract = ""; setterContract = ""
  getterBodyHash = ""; setterBodyHash = ""
  contractHash = .SSCUtil~contentHash(scope || "||")

::method mergeAccessor
  expose getterContract setterContract getterBodyHash setterBodyHash contractHash path line scope
  use arg accessMode, directiveContract, bodyHash = "", sourcePath = "", sourceLine = 0
  select
    when accessMode = "GET" then do
      getterContract = directiveContract
      getterBodyHash = bodyHash
    end
    when accessMode = "SET" then do
      setterContract = directiveContract
      setterBodyHash = bodyHash
    end
    otherwise do
      /* Bare ::attribute NAME is the generated BOTH shorthand. */
      getterContract = directiveContract
      setterContract = directiveContract
      getterBodyHash = bodyHash
      setterBodyHash = bodyHash
    end
  end
  if path = "" then path = sourcePath
  if line = 0 | (sourceLine > 0 & sourceLine < line) then line = sourceLine
  contractHash = .SSCUtil~contentHash(scope || "|" || getterContract || "|" || setterContract)

::method reassignEntityId
  expose entityId
  use arg stableId
  entityId = stableId

::method identityKey
  expose qualifiedName scope
  if scope = "INSTANCE" then return qualifiedName || "#ATTRIBUTE"
  return qualifiedName || "#ATTRIBUTE_" || scope

::method accessMode
  expose getterContract setterContract
  if getterContract <> "" & setterContract <> "" then return "BOTH"
  if getterContract <> "" then return "GET"
  if setterContract <> "" then return "SET"
  return "NONE"

::method visibility
  expose getterContract setterContract
  text = (getterContract || " " || setterContract)~upper
  if .SSCUtil~containsWord(text, "PRIVATE") then return "PRIVATE"
  if .SSCUtil~containsWord(text, "PROTECTED") then return "PROTECTED"
  return "PUBLIC"

::method directiveContract
  expose getterContract setterContract
  return "GET{" || getterContract || "} SET{" || setterContract || "}"

::method revisionId
  expose entityId contractHash getterBodyHash setterBodyHash
  return "SR-" || .SSCUtil~contentHash(entityId || "|" || contractHash || "|" || getterBodyHash || "|" || setterBodyHash)~left(24)


::class SourceConstantRevision public
::attribute entityId get
::attribute qualifiedName get
::attribute className get
::attribute constantName get
::attribute valueContract get
::attribute valueHash get
::attribute path get
::attribute line get

::method init
  expose entityId qualifiedName className constantName valueContract valueHash path line
  use arg entityId, qualifiedName, className, constantName, valueContract, valueHash, path, line

::method reassignEntityId
  expose entityId
  use arg stableId
  entityId = stableId

::method identityKey
  expose qualifiedName
  return qualifiedName || "#CONSTANT"

::method revisionId
  expose entityId valueHash
  return "SR-" || .SSCUtil~contentHash(entityId || "|" || valueHash)~left(24)


::class SourceRequirement public
::attribute target get
::attribute minimumLevel get
::attribute evidence get
::attribute path get
::attribute line get
::attribute consumer get

::method init
  expose target minimumLevel evidence path line consumer
  use arg target, minimumLevel, evidence, path, line, consumer = ""


::class SourceUse public
::attribute message get
::attribute path get
::attribute line get
::attribute consumer get
::attribute useKind get
::attribute targetClass get
::attribute detail get
::attribute targetScope get
::attribute consumerScope get

::method init
  expose message path line consumer useKind targetClass detail targetScope consumerScope
  use arg message, path, line, consumer = "", useKind = "DYNAMIC_MESSAGE", targetClass = "", detail = "", targetScope = "UNKNOWN", consumerScope = "UNKNOWN"


::class SourceDataDependency public
::attribute target get
::attribute mode get
::attribute detail get
::attribute path get
::attribute line get
::attribute consumer get

::method init
  expose target mode detail path line consumer
  use arg target, mode, detail, path, line, consumer = ""


::class ExternalCandidate public
::attribute methodKey get
::attribute kind get
::attribute operation get
::attribute statement get
::attribute statementHash get
::attribute beforeHashes get
::attribute afterHashes get
::attribute anchorHash get
::attribute semanticContract get
::attribute path get
::attribute line get
::attribute proposalId get

::method init
  expose methodKey kind operation statement statementHash beforeHashes afterHashes anchorHash semanticContract path line proposalId
  use arg methodKey, kind, operation, statement, beforeHashes, afterHashes, semanticContract, path, line, persistedStatementHash = "", persistedProposalId = ""
  if persistedStatementHash <> "" then do
    /* Persisted candidates already carry their authoritative contextual
       identity.  Loading an identity-only historical view must not spawn MD5
       processes merely to rediscover a hash which is immediately overwritten. */
    statementHash = persistedStatementHash
    anchorHash = ""
  end
  else do
    statementHash = .SSCUtil~md5(.SSCUtil~normalizeLine(statement))
    anchorText = methodKey || "|" || .SSCUtil~join(beforeHashes, ",") || "|" || statementHash || "|" || .SSCUtil~join(afterHashes, ",")
    /* The contextual fingerprint is composed from MD5 line/statement hashes;
       its aggregate key can use the repository SHA batch.  This avoids a
       second-order MD5 payload appearing only after statement MD5 resolution. */
    anchorHash = .SSCUtil~contentHash(anchorText)
  end
  if persistedProposalId <> "" then proposalId = persistedProposalId
  else proposalId = .SSCUtil~stableId("TP", methodKey || "|" || kind || "|" || statementHash)

::method overrideStatementHash
  expose statementHash
  use arg value
  statementHash = value

::method overrideProposalId
  expose proposalId
  use arg value
  proposalId = value

::method beforeSignature
  expose beforeHashes
  return .SSCUtil~join(beforeHashes, ",")

::method afterSignature
  expose afterHashes
  return .SSCUtil~join(afterHashes, ",")


::class ExternalOperationRevision public
::attribute externalId get
::attribute methodKey get
::attribute kind get
::attribute operation get
::attribute statementHash get
::attribute beforeHashes get
::attribute afterHashes get
::attribute semanticContract get
::attribute path get
::attribute line get

::method init
  expose externalId methodKey kind operation statementHash beforeHashes afterHashes semanticContract path line
  use arg externalId, candidate
  methodKey = candidate~methodKey
  kind = candidate~kind
  operation = candidate~operation
  statementHash = candidate~statementHash
  beforeHashes = candidate~beforeHashes
  afterHashes = candidate~afterHashes
  semanticContract = candidate~semanticContract
  path = candidate~path
  line = candidate~line

::method overrideStatementHash
  expose statementHash
  use arg value
  statementHash = value


::class TrackingDecision public
::attribute proposalId get
::attribute decision get
::attribute externalId get
::attribute methodKey get
::attribute kind get
::attribute statementHash get
::attribute beforeHashes get
::attribute afterHashes get
::attribute reason get
::attribute authority get
::attribute decidedAt get

::method init
  expose proposalId decision externalId methodKey kind statementHash beforeHashes afterHashes reason authority decidedAt
  use arg proposalId, decision, externalId, methodKey, kind, statementHash, beforeHashes, afterHashes, reason = "", authority = "", decidedAt = ""


::class SourceSnapshot public
::attribute component get
::attribute lineage get
::attribute sourceLevel get
::attribute label get
::attribute files get
::attribute packages get
::attribute classes get
::attribute methods get
::attribute attributes get
::attribute constants get
::attribute schemaVersion get
::attribute requirements get
::attribute uses get
::attribute dataDependencies get
::attribute candidates get
::attribute externalOperations get

::method init
  expose component lineage sourceLevel label files packages classes methods attributes constants schemaVersion requirements uses dataDependencies candidates externalOperations
  use arg component, lineage, sourceLevel, label = ""
  files = .array~new
  packages = .array~new
  classes = .array~new
  methods = .array~new
  attributes = .array~new
  constants = .array~new
  schemaVersion = 4
  requirements = .array~new
  uses = .array~new
  dataDependencies = .array~new
  candidates = .array~new
  externalOperations = .array~new

::method addFile
  expose files
  use arg item
  files~append(item)

::method fileByPath
  expose files
  use arg wanted
  do f over files
    if f~path = wanted then return f
  end
  return .nil

::method addPackage
  expose packages
  use arg item
  packages~append(item)

::method packageByQualifiedName
  expose packages
  use arg wanted
  wanted = wanted~string~upper
  do p over packages
    if p~qualifiedName~upper = wanted then return p
  end
  return .nil

::method addClass
  expose classes
  use arg item
  classes~append(item)

::method addMethod
  expose methods
  use arg item
  methods~append(item)

::method addAttribute
  expose attributes
  use arg item
  attributes~append(item)

::method addConstant
  expose constants
  use arg item
  constants~append(item)

::method markSchemaVersion
  expose schemaVersion
  use arg value
  schemaVersion = value

::method attributeByIdentityKey
  expose attributes
  use arg wanted
  wanted = wanted~upper
  do a over attributes
    if a~identityKey~upper = wanted then return a
  end
  return .nil

::method constantByIdentityKey
  expose constants
  use arg wanted
  wanted = wanted~upper
  do c over constants
    if c~identityKey~upper = wanted then return c
  end
  return .nil

::method addRequirement
  expose requirements
  use arg item
  requirements~append(item)

::method addUse
  expose uses
  use arg item
  uses~append(item)

::method addDataDependency
  expose dataDependencies
  use arg item
  dataDependencies~append(item)

::method addCandidate
  expose candidates
  use arg item
  candidates~append(item)

::method addExternalOperation
  expose externalOperations
  use arg item
  externalOperations~append(item)

::method clearExternalOperations
  expose externalOperations
  externalOperations = .array~new

::method externalForCandidate
  expose externalOperations
  use arg candidate
  do e over externalOperations
    if e~methodKey <> candidate~methodKey then iterate
    if e~kind <> candidate~kind then iterate
    if e~statementHash <> candidate~statementHash then iterate
    if e~path <> candidate~path then iterate
    if e~line <> candidate~line then iterate
    return e
  end
  return .nil

::method methodByQualifiedName
  expose methods
  use arg wanted
  wanted = wanted~string
  wantedScope = ""
  hash = wanted~lastPos("#")
  if hash > 0 then do
    maybeScope = wanted~substr(hash + 1)~upper
    if maybeScope = "INSTANCE" | maybeScope = "CLASS" | maybeScope = "OBJECT" then do
      wantedScope = maybeScope
      wanted = wanted~left(hash - 1)
    end
  end
  wanted = wanted~upper
  fallback = .nil
  do m over methods
    if m~qualifiedName~upper <> wanted then iterate
    if wantedScope <> "" then do
      if m~scope = wantedScope then return m
      iterate
    end
    /* Backward-compatible default: ordinary unqualified source selectors mean
       instance side when both instance and class messages share a name. */
    if m~scope = "INSTANCE" then return m
    if fallback == .nil then fallback = m
  end
  return fallback

::method methodsByName
  expose methods
  use arg wanted
  out = .array~new
  wanted = wanted~string~upper
  do m over methods
    if m~methodName~upper = wanted then out~append(m)
  end
  return out

::method externalById
  expose externalOperations
  use arg wanted
  do e over externalOperations
    if e~externalId = wanted then return e
  end
  return .nil

::method identityView
  expose component lineage sourceLevel label classes methods attributes constants externalOperations
  view = .SourceSnapshot~new(component, lineage, sourceLevel, label)
  do c over classes; view~addClass(c); end
  do m over methods; view~addMethod(m); end
  do a over attributes; view~addAttribute(a); end
  do n over constants; view~addConstant(n); end
  do e over externalOperations; view~addExternalOperation(e); end
  return view


::class SourceContractDelta public
::attribute kind get
::attribute risk get
::attribute entity get
::attribute oldValue get
::attribute newValue get
::attribute detail get

::method init
  expose kind risk entity oldValue newValue detail
  use arg kind, risk, entity, oldValue = "", newValue = "", detail = ""


::class ImpactFinding public
::attribute status get
::attribute provider get
::attribute changeKind get
::attribute consumer get
::attribute path get
::attribute line get
::attribute reason get
::attribute evidence get

::method init
  expose status provider changeKind consumer path line reason evidence
  use arg status, provider, changeKind, consumer, path, line, reason, evidence = ""


::class SQLSemantic public

::method looksLikeSQL class
  use arg line
  n = .SSCUtil~upperNorm(line)
  if n = "" then return .false
  if n~left(2) = "--" then return .false
  if pos("SELECT ", n) > 0 & pos(" FROM ", " " || n || " ") > 0 then return .true
  if pos("UPDATE ", n) > 0 & pos(" SET ", " " || n || " ") > 0 then return .true
  if pos("DELETE FROM ", n) > 0 then return .true
  if pos("INSERT INTO ", n) > 0 then return .true
  if pos("EXEC SQL", n) > 0 then return .true

  /* SQL CALL is lexically ambiguous with the Rexx CALL instruction.  Never
     infer SQL merely because a Rexx line begins CALL and happens to mention a
     variable such as sql/proc.  A stored-procedure CALL is proposed only when
     CALL is visibly carried as SQL text (or occurs behind EXEC SQL above).
     This keeps ordinary package-level test statements such as
       call assert sql~pos("COMMIT") > 0
     as Rexx dependency evidence rather than external SQL operations. */
  if self~containsSqlCallLiteral(n) then return .true
  return .false

::method containsSqlCallLiteral class
  use arg line
  do quote over .array~of('"', "'")
    start = 1
    do forever
      p = pos(quote || "CALL ", line, start)
      if p = 0 then leave
      prefix = line~left(p - 1)~upper
      /* A quoted CALL inspected with POS/LASTPOS/CONTAINS is evidence about
         text, not evidence that the SQL call itself is executed here. */
      tail = prefix~right(32)
      if pos("~POS(", tail) = 0 & pos("~LASTPOS(", tail) = 0 & pos("~CONTAINS(", tail) = 0 then return .true
      start = p + 1
    end
  end
  return .false

::method extractStatement class
  use arg line
  raw = line~string~strip
  up = raw~upper
  starts = .array~of("SELECT ", "UPDATE ", "DELETE FROM ", "INSERT INTO ", "EXEC SQL")
  best = 0
  do s over starts
    p = pos(s, up)
    if p > 0 & (best = 0 | p < best) then best = p
  end
  if best = 0 then do quote over .array~of('"', "'")
    p = pos(quote || "CALL ", up)
    if p > 0 then do
      p += 1
      if best = 0 | p < best then best = p
    end
  end
  if best > 0 then raw = raw~substr(best)
  return self~cleanHostSuffix(.SSCUtil~stripQuotes(raw))

::method cleanHostSuffix class
  use arg text
  text = text~string~strip
  /* The SQL commonly lives inside an ooRexx call argument, e.g.
       db~exec("SELECT ... WHERE ID = ?")
     extractStatement begins at SELECT, so the closing quote/parenthesis are
     host-language syntax and must not become part of the SQL predicate. */
  i = text~length
  do while i > 0
    c = text~substr(i, 1)
    if c = ")" | c = "," | c = ";" | c = " " then i -= 1
    else leave
  end
  if i > 0 then do
    c = text~substr(i, 1)
    if c = '"' | c = "'" then text = text~left(i - 1)~strip
  end
  do while text~right(1) = ";"
    text = text~left(text~length - 1)~strip
  end
  return text

::method operation class
  use arg statement
  up = .SSCUtil~upperNorm(statement)
  if up~left(8) = "EXEC SQL" then up = up~substr(9)~strip
  if up~left(6) = "SELECT" then return "SELECT"
  if up~left(6) = "UPDATE" then return "UPDATE"
  if up~left(11) = "DELETE FROM" then return "DELETE"
  if up~left(11) = "INSERT INTO" then return "INSERT"
  if up~left(4) = "CALL" then return "CALL"
  return "UNKNOWN"

::method contract class
  use arg statement
  s = .SSCUtil~upperNorm(.SSCUtil~stripQuotes(statement))
  if s~left(8) = "EXEC SQL" then s = s~substr(9)~strip
  op = self~operation(s)
  sources = ""
  projection = ""
  predicate = ""
  writeColumns = ""

  select
    when op = "SELECT" then do
      pFrom = pos(" FROM ", s)
      if pFrom > 0 then do
        projection = s~substr(7, pFrom - 7)~strip
        tail = s~substr(pFrom + 6)~strip
        sources = self~readSources(tail)
        predicate = self~readPredicate(tail)
      end
    end
    when op = "UPDATE" then do
      tail = s~substr(7)~strip
      pSet = pos(" SET ", tail)
      if pSet > 0 then do
        sources = tail~left(pSet)~strip
        assigns = tail~substr(pSet + 5)
        pWhere = pos(" WHERE ", assigns)
        if pWhere > 0 then do
          writeColumns = self~assignmentColumns(assigns~left(pWhere))
          predicate = assigns~substr(pWhere + 7)~strip
        end
        else writeColumns = self~assignmentColumns(assigns)
      end
    end
    when op = "DELETE" then do
      tail = s~substr(12)~strip
      pWhere = pos(" WHERE ", tail)
      if pWhere > 0 then do
        sources = tail~left(pWhere)~strip
        predicate = tail~substr(pWhere + 7)~strip
      end
      else sources = tail
    end
    when op = "INSERT" then do
      tail = s~substr(12)~strip
      pParen = pos("(", tail)
      if pParen > 0 then do
        sources = tail~left(pParen - 1)~strip
        pClose = pos(")", tail, pParen + 1)
        if pClose > pParen then writeColumns = tail~substr(pParen + 1, pClose - pParen - 1)~strip
      end
      else sources = word(tail, 1)
    end
    when op = "CALL" then sources = word(s, 2)
    otherwise nop
  end
  return "op=" || op || ";sources=" || sources || ";projection=" || projection || ";writes=" || writeColumns || ";predicate=" || predicate

::method readSources class
  use arg tail
  stop = tail~length + 1
  do marker over .array~of(" WHERE ", " GROUP ", " ORDER ", " HAVING ", " UNION ")
    p = pos(marker, tail)
    if p > 0 & p < stop then stop = p
  end
  fromPart = tail~left(stop - 1)~strip
  /* Preserve join/source text.  It is more useful for delta evidence than
     flattening it prematurely to the first table name. */
  return fromPart

::method readPredicate class
  use arg tail
  p = pos(" WHERE ", tail)
  if p <= 0 then return ""
  pred = tail~substr(p + 7)~strip
  return pred

::method assignmentColumns class
  use arg assignments
  cols = .array~new
  rest = assignments
  do while rest <> ""
    comma = pos(",", rest)
    if comma = 0 then do
      one = rest
      rest = ""
    end
    else do
      one = rest~left(comma - 1)
      rest = rest~substr(comma + 1)
    end
    eq = pos("=", one)
    if eq > 0 then cols~append(one~left(eq - 1)~strip)
  end
  return .SSCUtil~join(cols, ",")

::method field class
  use arg contract, key
  needle = key || "="
  p = pos(needle, contract)
  if p = 0 then return ""
  value = contract~substr(p + needle~length)
  semi = pos(";", value)
  if semi > 0 then value = value~left(semi - 1)
  return value

::method delta class
  use arg oldContract, newContract
  out = .array~new
  oldOp = self~field(oldContract, "op"); newOp = self~field(newContract, "op")
  if oldOp <> newOp then out~append("SQL_OPERATION_CHANGED " || oldOp || " -> " || newOp)
  oldSources = self~field(oldContract, "sources"); newSources = self~field(newContract, "sources")
  if oldSources <> newSources then out~append("SQL_DATA_SOURCE_CHANGED " || oldSources || " -> " || newSources)
  oldProj = self~field(oldContract, "projection"); newProj = self~field(newContract, "projection")
  if oldProj <> newProj then do
    if oldProj <> "" & newProj <> "" then out~append("SQL_PROJECTION_OR_ORDER_CHANGED " || oldProj || " -> " || newProj)
    else out~append("SQL_RESULT_SHAPE_CHANGED " || oldProj || " -> " || newProj)
  end
  oldWrites = self~field(oldContract, "writes"); newWrites = self~field(newContract, "writes")
  if oldWrites <> newWrites then out~append("SQL_WRITE_COLUMNS_CHANGED " || oldWrites || " -> " || newWrites)
  oldPred = self~field(oldContract, "predicate"); newPred = self~field(newContract, "predicate")
  if oldPred <> newPred then out~append("SQL_PREDICATE_SCOPE_CHANGED " || oldPred || " -> " || newPred)
  return out


::class CommandSemantic public

::method looksLikeCommand class
  use arg line
  n = .SSCUtil~upperNorm(line)
  if n~left(2) = "--" then return .false
  return n~left(15) = "ADDRESS SYSTEM " | n~left(16) = "ADDRESS COMMAND "

::method extractStatement class
  use arg line
  n = .SSCUtil~normalizeLine(line)
  up = n~upper
  if up~left(15) = "ADDRESS SYSTEM " then return n~substr(16)~strip
  if up~left(16) = "ADDRESS COMMAND " then return n~substr(17)~strip
  return n

::method contract class
  use arg statement
  command = .SSCUtil~normalizeLine(statement)
  tokenized = .SSCUtil~wordish(.SSCUtil~stripQuotes(command))
  executable = word(tokenized, 1)
  return "channel=COMMAND;executable=" || executable || ";command=" || command


::class SemanticRepository public
::attribute root get

::method init
  expose root snapshotCache baselineViewCache proposalCache decisionsCache decisionByProposal
  use arg root
  root = root~string
  snapshotCache = .table~new
  baselineViewCache = .table~new
  proposalCache = .nil
  decisionsCache = .nil
  decisionByProposal = .nil
  .SSCUtil~ensureDir(root)
  .SSCUtil~ensureDir(root || "/components")
  .SSCUtil~ensureDir(root || "/blobs/sha256")

::method clearDerivedCaches private
  expose snapshotCache baselineViewCache decisionsCache decisionByProposal
  snapshotCache = .table~new
  baselineViewCache = .table~new
  decisionsCache = .nil
  decisionByProposal = .nil

::method snapshotCacheKey private
  use arg component, level
  return component~string~upper || "|" || level~string

::method blobPath private
  expose root
  use arg hash
  return root || "/blobs/sha256/" || hash~left(2) || "/" || hash

::method storeBlob
  use arg hash, content
  path = self~blobPath(hash)
  if \.SSCUtil~fileExists(path) then .SSCUtil~writeAll(path, content)
  return path

::method blob
  use arg hash
  return .SSCUtil~readAll(self~blobPath(hash))

::method componentDir private
  expose root
  use arg component
  safe = component~changestr("/", "_")~changestr("\\", "_")
  return root || "/components/" || safe

::method reconcileIdentities
  use arg snapshot, old = .nil
  if old == .nil then old = self~loadLatest(snapshot~component)
  if old == .nil then return snapshot
  do c over snapshot~classes
    do oc over old~classes
      if oc~qualifiedName~upper = c~qualifiedName~upper then do
        c~reassignEntityId(oc~entityId)
        leave
      end
    end
  end
  do m over snapshot~methods
    matched = .nil
    do om over old~methods
      if om~qualifiedName~upper = m~qualifiedName~upper & om~scope = m~scope then do
        matched = om
        leave
      end
    end
    if matched == .nil then do om over old~methods
      if om~className~upper = m~className~upper & om~scope = m~scope & om~bodyHash = m~bodyHash & om~contractHash = m~contractHash then do
        matched = om
        leave
      end
    end
    if matched <> .nil then m~reassignEntityId(matched~entityId)
  end
  do a over snapshot~attributes
    do oa over old~attributes
      if oa~identityKey~upper = a~identityKey~upper then do
        a~reassignEntityId(oa~entityId)
        leave
      end
    end
  end
  do n over snapshot~constants
    do on over old~constants
      if on~identityKey~upper = n~identityKey~upper then do
        n~reassignEntityId(on~entityId)
        leave
      end
    end
  end
  return snapshot

::method saveSnapshot
  use arg snapshot
  dir = self~componentDir(snapshot~component) || "/levels/" || snapshot~sourceLevel
  .SSCUtil~ensureDir(dir)
  lines = .array~new
  lines~append("H|" || .SSCUtil~encode(snapshot~component) || "|" || .SSCUtil~encode(snapshot~lineage) || "|" || snapshot~sourceLevel || "|" || .SSCUtil~encode(snapshot~label))
  lines~append("V|4")
  do f over snapshot~files
    self~storeBlob(f~blobHash, f~content)
    lines~append("F|" || .SSCUtil~encode(f~path) || "|" || f~blobHash)
  end
  do p over snapshot~packages
    lines~append("K|" || .SSCUtil~encode(p~entityId) || "|" || .SSCUtil~encode(p~qualifiedName) || "|" || .SSCUtil~encode(p~anchor) || "|" || .SSCUtil~encode(p~optionsContract) || "|" || .SSCUtil~encode(p~requiresContract) || "|" || p~contractHash || "|" || .SSCUtil~encode(p~path) || "|" || p~line)
  end
  do c over snapshot~classes
    lines~append("C|" || .SSCUtil~encode(c~entityId) || "|" || .SSCUtil~encode(c~qualifiedName) || "|" || .SSCUtil~encode(c~className) || "|" || .SSCUtil~encode(c~directiveContract) || "|" || c~contractHash || "|" || .SSCUtil~encode(c~path) || "|" || c~line)
  end
  do m over snapshot~methods
    lines~append("M|" || .SSCUtil~encode(m~entityId) || "|" || .SSCUtil~encode(m~qualifiedName) || "|" || .SSCUtil~encode(m~className) || "|" || .SSCUtil~encode(m~methodName) || "|" || m~scope || "|" || m~visibility || "|" || .SSCUtil~encode(m~argSpec) || "|" || m~contractHash || "|" || m~bodyHash || "|" || .SSCUtil~encode(m~path) || "|" || m~lineStart || "|" || m~lineEnd)
  end
  do a over snapshot~attributes
    lines~append("A|" || .SSCUtil~encode(a~entityId) || "|" || .SSCUtil~encode(a~qualifiedName) || "|" || .SSCUtil~encode(a~className) || "|" || .SSCUtil~encode(a~attributeName) || "|" || a~scope || "|" || .SSCUtil~encode(a~getterContract) || "|" || .SSCUtil~encode(a~setterContract) || "|" || a~getterBodyHash || "|" || a~setterBodyHash || "|" || a~contractHash || "|" || .SSCUtil~encode(a~path) || "|" || a~line)
  end
  do n over snapshot~constants
    lines~append("N|" || .SSCUtil~encode(n~entityId) || "|" || .SSCUtil~encode(n~qualifiedName) || "|" || .SSCUtil~encode(n~className) || "|" || .SSCUtil~encode(n~constantName) || "|" || .SSCUtil~encode(n~valueContract) || "|" || n~valueHash || "|" || .SSCUtil~encode(n~path) || "|" || n~line)
  end
  do r over snapshot~requirements
    lines~append("R|" || .SSCUtil~encode(r~target) || "|" || r~minimumLevel || "|" || r~evidence || "|" || .SSCUtil~encode(r~path) || "|" || r~line || "|" || .SSCUtil~encode(r~consumer))
  end
  do u over snapshot~uses
    lines~append("U|" || .SSCUtil~encode(u~message) || "|" || .SSCUtil~encode(u~path) || "|" || u~line || "|" || .SSCUtil~encode(u~consumer) || "|" || u~useKind || "|" || .SSCUtil~encode(u~targetClass) || "|" || .SSCUtil~encode(u~detail) || "|" || u~targetScope || "|" || u~consumerScope)
  end
  do d over snapshot~dataDependencies
    lines~append("D|" || .SSCUtil~encode(d~target) || "|" || d~mode || "|" || .SSCUtil~encode(d~detail) || "|" || .SSCUtil~encode(d~path) || "|" || d~line || "|" || .SSCUtil~encode(d~consumer))
  end
  /* Candidate evidence belongs to the immutable source snapshot.  Whether it
     is independently tracked is a separate, later TrackingDecision. */
  do c over snapshot~candidates
    lines~append("P|" || c~proposalId || "|" || .SSCUtil~encode(c~methodKey) || "|" || c~kind || "|" || c~operation || "|" || c~statementHash || "|" || .SSCUtil~encode(c~beforeSignature) || "|" || .SSCUtil~encode(c~afterSignature) || "|" || .SSCUtil~encode(c~semanticContract) || "|" || .SSCUtil~encode(c~path) || "|" || c~line)
  end
  snapshotPath = dir || "/snapshot.osc"
  existing = .SSCUtil~readLines(snapshotPath)
  if existing~items > 0 then do
    if .SSCUtil~arraysEqual(existing, lines) then return snapshotPath

    /* A pre-v0.2 repository did not retain whole-release evidence.  Do not
       rewrite that historical level merely because a newer analyzer can now
       see README/schema/manifest files that were invisible then.  Every file
       the old snapshot *did* know must still match byte-for-byte. */
    if self~persistedSchemaVersion(existing) < 4 then do
      if self~legacyTrackedEvidenceEqual(existing, snapshot) then return snapshotPath
    end

    /* Analyzer schema upgrades add rebuildable semantic rows but must never
       make byte-identical accepted source look like an attempted rewrite. */
    accepted = self~loadSnapshot(snapshot~component, snapshot~sourceLevel)
    if accepted <> .nil then do
      if self~releaseEvidenceEqual(accepted, snapshot) then return snapshotPath
    end
    raise syntax 88.900 array("accepted source level is immutable", snapshot~component || " AT_LEAST " || snapshot~sourceLevel)
  end
  .SSCUtil~writeLines(snapshotPath, lines)
  .SSCUtil~writeLines(self~componentDir(snapshot~component) || "/LATEST", .array~of(snapshot~sourceLevel))
  return dir || "/snapshot.osc"

::method persistedSchemaVersion private
  use arg rows
  version = 1
  do row over rows
    if row~left(2) = "V|" then do
      f = .SSCUtil~split(row, "|")
      if f~items >= 2 then version = f[2]
      leave
    end
  end
  return version

::method legacyTrackedEvidenceEqual private
  use arg persistedRows, currentSnap
  currentByPath = .table~new
  do f over currentSnap~files
    currentByPath[f~path] = f~blobHash
  end
  knownFiles = 0
  do row over persistedRows
    if row~left(2) <> "F|" then iterate
    fields = .SSCUtil~split(row, "|")
    if fields~items < 3 then return .false
    path = .SSCUtil~decode(fields[2])
    hash = fields[3]
    knownFiles += 1
    if \currentByPath~hasIndex(path) then return .false
    if currentByPath[path] <> hash then return .false
  end
  return knownFiles > 0

::method releaseEvidenceEqual private
  use arg leftSnap, rightSnap
  if leftSnap~files~items <> rightSnap~files~items then return .false
  rightByPath = .table~new
  do f over rightSnap~files
    rightByPath[f~path] = f~blobHash
  end
  do f over leftSnap~files
    if rightByPath[f~path] == .nil then return .false
    if rightByPath[f~path] <> f~blobHash then return .false
  end
  return .true

::method latestLevel
  expose root
  use arg component
  path = self~componentDir(component) || "/LATEST"
  lines = .SSCUtil~readLines(path)
  if lines~items = 0 then return .nil
  return lines[1]

::method previousAcceptedLevel private
  use arg component, level
  if \datatype(level, "W") then return .nil
  if level <= 1 then return .nil
  do candidate = level - 1 to 1 by -1
    path = self~componentDir(component) || "/levels/" || candidate || "/snapshot.osc"
    if .SSCUtil~fileExists(path) then return candidate
  end
  return .nil

::method loadLatest
  use arg component
  level = self~latestLevel(component)
  if level == .nil then return .nil
  return self~loadSnapshot(component, level)

::method latestIdentityView
  use arg component
  level = self~latestLevel(component)
  if level == .nil then return .nil
  return self~loadIdentitySnapshot(component, level)

::method loadIdentitySnapshot private
  /* Baseline/scan reconciliation needs stable OO identities and the accepted
     external-operation timeline, not a full semantic re-index of historical
     source blobs.  Parse that compact evidence directly from snapshot.osc.
     This is especially important for pre-v0.2.2 repositories: full legacy
     upgrades remain available to impact/export, but they no longer burden the
     ordinary adopt-next-level path. */
  expose baselineViewCache
  use arg component, level
  cacheKey = self~snapshotCacheKey(component, level)
  if baselineViewCache~hasIndex(cacheKey) then return baselineViewCache[cacheKey]
  path = self~componentDir(component) || "/levels/" || level || "/snapshot.osc"
  lines = .SSCUtil~readLines(path)
  if lines~items = 0 then return .nil
  snap = .nil
  do row over lines
    fields = .SSCUtil~split(row, "|")
    if fields~items = 0 then iterate
    kind = fields[1]
    select
      when kind = "H" then do
        snap = .SourceSnapshot~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), fields[4], .SSCUtil~decode(fields[5]))
        snap~markSchemaVersion(1)
      end
      when kind = "V" then snap~markSchemaVersion(fields[2])
      when kind = "C" then snap~addClass(.SourceClassRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), fields[6], .SSCUtil~decode(fields[7]), fields[8]))
      when kind = "M" then do
        entityId = .SSCUtil~decode(fields[2])
        qualified = .SSCUtil~decode(fields[3])
        className = .SSCUtil~decode(fields[4])
        methodName = .SSCUtil~decode(fields[5])
        /* v0.1 parsed one-line directives as method names ending in ';'.
           Normalize only the historical lookup view; immutable rows remain
           byte-for-byte untouched. */
        if methodName~right(1) = ";" then do
          methodName = methodName~left(methodName~length - 1)
          if qualified~right(1) = ";" then qualified = qualified~left(qualified~length - 1)
        end
        snap~addMethod(.SourceMethodRevision~new(entityId, qualified, className, methodName, fields[6], fields[7], .SSCUtil~decode(fields[8]), fields[9], fields[10], .SSCUtil~decode(fields[11]), fields[12], fields[13]))
      end
      when kind = "A" then do
        a = .SourceAttributeRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), fields[6], .SSCUtil~decode(fields[12]), fields[13])
        if .SSCUtil~decode(fields[7]) <> "" then a~mergeAccessor("GET", .SSCUtil~decode(fields[7]), fields[9], .SSCUtil~decode(fields[12]), fields[13])
        if .SSCUtil~decode(fields[8]) <> "" then a~mergeAccessor("SET", .SSCUtil~decode(fields[8]), fields[10], .SSCUtil~decode(fields[12]), fields[13])
        snap~addAttribute(a)
      end
      when kind = "N" then snap~addConstant(.SourceConstantRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), .SSCUtil~decode(fields[6]), fields[7], .SSCUtil~decode(fields[8]), fields[9]))
      when kind = "P" then do
        candidate = .ExternalCandidate~new(.SSCUtil~decode(fields[3]), fields[4], fields[5], "", .SSCUtil~split(.SSCUtil~decode(fields[7]), ","), .SSCUtil~split(.SSCUtil~decode(fields[8]), ","), .SSCUtil~decode(fields[9]), .SSCUtil~decode(fields[10]), fields[11], fields[6], fields[2])
        snap~addCandidate(candidate)
      end
      when kind = "E" then do
        candidate = .ExternalCandidate~new(.SSCUtil~decode(fields[3]), fields[4], fields[5], "", .SSCUtil~split(.SSCUtil~decode(fields[7]), ","), .SSCUtil~split(.SSCUtil~decode(fields[8]), ","), .SSCUtil~decode(fields[9]), .SSCUtil~decode(fields[10]), fields[11], fields[6])
        snap~addExternalOperation(.ExternalOperationRevision~new(fields[2], candidate))
      end
      otherwise nop
    end
  end
  if snap == .nil then return .nil
  previous = .nil
  previousLevel = self~previousAcceptedLevel(component, level)
  if previousLevel <> .nil then do
    previous = self~loadIdentitySnapshot(component, previousLevel)
    if previous <> .nil then if previous~lineage <> snap~lineage then previous = .nil
  end
  self~reconcileTrackingSet(snap, previous, .false)
  baselineViewCache[cacheKey] = snap
  return snap

::method loadSnapshot
  expose snapshotCache
  use arg component, level
  cacheKey = self~snapshotCacheKey(component, level)
  if snapshotCache~hasIndex(cacheKey) then return snapshotCache[cacheKey]
  path = self~componentDir(component) || "/levels/" || level || "/snapshot.osc"
  lines = .SSCUtil~readLines(path)
  if lines~items = 0 then return .nil
  snap = .nil
  do row over lines
    fields = .SSCUtil~split(row, "|")
    kind = fields[1]
    select
      when kind = "H" then do
        snap = .SourceSnapshot~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), fields[4], .SSCUtil~decode(fields[5]))
        snap~markSchemaVersion(1)
      end
      when kind = "V" then snap~markSchemaVersion(fields[2])
      when kind = "F" then snap~addFile(.SourceFileRevision~new(.SSCUtil~decode(fields[2]), fields[3]))
      when kind = "K" then snap~addPackage(.SourcePackageRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), .SSCUtil~decode(fields[6]), fields[7], .SSCUtil~decode(fields[8]), fields[9]))
      when kind = "C" then snap~addClass(.SourceClassRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), fields[6], .SSCUtil~decode(fields[7]), fields[8]))
      when kind = "M" then snap~addMethod(.SourceMethodRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), fields[6], fields[7], .SSCUtil~decode(fields[8]), fields[9], fields[10], .SSCUtil~decode(fields[11]), fields[12], fields[13]))
      when kind = "A" then do
        a = .SourceAttributeRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), fields[6], .SSCUtil~decode(fields[12]), fields[13])
        if .SSCUtil~decode(fields[7]) <> "" then a~mergeAccessor("GET", .SSCUtil~decode(fields[7]), fields[9], .SSCUtil~decode(fields[12]), fields[13])
        if .SSCUtil~decode(fields[8]) <> "" then a~mergeAccessor("SET", .SSCUtil~decode(fields[8]), fields[10], .SSCUtil~decode(fields[12]), fields[13])
        snap~addAttribute(a)
      end
      when kind = "N" then snap~addConstant(.SourceConstantRevision~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), .SSCUtil~decode(fields[6]), fields[7], .SSCUtil~decode(fields[8]), fields[9]))
      when kind = "R" then snap~addRequirement(.SourceRequirement~new(.SSCUtil~decode(fields[2]), fields[3], fields[4], .SSCUtil~decode(fields[5]), fields[6], .SSCUtil~decode(fields[7])))
      when kind = "U" then do
        useKind = "DYNAMIC_MESSAGE"; targetClass = ""; detail = ""; targetScope = "UNKNOWN"; consumerScope = "UNKNOWN"
        if fields~items >= 6 then useKind = fields[6]
        if fields~items >= 7 then targetClass = .SSCUtil~decode(fields[7])
        if fields~items >= 8 then detail = .SSCUtil~decode(fields[8])
        if fields~items >= 9 then targetScope = fields[9]
        if fields~items >= 10 then consumerScope = fields[10]
        snap~addUse(.SourceUse~new(.SSCUtil~decode(fields[2]), .SSCUtil~decode(fields[3]), fields[4], .SSCUtil~decode(fields[5]), useKind, targetClass, detail, targetScope, consumerScope))
      end
      when kind = "D" then snap~addDataDependency(.SourceDataDependency~new(.SSCUtil~decode(fields[2]), fields[3], .SSCUtil~decode(fields[4]), .SSCUtil~decode(fields[5]), fields[6], .SSCUtil~decode(fields[7])))
      when kind = "P" then do
        c = .ExternalCandidate~new(.SSCUtil~decode(fields[3]), fields[4], fields[5], "", .SSCUtil~split(.SSCUtil~decode(fields[7]), ","), .SSCUtil~split(.SSCUtil~decode(fields[8]), ","), .SSCUtil~decode(fields[9]), .SSCUtil~decode(fields[10]), fields[11])
        c~overrideStatementHash(fields[6])
        c~overrideProposalId(fields[2])
        snap~addCandidate(c)
      end
      when kind = "E" then do
        c = .ExternalCandidate~new(.SSCUtil~decode(fields[3]), fields[4], fields[5], "", .SSCUtil~split(.SSCUtil~decode(fields[7]), ","), .SSCUtil~split(.SSCUtil~decode(fields[8]), ","), .SSCUtil~decode(fields[9]), .SSCUtil~decode(fields[10]), fields[11])
        e = .ExternalOperationRevision~new(fields[2], c)
        /* Preserve persisted statement hash even though statement text is not stored. */
        e~overrideStatementHash(fields[6])
        snap~addExternalOperation(e)
      end
      otherwise nop
    end
  end
  /* v0.1 snapshots predate package contracts and receiver-side use evidence.
     Re-index their immutable source blobs in memory with the current analyzer
     so an analyzer upgrade does not masquerade as an application change.
     This derived view is rebuildable and never rewrites the accepted level. */
  if (snap~schemaVersion < 4 | snap~packages~items = 0) & snap~files~items > 0 then snap = self~upgradeLegacySnapshot(snap)

  previous = .nil
  previousLevel = self~previousAcceptedLevel(component, level)
  if previousLevel <> .nil then do
    previous = self~loadSnapshot(component, previousLevel)
    if previous <> .nil then if previous~lineage <> snap~lineage then previous = .nil
  end
  self~reconcileTrackingSet(snap, previous, .false)
  snapshotCache[cacheKey] = snap
  return snap

::method upgradeLegacySnapshot private
  use arg legacy
  temp = SysTempFileName("/tmp/osc_legacy_reindex_??????")
  .SSCUtil~ensureDir(temp)
  do f over legacy~files
    .SSCUtil~writeAll(temp || "/" || f~path, self~blob(f~blobHash))
  end
  upgraded = .OoRexxSourceAnalyzer~new(.nil)~analyzeTree(temp, legacy~component, legacy~lineage, legacy~sourceLevel, legacy~label)
  address system 'rm -rf ' || .SSCUtil~shellQuote(temp)

  /* Preserve stable historical entity IDs whenever v0.1 had enough semantic
     evidence to identify the same entity. */
  do c over upgraded~classes
    do oc over legacy~classes
      if oc~qualifiedName~upper = c~qualifiedName~upper then do
        c~reassignEntityId(oc~entityId)
        leave
      end
    end
  end
  do m over upgraded~methods
    matched = .nil
    do om over legacy~methods
      oldName = om~methodName
      if oldName~right(1) = ";" then oldName = oldName~left(oldName~length - 1)
      if om~className~upper = m~className~upper & oldName~upper = m~methodName~upper & om~scope = m~scope then do
        matched = om
        leave
      end
    end
    if matched <> .nil then m~reassignEntityId(matched~entityId)
  end
  do a over upgraded~attributes
    do oa over legacy~attributes
      if oa~identityKey~upper = a~identityKey~upper then do
        a~reassignEntityId(oa~entityId)
        leave
      end
    end
  end
  do n over upgraded~constants
    do on over legacy~constants
      if on~identityKey~upper = n~identityKey~upper then do
        n~reassignEntityId(on~entityId)
        leave
      end
    end
  end
  return upgraded

::method exportSnapshot
  use arg snapshot, destination
  .SSCUtil~ensureDir(destination)
  do f over snapshot~files
    content = self~blob(f~blobHash)
    .SSCUtil~writeAll(destination || "/" || f~path, content)
  end
  return snapshot~files~items

::method methodSource
  use arg component, level, qualifiedName
  if level == .nil | level = "" then snapshot = self~loadLatest(component)
  else snapshot = self~loadSnapshot(component, level)
  if snapshot == .nil then return .nil
  m = snapshot~methodByQualifiedName(qualifiedName)
  if m == .nil then return .nil
  f = snapshot~fileByPath(m~path)
  if f == .nil then return .nil
  content = self~blob(f~blobHash)
  temp = SysTempFileName("/tmp/osc_method_source_??????")
  .SSCUtil~writeAll(temp, content)
  lines = .SSCUtil~readLines(temp)
  call SysFileDelete temp
  out = .array~new
  do i = m~lineStart to m~lineEnd
    if i <= lines~items then out~append(lines[i])
  end
  return .SSCUtil~join(out, "0a"x)

::method applyTrackingDecisions
  use arg snapshot
  return self~reconcileTrackingSet(snapshot, .nil, .false)

::method reconcileTrackingSet
  use arg snapshot, previous = .nil, recordProposals = .false
  snapshot~clearExternalOperations
  assigned = .table~new
  claimed = .set~new
  rejected = .set~new
  active = self~activeDecisions

  /* 1. Exact proposal decisions are authoritative. */
  do i = 1 to snapshot~candidates~items
    c = snapshot~candidates[i]
    d = self~decisionForProposal(c~proposalId)
    if d == .nil then iterate
    if d~decision = "REJECTED" then do
      rejected~put(i)
      iterate
    end
    if d~decision = "ACCEPTED" & d~externalId <> "" then do
      if \claimed~hasIndex(d~externalId) then do
        assigned[i] = d~externalId
        claimed~put(d~externalId)
      end
    end
  end

  /* 2. The immediately preceding accepted snapshot is the strongest history
        for identity continuity.  In particular, once an operation moved in
        v0.6, v0.7 must compare against that v0.6 location rather than against
        the method in which the operation happened to be first accepted. */
  if previous <> .nil then self~assignPreviousContinuity(snapshot, previous, assigned, claimed)

  /* 3. Older repositories may not have a usable preceding semantic snapshot.
        Same-method contextual evidence can still bind an accepted decision,
        but only one-to-one. */
  self~assignDecisionContinuity(snapshot, active, assigned, claimed)

  /* 4. Cross-method relocation is deliberately conservative and global.  A
        candidate and accepted identity must be each other's only remaining
        compatible partner.  Merely using the same SQL table is never enough
        to consume an existing identity while that identity's current call-site
        remains present. */
  self~assignUniqueRelocations(snapshot, previous, active, assigned, claimed)

  do i = 1 to snapshot~candidates~items
    c = snapshot~candidates[i]
    if assigned~hasIndex(i) then do
      snapshot~addExternalOperation(.ExternalOperationRevision~new(assigned[i], c))
      iterate
    end
    if rejected~hasIndex(i) then iterate
    d = self~decisionForProposal(c~proposalId)
    /* An accepted exact decision that could not be bound because its identity
       was already claimed is a conflict, not permission to duplicate it.  Keep
       it visible to the caller as unresolved rather than silently merging. */
    if recordProposals & d == .nil then self~recordProposal(c, "PROPOSED", "HIGH")
  end
  return snapshot

::method candidateStatus
  use arg candidate, snapshot
  if snapshot~externalForCandidate(candidate) <> .nil then return "TRACKED"
  d = self~decisionForProposal(candidate~proposalId)
  if d <> .nil then if d~decision = "REJECTED" then return "REJECTED"
  return "PENDING"

::method assignPreviousContinuity private
  use arg snapshot, previous, assigned, claimed
  pairs = .array~new
  do i = 1 to snapshot~candidates~items
    if assigned~hasIndex(i) then iterate
    c = snapshot~candidates[i]
    count = 0; chosen = ""
    do e over previous~externalOperations
      if claimed~hasIndex(e~externalId) then iterate
      if self~currentContinuityMatch(e, c) then do
        count += 1
        chosen = e~externalId
      end
    end
    if count <> 1 then iterate
    e = previous~externalById(chosen)
    reciprocal = 0
    do j = 1 to snapshot~candidates~items
      if assigned~hasIndex(j) then iterate
      if self~currentContinuityMatch(e, snapshot~candidates[j]) then reciprocal += 1
    end
    if reciprocal = 1 then pairs~append(i || "|" || chosen)
  end
  self~applyTrackingPairs(pairs, assigned, claimed)

::method assignDecisionContinuity private
  use arg snapshot, active, assigned, claimed
  pairs = .array~new
  do i = 1 to snapshot~candidates~items
    if assigned~hasIndex(i) then iterate
    c = snapshot~candidates[i]
    count = 0; chosen = ""
    do d over active
      if d~decision <> "ACCEPTED" | d~externalId = "" then iterate
      if claimed~hasIndex(d~externalId) then iterate
      if self~decisionContinuityMatch(d, c) then do
        count += 1
        chosen = d~externalId
      end
    end
    if count <> 1 then iterate
    reciprocal = 0
    do j = 1 to snapshot~candidates~items
      if assigned~hasIndex(j) then iterate
      do d over active
        if d~externalId <> chosen then iterate
        if self~decisionContinuityMatch(d, snapshot~candidates[j]) then reciprocal += 1
        leave
      end
    end
    if reciprocal = 1 then pairs~append(i || "|" || chosen)
  end
  self~applyTrackingPairs(pairs, assigned, claimed)

::method assignUniqueRelocations private
  use arg snapshot, previous, active, assigned, claimed
  pairs = .array~new
  do i = 1 to snapshot~candidates~items
    if assigned~hasIndex(i) then iterate
    c = snapshot~candidates[i]
    count = 0; chosen = ""
    do d over active
      if d~decision <> "ACCEPTED" | d~externalId = "" then iterate
      if claimed~hasIndex(d~externalId) then iterate
      prevE = .nil
      if previous <> .nil then prevE = previous~externalById(d~externalId)
      if self~relocationAnchorMatch(d, prevE, c) then do
        count += 1
        chosen = d~externalId
      end
    end
    if count <> 1 then iterate

    /* The chosen accepted identity must itself have exactly one remaining
       compatible candidate.  This is the one-to-one evidence that v0.2.2 was
       missing in the FederationBank level-7 case. */
    reciprocal = 0
    do d over active
      if d~externalId <> chosen then iterate
      prevE = .nil
      if previous <> .nil then prevE = previous~externalById(d~externalId)
      do j = 1 to snapshot~candidates~items
        if assigned~hasIndex(j) then iterate
        if self~relocationAnchorMatch(d, prevE, snapshot~candidates[j]) then reciprocal += 1
      end
      leave
    end
    if reciprocal = 1 then pairs~append(i || "|" || chosen)
  end
  self~applyTrackingPairs(pairs, assigned, claimed)

::method applyTrackingPairs private
  use arg pairs, assigned, claimed
  do pair over pairs
    parse var pair index "|" externalId
    if assigned~hasIndex(index) then iterate
    if claimed~hasIndex(externalId) then iterate
    assigned[index] = externalId
    claimed~put(externalId)
  end

::method currentContinuityMatch private
  use arg external, candidate
  if external~kind <> candidate~kind then return .false
  if \self~methodKeyEquivalent(external~methodKey, candidate~methodKey) then return .false
  if external~statementHash = candidate~statementHash then return .true
  score = self~contextScore(external~beforeHashes, external~afterHashes, candidate~beforeHashes, candidate~afterHashes)
  /* Very strong surrounding evidence identifies the same call-site even when
     the SQL itself changes operation/source; that is precisely when the tracked
     entity must survive so the semantic delta can say SELECT -> DELETE, etc. */
  if score >= 75 then return .true
  /* Weaker context may support continuity only inside the same SQL surface. */
  if candidate~kind = "SQL" then if \self~relocationSemanticMatchExternal(external, candidate) then return .false
  return score >= 50

::method decisionContinuityMatch private
  use arg decision, candidate
  if decision~kind <> candidate~kind then return .false
  if \self~methodKeyEquivalent(decision~methodKey, candidate~methodKey) then return .false
  if decision~statementHash = candidate~statementHash then return .true
  score = self~contextScore(decision~beforeHashes, decision~afterHashes, candidate~beforeHashes, candidate~afterHashes)
  if score >= 75 then return .true
  if candidate~kind = "SQL" then if \self~relocationSemanticMatch(decision, candidate) then return .false
  return score >= 50

::method relocationAnchorMatch private
  use arg decision, previousExternal, candidate
  if previousExternal <> .nil then do
    anchorMethod = previousExternal~methodKey
    anchorKind = previousExternal~kind
  end
  else do
    anchorMethod = decision~methodKey
    anchorKind = decision~kind
  end
  if anchorKind <> candidate~kind then return .false
  if self~methodKeyEquivalent(anchorMethod, candidate~methodKey) then return .false
  if \self~sameMethodOwner(anchorMethod, candidate~methodKey) then return .false

  if previousExternal <> .nil then return self~relocationSemanticMatchExternal(previousExternal, candidate)
  return self~relocationSemanticMatch(decision, candidate)

::method relocationSemanticMatchExternal private
  use arg external, candidate
  if external~statementHash = candidate~statementHash then return .true
  if candidate~kind <> "SQL" then return .false
  oldOperation = external~operation
  if oldOperation <> candidate~operation then return .false
  oldSource = .SQLSemantic~field(external~semanticContract, "sources")~upper~strip
  newSource = .SQLSemantic~field(candidate~semanticContract, "sources")~upper~strip
  if oldSource = "" | newSource = "" then return .false
  return oldSource = newSource

::method ensureProposalCache private
  expose root proposalCache
  if proposalCache~isA(.table) then return
  proposalCache = .table~new
  lines = .SSCUtil~readLines(root || "/proposals.osc")
  do row over lines
    f = .SSCUtil~split(row, "|")
    if f~items >= 1 then proposalCache[f[1]] = f
  end

::method recordProposal
  expose root proposalCache
  use arg candidate, classification = "PROPOSED", confidence = "HIGH"
  if self~proposal(candidate~proposalId) <> .nil then return candidate~proposalId
  path = root || "/proposals.osc"
  row = candidate~proposalId || "|" || classification || "|" || confidence || "|" || .SSCUtil~encode(candidate~methodKey) || "|" || candidate~kind || "|" || candidate~operation || "|" || candidate~statementHash || "|" || .SSCUtil~encode(candidate~beforeSignature) || "|" || .SSCUtil~encode(candidate~afterSignature) || "|" || .SSCUtil~encode(candidate~semanticContract) || "|" || .SSCUtil~encode(candidate~path) || "|" || candidate~line
  .SSCUtil~appendLine(path, row)
  self~ensureProposalCache
  proposalCache[candidate~proposalId] = .SSCUtil~split(row, "|")
  return candidate~proposalId

::method proposal
  expose proposalCache
  use arg proposalId
  self~ensureProposalCache
  if proposalCache~hasIndex(proposalId) then return proposalCache[proposalId]
  return .nil

::method ensureDecisionCache private
  expose root decisionsCache decisionByProposal
  if decisionsCache~isA(.array) & decisionByProposal~isA(.table) then return
  decisionsCache = .array~new
  decisionByProposal = .table~new
  lines = .SSCUtil~readLines(root || "/decisions.osc")
  do row over lines
    f = .SSCUtil~split(row, "|")
    if f~items < 11 then iterate
    d = .TrackingDecision~new(f[1], f[2], f[3], .SSCUtil~decode(f[4]), f[5], f[6], .SSCUtil~split(.SSCUtil~decode(f[7]), ","), .SSCUtil~split(.SSCUtil~decode(f[8]), ","), .SSCUtil~decode(f[9]), .SSCUtil~decode(f[10]), f[11])
    decisionsCache~append(d)
    /* The ledger is append-only.  The last row for a proposal is authoritative. */
    decisionByProposal[d~proposalId] = d
  end

::method decisions
  expose decisionsCache
  self~ensureDecisionCache
  return decisionsCache

::method activeDecisions private
  expose decisionByProposal
  self~ensureDecisionCache
  out = .array~new
  do proposalId over decisionByProposal~allIndexes
    out~append(decisionByProposal[proposalId])
  end
  return out

::method decisionForProposal
  expose decisionByProposal
  use arg proposalId
  self~ensureDecisionCache
  if decisionByProposal~hasIndex(proposalId) then return decisionByProposal[proposalId]
  return .nil

::method recordDecision
  expose root decisionsCache decisionByProposal snapshotCache baselineViewCache
  use arg proposalId, decision, reason = "", authority = ""
  proposal = self~proposal(proposalId)
  if proposal == .nil then raise syntax 88.900 array("unknown tracking proposal", proposalId)
  previous = self~decisionForProposal(proposalId)
  if previous <> .nil then do
    if previous~decision = decision~upper then raise syntax 88.900 array("tracking proposal already has this decision", proposalId)
    reason = "supersedes " || previous~decision || ": " || reason
  end
  if authority = "" then do
    authority = value("USER",, "ENVIRONMENT")
    if authority = "" then authority = "UNKNOWN"
  end
  externalId = ""
  if decision~upper = "ACCEPTED" then externalId = .SSCUtil~stableId("EO", .SSCUtil~decode(proposal[4]) || "|" || proposal[5] || "|" || proposalId)
  row = proposalId || "|" || decision~upper || "|" || externalId || "|" || proposal[4] || "|" || proposal[5] || "|" || proposal[7] || "|" || proposal[8] || "|" || proposal[9] || "|" || .SSCUtil~encode(reason) || "|" || .SSCUtil~encode(authority) || "|" || .SSCUtil~now
  .SSCUtil~appendLine(root || "/decisions.osc", row)
  /* Decisions change derived semantic views, never accepted source bytes. */
  decisionsCache = .nil
  decisionByProposal = .nil
  snapshotCache = .table~new
  baselineViewCache = .table~new
  return externalId

::method matchTrackingDecision
  use arg candidate
  /* Single-candidate lookup is intentionally conservative.  Exact and
     same-method contextual decisions are safe here; cross-method relocation
     requires the whole candidate set and is handled by reconcileTrackingSet. */
  exact = self~decisionForProposal(candidate~proposalId)
  if exact <> .nil then return exact

  active = self~activeDecisions
  best = .nil; bestScore = 0; bestCount = 0
  do d over active
    if d~decision <> "ACCEPTED" then iterate
    if \self~methodKeyEquivalent(d~methodKey, candidate~methodKey) then iterate
    if d~kind <> candidate~kind then iterate
    score = self~contextScore(d~beforeHashes, d~afterHashes, candidate~beforeHashes, candidate~afterHashes)
    if d~statementHash = candidate~statementHash then score = 100
    if score > bestScore then do
      best = d; bestScore = score; bestCount = 1
    end
    else if score = bestScore & score > 0 then bestCount += 1
  end
  if bestScore >= 50 & bestCount = 1 then return best
  return .nil

::method relocationSemanticMatch private
  use arg decision, candidate
  if decision~statementHash = candidate~statementHash then return .true
  if candidate~kind <> "SQL" then return .false
  oldProposal = self~proposal(decision~proposalId)
  if oldProposal == .nil then return .false
  if oldProposal~items < 10 then return .false
  oldOperation = oldProposal[6]
  if oldOperation <> candidate~operation then return .false
  oldContract = .SSCUtil~decode(oldProposal[10])
  oldSource = .SQLSemantic~field(oldContract, "sources")~upper~strip
  newSource = .SQLSemantic~field(candidate~semanticContract, "sources")~upper~strip
  if oldSource = "" | newSource = "" then return .false
  return oldSource = newSource

::method sameMethodOwner private
  use arg oldKey, newKey
  o = self~methodOwnerKey(oldKey)
  n = self~methodOwnerKey(newKey)
  if o = "" | n = "" then return .false
  /* Package executable pseudo-methods intentionally do not participate in
     automatic cross-method relocation. */
  if pos(".PACKAGE", o) > 0 | pos(".PACKAGE", n) > 0 then return .false
  return o = n

::method methodOwnerKey private
  use arg key
  k = key~string~upper
  h = k~lastPos("#")
  if h > 0 then k = k~left(h - 1)
  p = k~lastPos(".")
  if p <= 0 then return ""
  return k~left(p - 1)

::method methodKeyEquivalent private
  use arg oldKey, newKey
  o = oldKey~upper
  n = newKey~upper
  if o = n then return .true
  /* v0.1 had no side discriminator.  Permit a historical decision to bind to
     the same base method when the contextual MD5 evidence also matches. */
  if pos("#", o) = 0 then do
    h = n~lastPos("#")
    if h > 0 then if n~left(h - 1) = o then return .true
  end
  return .false

::method contextScore private
  use arg oldBefore, oldAfter, newBefore, newAfter
  old = .array~new; new = .array~new
  do x over oldBefore; if x <> "" then old~append(x); end
  do x over oldAfter; if x <> "" then old~append(x); end
  do x over newBefore; if x <> "" then new~append(x); end
  do x over newAfter; if x <> "" then new~append(x); end
  if old~items = 0 | new~items = 0 then return 0
  matched = 0
  used = .set~new
  do i = 1 to old~items
    do j = 1 to new~items
      if used~hasIndex(j) then iterate
      if old[i] = new[j] then do
        matched += 1
        used~put(j)
        leave
      end
    end
  end
  denom = old~items
  if new~items > denom then denom = new~items
  return (matched * 100) % denom


::class OoRexxSourceAnalyzer public
::attribute repository get
::attribute contextWindow get

::method init
  expose repository contextWindow
  use arg repository = .nil, contextWindow = 4

::method analyzeTree
  expose repository contextWindow
  use arg root, component, lineage = "MAIN", sourceLevel = "UNKNOWN", label = ""

  /* Establish the historical semantic view before allocating the incoming
     analysis graph.  On the debug interpreter this avoids severe retention/GC
     pressure when a large current tree is followed by multiple legacy re-index
     passes, and it gives reconciliation an explicit known baseline. */
  previous = .nil
  if repository <> .nil then previous = repository~latestIdentityView(component)

  /* Context MD5 and source SHA-256 are both batched, but the hashes have a
     dependency order: candidate/proposal SHA identities include contextual
     MD5 values.  Pass 1 therefore discovers MD5 payloads while SHA collection
     is disposable.  Pass 2 discovers the final SHA payload set using real MD5
     values.  Pass 3 is the authoritative semantic pass with no hash process
     creation at entity granularity. */
  warmer = .OoRexxSourceAnalyzer~new(.nil, contextWindow)

  .SSCUtil~beginMd5Batch
  .SSCUtil~beginContentHashBatch
  warmer~analyzeTreePass(root, component, lineage, sourceLevel, label)
  .SSCUtil~flushMd5Batch

  /* Discard SHA placeholders derived from zero MD5s and recollect with the
     real contextual fingerprints now resident in the MD5 cache. */
  .SSCUtil~beginContentHashBatch
  warmer~analyzeTreePass(root, component, lineage, sourceLevel, label)
  .SSCUtil~flushContentHashBatch
  .SSCUtil~endMd5Batch

  snap = self~analyzeTreePass(root, component, lineage, sourceLevel, label)
  .SSCUtil~endContentHashBatch
  .SSCUtil~releaseHashCaches

  if repository <> .nil then repository~reconcileTrackingSet(snap, previous, .true)
  return snap

::method analyzeTreePass private
  use arg root, component, lineage = "MAIN", sourceLevel = "UNKNOWN", label = ""
  snap = .SourceSnapshot~new(component, lineage, sourceLevel, label)

  /* Release evidence is lossless and independent of semantic parsing.  Every
     file is retained in the content-addressed blob store/export view; only
     ooRexx sources below are parsed into semantic entities. */
  call SysFileTree root || "/*", "allfiles.", "FOS"
  do i = 1 to allfiles.0
    if .SSCUtil~basename(allfiles.i) = ".OSC_ARCHIVE_ORIGIN" then iterate
    self~captureReleaseFile(allfiles.i, root, snap)
  end

  call SysFileTree root || "/*.cls", "files.", "FOS"
  do i = 1 to files.0
    self~analyzeFile(files.i, root, snap)
  end
  call SysFileTree root || "/*.rex", "rexfiles.", "FOS"
  do i = 1 to rexfiles.0
    self~analyzeFile(rexfiles.i, root, snap)
  end
  return snap

::method captureReleaseFile private
  use arg path, root, snap
  rel = .SSCUtil~relativePath(path, root)
  rawContent = .SSCUtil~readAll(path)
  snap~addFile(.SourceFileRevision~new(rel, .SSCUtil~contentHash(rawContent), rawContent))

::method analyzeFile private
  expose repository contextWindow
  use arg path, root, snap
  lines = .SSCUtil~readLines(path)
  codeLines = .SSCUtil~codeLines(lines)
  rel = .SSCUtil~relativePath(path, root)

  self~capturePackageContract(codeLines, rel, snap)
  packageAnchor = self~packageAnchor(codeLines, rel)
  packageConsumer = snap~component || ".PACKAGE." || packageAnchor

  currentClass = "PACKAGE"
  currentMethod = ""
  methodStart = 0
  methodDirective = ""
  inlineBody = ""
  bodyStart = 0
  currentAttribute = ""
  attributeStart = 0
  attributeDirective = ""
  attributeInlineBody = ""
  attributeBodyStart = 0

  do i = 1 to lines~items + 1
    if i <= lines~items then do
      line = lines[i]
      codeLine = codeLines[i]
    end
    else do
      line = "::EOF"
      codeLine = "::EOF"
    end
    n = .SSCUtil~normalizeLine(codeLine)
    upper = n~upper

    if i <= lines~items then do
      consumerKey = snap~component || "." || currentClass
      if currentMethod <> "" then consumerKey ||= "." || currentMethod
      else if currentAttribute <> "" then consumerKey ||= "." || currentAttribute || "#ATTRIBUTE_" || self~attributeAccessMode(attributeDirective)
      self~parseRequirement(lines[i], rel, i, consumerKey, snap)
      self~parseDataDependency(lines[i], rel, i, consumerKey, snap)

      /* Executable package code is real ooRexx behaviour too.  This is common
         in test programs, launchers and scripts, and constructor dependencies
         there must participate in impact analysis just like method bodies. */
      if currentMethod = "" & currentClass = "PACKAGE" & n <> "" & upper~left(2) <> "::" & n~left(2) <> "--" then do
        self~captureMessageUses(codeLines[i], rel, i, packageConsumer, "PACKAGE", "PACKAGE", snap)
        if .SQLSemantic~looksLikeSQL(codeLines[i]) | .CommandSemantic~looksLikeCommand(codeLines[i]) then do
          before = self~contextHashes(codeLines, 1, codeLines~items, i, -1, contextWindow)
          after = self~contextHashes(codeLines, 1, codeLines~items, i, 1, contextWindow)
          self~captureExternalCandidate(codeLines[i], rel, i, packageConsumer, before, after, snap)
        end
      end
    end

    if upper~left(8) = "::CLASS " then do
      if currentMethod <> "" then self~finalizeMethod(lines, codeLines, rel, snap, currentClass, currentMethod, methodDirective, methodStart, bodyStart, i - 1, inlineBody)
      if currentAttribute <> "" then self~finalizeAttribute(lines, codeLines, rel, snap, currentClass, currentAttribute, attributeDirective, attributeStart, attributeBodyStart, i - 1, attributeInlineBody)
      currentMethod = ""; inlineBody = ""; currentAttribute = ""; attributeInlineBody = ""
      currentClass = word(n, 2)
      classContract = subword(n, 3)
      classEntity = .SSCUtil~stableId("C", snap~lineage || "|CLASS|" || currentClass)
      snap~addClass(.SourceClassRevision~new(classEntity, snap~component || "." || currentClass, currentClass, classContract, .SSCUtil~contentHash(classContract), rel, i))
      iterate
    end

    if upper~left(12) = "::ATTRIBUTE " then do
      if currentMethod <> "" then self~finalizeMethod(lines, codeLines, rel, snap, currentClass, currentMethod, methodDirective, methodStart, bodyStart, i - 1, inlineBody)
      if currentAttribute <> "" then self~finalizeAttribute(lines, codeLines, rel, snap, currentClass, currentAttribute, attributeDirective, attributeStart, attributeBodyStart, i - 1, attributeInlineBody)
      currentMethod = ""; inlineBody = ""; currentAttribute = ""; attributeInlineBody = ""
      parts = .SSCUtil~splitRexxStatements(n)
      attributeDirective = parts[1]
      currentAttribute = word(attributeDirective, 2)
      attributeInlineBody = self~remainingStatements(parts)
      attributeStart = i
      attributeBodyStart = i + 1
      if self~attributeAccessMode(attributeDirective) = "BOTH" then do
        self~finalizeAttribute(lines, codeLines, rel, snap, currentClass, currentAttribute, attributeDirective, attributeStart, attributeBodyStart, i, attributeInlineBody)
        currentAttribute = ""; attributeInlineBody = ""
      end
      iterate
    end

    if upper~left(11) = "::CONSTANT " then do
      if currentMethod <> "" then self~finalizeMethod(lines, codeLines, rel, snap, currentClass, currentMethod, methodDirective, methodStart, bodyStart, i - 1, inlineBody)
      if currentAttribute <> "" then self~finalizeAttribute(lines, codeLines, rel, snap, currentClass, currentAttribute, attributeDirective, attributeStart, attributeBodyStart, i - 1, attributeInlineBody)
      currentMethod = ""; inlineBody = ""; currentAttribute = ""; attributeInlineBody = ""
      self~captureConstant(n, rel, i, currentClass, snap)
      iterate
    end

    if upper~left(9) = "::METHOD " then do
      if currentMethod <> "" then self~finalizeMethod(lines, codeLines, rel, snap, currentClass, currentMethod, methodDirective, methodStart, bodyStart, i - 1, inlineBody)
      if currentAttribute <> "" then self~finalizeAttribute(lines, codeLines, rel, snap, currentClass, currentAttribute, attributeDirective, attributeStart, attributeBodyStart, i - 1, attributeInlineBody)
      currentAttribute = ""; attributeInlineBody = ""
      parts = .SSCUtil~splitRexxStatements(n)
      methodDirective = parts[1]
      currentMethod = word(methodDirective, 2)
      inlineBody = self~remainingStatements(parts)
      methodStart = i
      bodyStart = i + 1
      iterate
    end

    if upper~left(10) = "::ROUTINE " then do
      if currentMethod <> "" then self~finalizeMethod(lines, codeLines, rel, snap, currentClass, currentMethod, methodDirective, methodStart, bodyStart, i - 1, inlineBody)
      if currentAttribute <> "" then self~finalizeAttribute(lines, codeLines, rel, snap, currentClass, currentAttribute, attributeDirective, attributeStart, attributeBodyStart, i - 1, attributeInlineBody)
      currentAttribute = ""; attributeInlineBody = ""
      currentClass = "PACKAGE"
      parts = .SSCUtil~splitRexxStatements(n)
      routineDirective = parts[1]
      currentMethod = word(routineDirective, 2)
      methodDirective = routineDirective~changestr("::ROUTINE", "::METHOD")
      inlineBody = self~remainingStatements(parts)
      methodStart = i
      bodyStart = i + 1
      iterate
    end

    if upper~left(2) = "::" & currentMethod <> "" & upper~left(9) <> "::METHOD " then do
      self~finalizeMethod(lines, codeLines, rel, snap, currentClass, currentMethod, methodDirective, methodStart, bodyStart, i - 1, inlineBody)
      currentMethod = ""; inlineBody = ""
    end
    if upper~left(2) = "::" & currentAttribute <> "" & upper~left(12) <> "::ATTRIBUTE " then do
      self~finalizeAttribute(lines, codeLines, rel, snap, currentClass, currentAttribute, attributeDirective, attributeStart, attributeBodyStart, i - 1, attributeInlineBody)
      currentAttribute = ""; attributeInlineBody = ""
    end
  end

::method attributeAccessMode private
  use arg directive
  u = directive~upper
  hasGet = .SSCUtil~containsWord(u, "GET")
  hasSet = .SSCUtil~containsWord(u, "SET")
  if hasGet & \hasSet then return "GET"
  if hasSet & \hasGet then return "SET"
  return "BOTH"

::method finalizeAttribute private
  expose repository contextWindow
  use arg lines, codeLines, path, snap, className, attributeName, directive, startLine, bodyStart, endLine, inlineBody = ""
  if endLine < startLine then endLine = startLine
  accessMode = self~attributeAccessMode(directive)
  scope = "INSTANCE"
  if .SSCUtil~containsWord(directive~upper, "CLASS") then scope = "CLASS"
  bodyNorm = .array~new
  inlineStatements = .SSCUtil~splitRexxStatements(inlineBody)
  do stmt over inlineStatements
    n = .SSCUtil~normalizeLine(stmt)
    if n <> "" then bodyNorm~append(n)
  end
  if accessMode <> "BOTH" then do i = bodyStart to endLine
    n = .SSCUtil~normalizeLine(codeLines[i])
    if n <> "" then bodyNorm~append(n)
  end
  bodyHash = ""
  if bodyNorm~items > 0 then bodyHash = .SSCUtil~contentHash(.SSCUtil~join(bodyNorm, "0a"x))
  qualified = snap~component || "." || className || "." || attributeName
  key = qualified || "#ATTRIBUTE"
  if scope <> "INSTANCE" then key = qualified || "#ATTRIBUTE_" || scope
  attr = snap~attributeByIdentityKey(key)
  if attr == .nil then do
    entityId = .SSCUtil~stableId("A", snap~lineage || "|ATTRIBUTE|" || className || "|" || attributeName || "|" || scope)
    attr = .SourceAttributeRevision~new(entityId, qualified, className, attributeName, scope, path, startLine)
    snap~addAttribute(attr)
  end
  attr~mergeAccessor(accessMode, directive, bodyHash, path, startLine)

  /* Explicit GET/SET attributes can contain arbitrary executable ooRexx
     bodies.  Preserve their dependencies and external-operation candidates as
     accessor-specific consumers rather than losing them between directives. */
  if accessMode <> "BOTH" then do
    accessorKey = attr~identityKey || "_" || accessMode
    do si = 1 to inlineStatements~items
      stmt = inlineStatements[si]
      self~captureMessageUses(stmt, path, startLine, accessorKey, className, scope, snap)
      if .SQLSemantic~looksLikeSQL(stmt) | .CommandSemantic~looksLikeCommand(stmt) then do
        before = self~statementContextHashes(inlineStatements, si, -1, contextWindow)
        after = self~statementContextHashes(inlineStatements, si, 1, contextWindow)
        self~captureExternalCandidate(stmt, path, startLine, accessorKey, before, after, snap)
      end
    end
    do i = bodyStart to endLine
      self~captureMessageUses(codeLines[i], path, i, accessorKey, className, scope, snap)
      if .SQLSemantic~looksLikeSQL(codeLines[i]) | .CommandSemantic~looksLikeCommand(codeLines[i]) then do
        before = self~contextHashes(codeLines, bodyStart, endLine, i, -1, contextWindow)
        after = self~contextHashes(codeLines, bodyStart, endLine, i, 1, contextWindow)
        self~captureExternalCandidate(codeLines[i], path, i, accessorKey, before, after, snap)
      end
    end
  end

::method captureConstant private
  use arg directive, path, lineNo, className, snap
  parts = .SSCUtil~splitRexxStatements(directive)
  d = parts[1]
  name = word(d, 2)
  if name = "" then return
  value = subword(d, 3)
  qualified = snap~component || "." || className || "." || name
  entityId = .SSCUtil~stableId("N", snap~lineage || "|CONSTANT|" || className || "|" || name)
  valueHash = .SSCUtil~contentHash(value)
  snap~addConstant(.SourceConstantRevision~new(entityId, qualified, className, name, value, valueHash, path, lineNo))

::method remainingStatements private
  use arg parts
  if parts~items <= 1 then return ""
  out = .array~new
  do i = 2 to parts~items
    out~append(parts[i])
  end
  return .SSCUtil~join(out, "; ")

::method capturePackageContract private
  use arg lines, path, snap
  options = .array~new
  requires = .array~new
  firstLine = 1
  found = .false
  do i = 1 to lines~items
    n = .SSCUtil~normalizeLine(lines[i])
    u = n~upper
    if u~left(10) = "::OPTIONS " then do
      options~append(subword(n, 2))
      if \found then firstLine = i
      found = .true
    end
    else if u~left(11) = "::REQUIRES " then do
      requires~append(subword(n, 2))
      if \found then firstLine = i
      found = .true
    end
  end
  anchor = self~packageAnchor(lines, path)
  optionsContract = .SSCUtil~join(options, " || ")
  requiresContract = .SSCUtil~join(requires, " || ")
  entityId = .SSCUtil~stableId("K", snap~lineage || "|PACKAGE|" || anchor)
  qualified = snap~component || ".PACKAGE." || anchor
  contractHash = .SSCUtil~contentHash(optionsContract || "|" || requiresContract)
  snap~addPackage(.SourcePackageRevision~new(entityId, qualified, anchor, optionsContract, requiresContract, contractHash, path, firstLine))

::method packageAnchor private
  use arg lines, path
  do line over lines
    n = .SSCUtil~normalizeLine(line)
    u = n~upper
    if u~left(8) = "::CLASS " then return "CLASS:" || word(n, 2)
    if u~left(10) = "::ROUTINE " then do
      parts = .SSCUtil~splitRexxStatements(n)
      return "ROUTINE:" || word(parts[1], 2)
    end
    if u~left(9) = "::METHOD " then do
      parts = .SSCUtil~splitRexxStatements(n)
      return "PACKAGE_METHOD:" || word(parts[1], 2)
    end
  end
  return "FILE:" || .SSCUtil~basename(path)

::method parseRequirement private
  use arg lineText, path, lineNo, currentMethod, snap
  upper = lineText~upper
  p = pos("@SOURCE-REQUIRES", upper)
  if p = 0 then return
  spec = lineText~substr(p + 16)~strip
  if word(spec, 2)~upper <> "AT_LEAST" then return
  target = word(spec, 1)
  level = word(spec, 3)
  if target = "" | level = "" then return
  if \datatype(level, "W") then raise syntax 88.900 array("AT_LEAST source level must be a whole number at " || path || ":" || lineNo, level)
  snap~addRequirement(.SourceRequirement~new(target, level, "DECLARED", path, lineNo, currentMethod))

::method parseDataDependency private
  use arg lineText, path, lineNo, consumer, snap
  upper = lineText~upper
  p = pos("@SOURCE-DATA", upper)
  if p > 0 then do
    spec = lineText~substr(p + 12)~strip
    mode = word(spec, 1)~upper
    target = word(spec, 2)
    if (mode = "READ" | mode = "WRITE" | mode = "READWRITE") & target <> "" then snap~addDataDependency(.SourceDataDependency~new(target, mode, subword(spec, 3), path, lineNo, consumer))
  end
  p = pos("@SOURCE-RESULT-ORDINAL", upper)
  if p > 0 then do
    spec = lineText~substr(p + 22)~strip
    target = word(spec, 1)
    ordinal = word(spec, 2)
    meaning = subword(spec, 3)
    if target <> "" & ordinal <> "" then snap~addDataDependency(.SourceDataDependency~new(target, "RESULT_ORDINAL", ordinal || " " || meaning, path, lineNo, consumer))
  end

::method finalizeMethod private
  expose repository contextWindow
  use arg lines, codeLines, path, snap, className, methodName, directive, startLine, bodyStart, endLine, inlineBody = ""
  if endLine < startLine then endLine = startLine
  scope = "INSTANCE"
  visibility = "PUBLIC"
  upDir = directive~upper
  if .SSCUtil~containsWord(upDir, "CLASS") then scope = "CLASS"
  if .SSCUtil~containsWord(upDir, "PRIVATE") then visibility = "PRIVATE"
  else if .SSCUtil~containsWord(upDir, "PROTECTED") then visibility = "PROTECTED"

  argSpec = ""
  bodyNorm = .array~new
  inlineStatements = .SSCUtil~splitRexxStatements(inlineBody)
  do stmt over inlineStatements
    n = .SSCUtil~normalizeLine(stmt)
    if n = "" then iterate
    if argSpec = "" then do
      u = n~upper
      if u~left(8) = "USE ARG " | u~left(15) = "USE STRICT ARG " then argSpec = n
    end
    if n~left(2) <> "--" then bodyNorm~append(n)
  end
  do i = bodyStart to endLine
    n = .SSCUtil~normalizeLine(lines[i])
    if n = "" then iterate
    if argSpec = "" then do
      u = n~upper
      if u~left(8) = "USE ARG " | u~left(15) = "USE STRICT ARG " then argSpec = n
    end
    /* Ignore pure comments in implementation hash; retain executable text. */
    if n~left(2) <> "--" then bodyNorm~append(n)
  end

  qualified = snap~component || "." || className || "." || methodName
  entitySeed = snap~lineage || "|METHOD|" || className || "|" || methodName || "|" || scope
  entityId = .SSCUtil~stableId("M", entitySeed)
  contractText = scope || "|" || visibility || "|" || argSpec
  contractHash = .SSCUtil~contentHash(contractText)
  bodyHash = .SSCUtil~contentHash(.SSCUtil~join(bodyNorm, "0a"x))
  method = .SourceMethodRevision~new(entityId, qualified, className, methodName, scope, visibility, argSpec, contractHash, bodyHash, path, startLine, endLine)
  snap~addMethod(method)

  methodKey = method~identityKey
  do si = 1 to inlineStatements~items
    stmt = inlineStatements[si]
    self~captureMessageUses(stmt, path, startLine, methodKey, className, scope, snap)
    if .SQLSemantic~looksLikeSQL(stmt) | .CommandSemantic~looksLikeCommand(stmt) then do
      before = self~statementContextHashes(inlineStatements, si, -1, contextWindow)
      after = self~statementContextHashes(inlineStatements, si, 1, contextWindow)
      self~captureExternalCandidate(stmt, path, startLine, methodKey, before, after, snap)
    end
  end
  do i = bodyStart to endLine
    self~captureMessageUses(codeLines[i], path, i, methodKey, className, scope, snap)
    if .SQLSemantic~looksLikeSQL(codeLines[i]) | .CommandSemantic~looksLikeCommand(codeLines[i]) then do
      before = self~contextHashes(codeLines, bodyStart, endLine, i, -1, contextWindow)
      after = self~contextHashes(codeLines, bodyStart, endLine, i, 1, contextWindow)
      self~captureExternalCandidate(codeLines[i], path, i, methodKey, before, after, snap)
    end
  end

::method captureExternalCandidate private
  expose repository
  use arg text, path, lineNo, methodKey, before, after, snap
  candidate = .nil
  confidence = "HIGH"
  if .SQLSemantic~looksLikeSQL(text) then do
    statement = .SQLSemantic~extractStatement(text)
    operation = .SQLSemantic~operation(statement)
    contract = .SQLSemantic~contract(statement)
    candidate = .ExternalCandidate~new(methodKey, "SQL", operation, statement, before, after, contract, path, lineNo)
  end
  else if .CommandSemantic~looksLikeCommand(text) then do
    statement = .CommandSemantic~extractStatement(text)
    contract = .CommandSemantic~contract(statement)
    candidate = .ExternalCandidate~new(methodKey, "CLI_COMMAND", "EXECUTE", statement, before, after, contract, path, lineNo)
  end
  if candidate == .nil then return
  /* Candidate discovery is lexical/semantic fact.  Tracking resolution is a
     set-level operation performed only after the whole incoming tree is known;
     resolving here candidate-by-candidate cannot distinguish a relocation from
     one-to-many additions that happen to touch the same external surface. */
  snap~addCandidate(candidate)

::method contextHashes private
  use arg lines, bodyStart, bodyEnd, center, direction, count
  selected = .array~new
  if direction < 0 then do
    first = center - count
    if first < bodyStart then first = bodyStart
    do i = first to center - 1
      n = .SSCUtil~normalizeLine(lines[i])
      if n <> "" then selected~append(.SSCUtil~md5(n))
    end
  end
  else do
    last = center + count
    if last > bodyEnd then last = bodyEnd
    do i = center + 1 to last
      n = .SSCUtil~normalizeLine(lines[i])
      if n <> "" then selected~append(.SSCUtil~md5(n))
    end
  end
  return selected

::method statementContextHashes private
  use arg statements, center, direction, count
  selected = .array~new
  if direction < 0 then do
    first = center - count
    if first < 1 then first = 1
    do i = first to center - 1
      n = .SSCUtil~normalizeLine(statements[i])
      if n <> "" then selected~append(.SSCUtil~md5(n))
    end
  end
  else do
    last = center + count
    if last > statements~items then last = statements~items
    do i = center + 1 to last
      n = .SSCUtil~normalizeLine(statements[i])
      if n <> "" then selected~append(.SSCUtil~md5(n))
    end
  end
  return selected

::method captureMessageUses private
  use arg lineText, path, lineNo, consumer, currentClass, currentScope, snap
  text = lineText~string
  posn = 1
  validName = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"
  validReceiver = validName || ".$"
  do while posn <= text~length
    p = pos("~", text, posn)
    if p = 0 then leave

    /* Capture the receiver immediately to the left of ~.  A class literal is
       strong static evidence; an arbitrary variable is deliberately weaker. */
    r = p - 1
    do while r >= 1
      c = text~substr(r, 1)
      if pos(c, validReceiver) = 0 then leave
      r -= 1
    end
    receiver = text~substr(r + 1, p - r - 1)

    j = p + 1
    name = ""
    do while j <= text~length
      c = text~substr(j, 1)
      if pos(c, validName) = 0 then leave
      name ||= c
      j += 1
    end
    if name <> "" then do
      /* A message-term assignment at the start of a clause sends NAME=.  In
         expression contexts (for example IF obj~name = x) the same token is
         a getter followed by Rexx comparison, so retain NAME there. */
      k = j
      do while k <= text~length & text~substr(k, 1) = " "
        k += 1
      end
      prefix = text~left(r)~strip
      if prefix = "" & k <= text~length & text~substr(k, 1) = "=" then name ||= "="
      useKind = "DYNAMIC_MESSAGE"
      targetClass = ""
      targetScope = "UNKNOWN"
      detail = "receiver=" || receiver
      suffix = text~substr(j)~strip
      if suffix~upper~left(6) = ":SUPER" then do
        useKind = "SUPER_MESSAGE"
        targetScope = currentScope
      end
      else if name~upper = "NEW" & receiver~left(1) = "." then do
        name = "init"
        useKind = "CONSTRUCTOR"
        targetClass = receiver~substr(2)
        targetScope = "INSTANCE"
        detail = "class literal " || receiver || "~new -> instance init"
      end
      else if receiver~upper = "SELF" then do
        useKind = "SELF_MESSAGE"
        targetClass = currentClass
        targetScope = currentScope
      end
      else if receiver~left(1) = "." then do
        useKind = "LITERAL_CLASS_MESSAGE"
        targetClass = receiver~substr(2)
        targetScope = "CLASS"
      end
      snap~addUse(.SourceUse~new(name, path, lineNo, consumer, useKind, targetClass, detail, targetScope, currentScope))
    end
    posn = p + 1
  end


::class ContractComparator public

::method compare
  use arg oldSnap, newSnap
  deltas = .array~new

  if oldSnap~lineage~upper <> newSnap~lineage~upper then deltas~append(.SourceContractDelta~new("SOURCE_LINEAGE_CHANGED", "HIGH", newSnap~component, oldSnap~lineage, newSnap~lineage, "source levels from different lineages are not AT_LEAST comparable"))

  /* Package compilation/runtime directives are semantic surfaces in ooRexx.
     They are compared independently of methods because changes such as
     ::options digits or ::requires can alter every method in a package while
     leaving all method source bodies untouched. */
  oldPackages = .table~new; newPackages = .table~new
  do p over oldSnap~packages; oldPackages[p~qualifiedName~upper] = p; end
  do p over newSnap~packages; newPackages[p~qualifiedName~upper] = p; end
  do oldP over oldSnap~packages
    newP = newPackages[oldP~qualifiedName~upper]
    if newP == .nil then do
      deltas~append(.SourceContractDelta~new("PACKAGE_REMOVED", "HIGH", oldP~qualifiedName, oldP~contractHash, "", "ooRexx package semantic container removed"))
      iterate
    end
    if oldP~optionsContract <> newP~optionsContract then deltas~append(.SourceContractDelta~new("PACKAGE_OPTIONS_CHANGED", "HIGH", oldP~qualifiedName, oldP~optionsContract, newP~optionsContract, "::options compilation/runtime semantics changed"))

    oldReq = .SSCUtil~split(oldP~requiresContract, " || ")
    newReq = .SSCUtil~split(newP~requiresContract, " || ")
    do requirement over oldReq
      if requirement = "" then iterate
      if \.SSCUtil~arrayContainsCI(newReq, requirement) then deltas~append(.SourceContractDelta~new("SOURCE_REQUIREMENT_REMOVED", "MAY_BREAK", oldP~qualifiedName, requirement, "", "::requires removed: " || requirement))
    end
    do requirement over newReq
      if requirement = "" then iterate
      if \.SSCUtil~arrayContainsCI(oldReq, requirement) then deltas~append(.SourceContractDelta~new("SOURCE_REQUIREMENT_ADDED", "VERIFY", newP~qualifiedName, "", requirement, "::requires added: " || requirement))
    end
  end
  do newP over newSnap~packages
    if oldPackages[newP~qualifiedName~upper] == .nil then deltas~append(.SourceContractDelta~new("PACKAGE_ADDED", "LOW", newP~qualifiedName, "", newP~contractHash, "new ooRexx package semantic container"))
  end

  oldClasses = .table~new; newClasses = .table~new
  do c over oldSnap~classes; oldClasses[c~qualifiedName~upper] = c; end
  do c over newSnap~classes; newClasses[c~qualifiedName~upper] = c; end
  do oc over oldSnap~classes
    nc = newClasses[oc~qualifiedName~upper]
    if nc == .nil then deltas~append(.SourceContractDelta~new("CLASS_REMOVED", "HIGH", oc~qualifiedName, oc~directiveContract, "", "class surface removed"))
    else if oc~contractHash <> nc~contractHash then deltas~append(.SourceContractDelta~new("CLASS_CONTRACT_CHANGED", "MAY_BREAK", oc~qualifiedName, oc~directiveContract, nc~directiveContract, "class visibility/inheritance directive changed"))
  end
  do nc over newSnap~classes
    if oldClasses[nc~qualifiedName~upper] == .nil then deltas~append(.SourceContractDelta~new("CLASS_ADDED", "LOW", nc~qualifiedName, "", nc~directiveContract, "new class surface"))
  end

  oldAttrs = .table~new; newAttrs = .table~new
  do a over oldSnap~attributes; oldAttrs[a~identityKey~upper] = a; end
  do a over newSnap~attributes; newAttrs[a~identityKey~upper] = a; end
  do oa over oldSnap~attributes
    na = newAttrs[oa~identityKey~upper]
    if na == .nil then deltas~append(.SourceContractDelta~new("ATTRIBUTE_REMOVED", "HIGH", oa~identityKey, oa~directiveContract, "", oa~scope || " attribute surface removed"))
    else if oa~contractHash <> na~contractHash then do
      kind = "ATTRIBUTE_CONTRACT_CHANGED"
      risk = "MAY_BREAK"
      if oa~accessMode <> na~accessMode then do
        oldGet = oa~accessMode = "GET" | oa~accessMode = "BOTH"
        oldSet = oa~accessMode = "SET" | oa~accessMode = "BOTH"
        newGet = na~accessMode = "GET" | na~accessMode = "BOTH"
        newSet = na~accessMode = "SET" | na~accessMode = "BOTH"
        removed = (oldGet & \newGet) | (oldSet & \newSet)
        if removed then kind = "ATTRIBUTE_ACCESS_CHANGED"
        else do
          kind = "ATTRIBUTE_ACCESS_EXPANDED"
          risk = "LOW"
        end
      end
      deltas~append(.SourceContractDelta~new(kind, risk, oa~identityKey, oa~accessMode || " " || oa~directiveContract, na~accessMode || " " || na~directiveContract, oa~scope || " attribute accessor contract changed"))
    end
    if oa~getterContract <> "" & na~getterContract <> "" & oa~getterBodyHash <> na~getterBodyHash then deltas~append(.SourceContractDelta~new("ATTRIBUTE_GETTER_IMPLEMENTATION_CHANGED", "VERIFY", oa~identityKey, oa~getterBodyHash~left(12), na~getterBodyHash~left(12), "attribute getter implementation changed; accessor contract retained"))
    if oa~setterContract <> "" & na~setterContract <> "" & oa~setterBodyHash <> na~setterBodyHash then deltas~append(.SourceContractDelta~new("ATTRIBUTE_SETTER_IMPLEMENTATION_CHANGED", "VERIFY", oa~identityKey, oa~setterBodyHash~left(12), na~setterBodyHash~left(12), "attribute setter implementation changed; accessor contract retained"))
  end
  do na over newSnap~attributes
    if oldAttrs[na~identityKey~upper] == .nil then deltas~append(.SourceContractDelta~new("ATTRIBUTE_ADDED", "LOW", na~identityKey, "", na~accessMode, "new " || na~scope || " attribute surface"))
  end

  oldConstants = .table~new; newConstants = .table~new
  do n over oldSnap~constants; oldConstants[n~identityKey~upper] = n; end
  do n over newSnap~constants; newConstants[n~identityKey~upper] = n; end
  do ocn over oldSnap~constants
    ncn = newConstants[ocn~identityKey~upper]
    if ncn == .nil then deltas~append(.SourceContractDelta~new("CONSTANT_REMOVED", "HIGH", ocn~identityKey, ocn~valueContract, "", "constant source/API surface removed"))
    else if ocn~valueHash <> ncn~valueHash then do
      risk = "VERIFY"
      uname = ocn~constantName~upper
      if pos("API", uname) > 0 | pos("PROTOCOL", uname) > 0 | pos("RELEASE", uname) > 0 | pos("VERSION", uname) > 0 | pos("SCHEMA", uname) > 0 | pos("FORMAT", uname) > 0 | pos("MAGIC", uname) > 0 then risk = "HIGH"
      deltas~append(.SourceContractDelta~new("CONSTANT_VALUE_CHANGED", risk, ocn~identityKey, ocn~valueContract, ncn~valueContract, "constant value changed; dependent behaviour requires verification"))
    end
  end
  do ncn over newSnap~constants
    if oldConstants[ncn~identityKey~upper] == .nil then deltas~append(.SourceContractDelta~new("CONSTANT_ADDED", "LOW", ncn~identityKey, "", ncn~valueContract, "new constant surface"))
  end

  oldByName = .table~new
  newByName = .table~new
  do m over oldSnap~methods; oldByName[m~identityKey~upper] = m; end
  do m over newSnap~methods; newByName[m~identityKey~upper] = m; end

  /* Method side is part of identity.  An instance message and a class message
     with the same spelling are two different OO surfaces. */
  do oldM over oldSnap~methods
    newM = newByName[oldM~identityKey~upper]
    if newM == .nil then do
      renamed = .nil
      do candidate over newSnap~methods
        if candidate~className~upper = oldM~className~upper & candidate~scope = oldM~scope & candidate~bodyHash = oldM~bodyHash & candidate~contractHash = oldM~contractHash then do
          renamed = candidate
          leave
        end
      end
      if renamed <> .nil then deltas~append(.SourceContractDelta~new("METHOD_RENAMED", "MAY_BREAK", oldM~identityKey, oldM~methodName, renamed~methodName, "stable semantic body/contract and method side suggest rename"))
      else deltas~append(.SourceContractDelta~new("METHOD_REMOVED", "HIGH", oldM~identityKey, oldM~methodName, "", oldM~scope || " message surface removed"))
      iterate
    end
    if oldM~contractHash <> newM~contractHash then deltas~append(.SourceContractDelta~new("METHOD_CONTRACT_CHANGED", "MAY_BREAK", oldM~identityKey, oldM~argSpec, newM~argSpec, oldM~scope || " visibility/argument contract changed"))
    else if oldM~bodyHash <> newM~bodyHash then deltas~append(.SourceContractDelta~new("METHOD_IMPLEMENTATION_CHANGED", "VERIFY", oldM~identityKey, oldM~bodyHash~left(12), newM~bodyHash~left(12), oldM~scope || " implementation changed; public contract unchanged"))
  end

  do newM over newSnap~methods
    if oldByName[newM~identityKey~upper] == .nil then do
      renamed = .false
      do oldM over oldSnap~methods
        if oldM~className~upper = newM~className~upper & oldM~scope = newM~scope & oldM~bodyHash = newM~bodyHash & oldM~contractHash = newM~contractHash then renamed = .true
      end
      if \renamed then deltas~append(.SourceContractDelta~new("METHOD_ADDED", "LOW", newM~identityKey, "", newM~methodName, "new " || newM~scope || " callable surface"))
    end
  end

  /* Independently tracked external operations. */
  do oldE over oldSnap~externalOperations
    newE = newSnap~externalById(oldE~externalId)
    if newE == .nil then do
      deltas~append(.SourceContractDelta~new("EXTERNAL_OPERATION_NOT_LOCATED", "MAY_BREAK", oldE~externalId, oldE~semanticContract, "", oldE~methodKey))
      iterate
    end
    if oldE~semanticContract <> newE~semanticContract | oldE~statementHash <> newE~statementHash then do
      if oldE~kind = "SQL" & newE~kind = "SQL" then do
        sqlDeltas = .SQLSemantic~delta(oldE~semanticContract, newE~semanticContract)
        if sqlDeltas~items = 0 then deltas~append(.SourceContractDelta~new("EXTERNAL_SQL_TEXT_CHANGED", "VERIFY", oldE~externalId, oldE~statementHash, newE~statementHash, oldE~methodKey))
        else do sd over sqlDeltas
          risk = "MAY_BREAK"
          if sd~left(21) = "SQL_OPERATION_CHANGED " | sd~left(27) = "SQL_PREDICATE_SCOPE_CHANGED " then risk = "HIGH"
          deltas~append(.SourceContractDelta~new(word(sd, 1), risk, oldE~externalId, oldE~semanticContract, newE~semanticContract, oldE~methodKey || ": " || subword(sd, 2)))
        end
      end
      else deltas~append(.SourceContractDelta~new("EXTERNAL_OPERATION_CHANGED", "MAY_BREAK", oldE~externalId, oldE~semanticContract, newE~semanticContract, oldE~methodKey || " tracked " || oldE~kind || " changed"))
    end
  end
  return deltas


::class ImpactEngine public

::method assess
  use arg providerOld, providerNew, workSnap, deltas
  findings = .array~new
  component = providerNew~component
  sourceLevel = providerNew~sourceLevel

  /* First: explicit AT_LEAST requirements.  Passing the minimum does not mean
     compatible; it merely means the known minimum is satisfied.  Contract
     deltas below can still yield MAY_BREAK. */
  do req over workSnap~requirements
    if self~targetIsForComponent(req~target, component) then do
      if datatype(req~minimumLevel, "W") then do
        if datatype(sourceLevel, "W") then do
          if sourceLevel < req~minimumLevel then findings~append(.ImpactFinding~new("REQUIREMENT_UNSATISFIED", component, "SOURCE_LEVEL_TOO_LOW", req~consumer, req~path, req~line, "requires " || req~target || " AT_LEAST " || req~minimumLevel || ", incoming source level is " || sourceLevel, "DECLARED"))
        end
        else findings~append(.ImpactFinding~new("VERIFICATION_REQUIRED", component, "SOURCE_LEVEL_UNKNOWN", req~consumer, req~path, req~line, "requires " || req~target || " AT_LEAST " || req~minimumLevel || ", but incoming archive has no authoritative sourceLevel", "DECLARED"))
      end
    end
  end

  do d over deltas
    if d~kind = "METHOD_ADDED" | d~kind = "ATTRIBUTE_ADDED" | d~kind = "CONSTANT_ADDED" then iterate

    providerEntity = d~entity
    changedMethod = ""
    changedClass = ""
    changedScope = "INSTANCE"
    if d~kind~left(7) = "METHOD_" then do
      changedMethod = self~entityMethodName(d~entity)
      changedClass = self~entityClassName(d~entity)
      changedScope = self~entityMethodScope(d~entity)
    end
    changedAttribute = .nil
    newAttribute = .nil
    if d~kind~left(10) = "ATTRIBUTE_" then do
      changedAttribute = providerOld~attributeByIdentityKey(d~entity)
      newAttribute = providerNew~attributeByIdentityKey(d~entity)
      a = changedAttribute
      if a == .nil then a = newAttribute
      if a <> .nil then do
        providerEntity = a~identityKey
        changedClass = a~className
        changedScope = a~scope
      end
    end
    if d~kind~left(9) = "CONSTANT_" then do
      c = providerOld~constantByIdentityKey(d~entity)
      if c == .nil then c = providerNew~constantByIdentityKey(d~entity)
      if c <> .nil then do
        providerEntity = c~identityKey
        changedMethod = c~constantName
        changedClass = c~className
        changedScope = "CLASS"
      end
    end

    external = .nil
    newExternal = .nil
    if d~kind~left(4) = "SQL_" | d~kind~left(9) = "EXTERNAL_" then do
      external = providerOld~externalById(d~entity)
      newExternal = providerNew~externalById(d~entity)
      if external <> .nil then do
        providerEntity = external~methodKey
        changedMethod = self~entityMethodName(external~methodKey)
        changedClass = self~entityClassName(external~methodKey)
        changedScope = self~entityMethodScope(external~methodKey)
      end
    end

    /* Declared requirements have authority over heuristic message-use evidence. */
    do req over workSnap~requirements
      if self~requirementIntersectsEntity(req~target, component, providerEntity) then do
        status = "MAY_BREAK"
        if d~kind = "METHOD_REMOVED" then status = "KNOWN_UNSATISFIED_SURFACE"
        else if d~risk = "HIGH" then status = "MAY_BREAK_HIGH"
        findings~append(.ImpactFinding~new(status, providerEntity, d~kind, req~consumer, req~path, req~line, d~detail, "DECLARED AT_LEAST " || req~minimumLevel))
      end
    end

    if changedAttribute <> .nil | newAttribute <> .nil then do
      a = changedAttribute
      if a == .nil then a = newAttribute
      getterAffected = .true
      setterAffected = .true
      if changedAttribute <> .nil & newAttribute <> .nil then do
        oldGet = changedAttribute~accessMode = "GET" | changedAttribute~accessMode = "BOTH"
        oldSet = changedAttribute~accessMode = "SET" | changedAttribute~accessMode = "BOTH"
        newGet = newAttribute~accessMode = "GET" | newAttribute~accessMode = "BOTH"
        newSet = newAttribute~accessMode = "SET" | newAttribute~accessMode = "BOTH"
        if d~kind = "ATTRIBUTE_ACCESS_CHANGED" then do
          getterAffected = oldGet & \newGet
          setterAffected = oldSet & \newSet
        end
        else if d~kind = "ATTRIBUTE_ACCESS_EXPANDED" then do
          getterAffected = .false
          setterAffected = .false
        end
        else if d~kind = "ATTRIBUTE_GETTER_IMPLEMENTATION_CHANGED" then do
          getterAffected = .true
          setterAffected = .false
        end
        else if d~kind = "ATTRIBUTE_SETTER_IMPLEMENTATION_CHANGED" then do
          getterAffected = .false
          setterAffected = .true
        end
      end
      do use over workSnap~uses
        isGetter = use~message~upper = a~attributeName~upper
        isSetter = use~message~upper = (a~attributeName || "=")~upper
        if \((isGetter & getterAffected) | (isSetter & setterAffected)) then iterate
        matched = .false
        status = "MAY_BREAK"
        if d~risk = "VERIFY" then status = "VERIFICATION_REQUIRED"
        evidence = use~useKind
        select
          when use~useKind = "LITERAL_CLASS_MESSAGE" then matched = a~scope = "CLASS" & use~targetClass~upper = a~className~upper
          when use~useKind = "SELF_MESSAGE" then matched = use~targetClass~upper = a~className~upper & (use~targetScope = a~scope | use~targetScope = "UNKNOWN")
          when use~useKind = "SUPER_MESSAGE" then matched = .false
          otherwise do
            matched = .true
            status = "VERIFICATION_REQUIRED"
            evidence = "DYNAMIC_ATTRIBUTE_MESSAGE"
          end
        end
        if matched then findings~append(.ImpactFinding~new(status, a~identityKey, d~kind, use~consumer, use~path, use~line, d~detail || "; " || use~detail, evidence))
      end
    end

    if changedMethod <> "" then do use over workSnap~uses
      if use~message~upper <> changedMethod~upper then iterate
      matched = .false
      status = "MAY_BREAK"
      if d~risk = "VERIFY" then status = "VERIFICATION_REQUIRED"
      evidence = use~useKind
      select
        when use~useKind = "CONSTRUCTOR" then matched = changedScope = "INSTANCE" & use~targetClass~upper = changedClass~upper
        when use~useKind = "LITERAL_CLASS_MESSAGE" then matched = changedScope = "CLASS" & use~targetClass~upper = changedClass~upper
        when use~useKind = "SELF_MESSAGE" then matched = use~targetClass~upper = changedClass~upper & (use~targetScope = changedScope | use~targetScope = "UNKNOWN")
        when use~useKind = "SUPER_MESSAGE" then matched = .false
        otherwise do
          /* The receiver type is not statically known.  Preserve this as
             useful but deliberately lower-confidence evidence rather than
             claiming that every same-named message targets this provider. */
          matched = .true
          status = "VERIFICATION_REQUIRED"
          evidence = "DYNAMIC_MESSAGE_NAME"
        end
      end
      if matched then do
        if d~risk = "HIGH" & status <> "VERIFICATION_REQUIRED" then status = "MAY_BREAK_HIGH"
        findings~append(.ImpactFinding~new(status, providerEntity, d~kind, use~consumer, use~path, use~line, d~detail || "; " || use~detail, evidence))
      end
    end

    if external <> .nil then self~assessExternalDataImpact(external, newExternal, d, workSnap, findings)
  end
  return findings

::method assessExternalDataImpact private
  use arg external, newExternal, delta, workSnap, findings
  methodKey = external~methodKey
  oldSource = .SQLSemantic~field(external~semanticContract, "sources")
  source = oldSource
  op = external~operation
  if newExternal <> .nil then do
    newSource = .SQLSemantic~field(newExternal~semanticContract, "sources")
    if newSource <> "" & pos(newSource~upper, source~upper) = 0 then source = source || " " || newSource
    op = newExternal~operation
  end

  if delta~kind = "SQL_PROJECTION_OR_ORDER_CHANGED" | delta~kind = "SQL_RESULT_SHAPE_CHANGED" then do dep over workSnap~dataDependencies
    if dep~mode = "RESULT_ORDINAL" & dep~target~upper = methodKey~upper then findings~append(.ImpactFinding~new("MAY_BREAK_HIGH", methodKey, delta~kind, dep~consumer, dep~path, dep~line, "positional SQL result consumer " || dep~detail || "; " || delta~detail, "DECLARED_RESULT_ORDINAL"))
  end

  mutating = op = "UPDATE" | op = "DELETE" | op = "INSERT"
  dataWide = delta~kind = "SQL_DATA_SOURCE_CHANGED" | delta~kind = "SQL_WRITE_COLUMNS_CHANGED" | delta~kind = "SQL_OPERATION_CHANGED" | (mutating & delta~kind = "SQL_PREDICATE_SCOPE_CHANGED")
  if dataWide then do dep over workSnap~dataDependencies
    if dep~mode = "RESULT_ORDINAL" then iterate
    if self~sourceIntersects(dep~target, source) then findings~append(.ImpactFinding~new("MAY_BREAK_HIGH", methodKey, delta~kind, dep~consumer, dep~path, dep~line, "tracked SQL changes data source " || source || "; downstream " || dep~mode || " dependency may observe changed data", "DECLARED_DATA_LINEAGE"))
  end

::method sourceIntersects private
  use arg wanted, sourceText
  w = wanted~upper~strip
  s = sourceText~upper
  if w = "" | s = "" then return .false
  return pos(w, s) > 0

::method targetIsForComponent private
  use arg target, component
  t = target~upper; c = component~upper
  return t = c | t~left(c~length + 1) = c || "."

::method requirementIntersectsEntity private
  use arg target, component, providerEntity
  if \self~targetIsForComponent(target, component) then return .false
  t = target~upper; p = providerEntity~upper; c = component~upper
  if t = c | p = c then return .true
  if t = p then return .true
  if t~left(p~length + 1) = p || "." then return .true
  if p~left(t~length + 1) = t || "." then return .true
  return .false

::method entityMethodName private
  use arg entity
  base = self~entityBase(entity)
  p = base~lastPos(".")
  if p = 0 then return ""
  return base~substr(p + 1)

::method entityClassName private
  use arg entity
  base = self~entityBase(entity)
  last = base~lastPos(".")
  if last <= 1 then return ""
  prefix = base~left(last - 1)
  prev = prefix~lastPos(".")
  if prev = 0 then return prefix
  return prefix~substr(prev + 1)

::method entityMethodScope private
  use arg entity
  hash = entity~lastPos("#")
  if hash = 0 then return "INSTANCE"
  scope = entity~substr(hash + 1)~upper
  if scope = "CLASS" | scope = "OBJECT" | scope = "INSTANCE" then return scope
  return "INSTANCE"

::method entityBase private
  use arg entity
  hash = entity~lastPos("#")
  if hash = 0 then return entity
  scope = entity~substr(hash + 1)~upper
  if scope = "CLASS" | scope = "OBJECT" | scope = "INSTANCE" then return entity~left(hash - 1)
  return entity


::class RollupIntake public

::method unpack
  use arg archive, stagingRoot
  .SSCUtil~ensureDir(stagingRoot)
  top = stagingRoot || "/root"
  .SSCUtil~ensureDir(top)
  .SSCUtil~writeLines(top || "/.OSC_ARCHIVE_ORIGIN", .array~of(.SSCUtil~basename(archive)))
  address system 'unzip -qq -o ' || .SSCUtil~shellQuote(archive) || ' -d ' || .SSCUtil~shellQuote(top)
  if rc <> 0 then raise syntax 88.900 array("cannot unpack roll-up archive", archive)

  seen = .set~new
  counter = 0
  do forever
    call SysFileTree stagingRoot || "/*.zip", "zips.", "FOS"
    changed = .false
    do i = 1 to zips.0
      z = zips.i
      if seen~hasIndex(z) then iterate
      seen~put(z)
      counter += 1
      dest = stagingRoot || "/nested/" || counter || "_" || .SSCUtil~stemWithoutVersion(z)
      .SSCUtil~ensureDir(dest)
      .SSCUtil~writeLines(dest || "/.OSC_ARCHIVE_ORIGIN", .array~of(.SSCUtil~basename(z)))
      address system 'unzip -qq -o ' || .SSCUtil~shellQuote(z) || ' -d ' || .SSCUtil~shellQuote(dest)
      if rc = 0 then changed = .true
    end
    if \changed then leave
  end
  return stagingRoot

::method discoverPackages
  use arg stagingRoot
  packages = .array~new
  root = stagingRoot || "/root"

  /*
   * A direct component does not stop being a component merely because its
   * release also carries nested ZIP dependencies.  If the outer archive has
   * an authoritative manifest, assess that root component as well as every
   * extracted nested package.  A manifest-less outer roll-up remains only a
   * carrier when nested packages exist.
   */
  call SysFileTree root || "/SSC_MANIFEST", "rootManifest.", "FOS"
  if rootManifest.0 > 0 then packages~append(root)

  /* Every extracted nested archive directory is a package candidate. */
  call SysFileTree stagingRoot || "/nested/*", "dirs.", "DO"
  do i = 1 to dirs.0
    packages~append(dirs.i)
  end

  /* Also allow a direct, non-nested legacy package archive. */
  if packages~items = 0 then packages~append(root)
  return packages

::method metadata
  use arg packageDir
  meta = .directory~new
  meta["component"] = ""
  meta["lineage"] = "MAIN"
  meta["sourceLevel"] = "UNKNOWN"
  call SysFileTree packageDir || "/SSC_MANIFEST", "m.", "FOS"
  if m.0 = 0 then do
    origin = .SSCUtil~readLines(packageDir || "/.OSC_ARCHIVE_ORIGIN")
    if origin~items > 0 then meta["component"] = .SSCUtil~stemWithoutVersion(origin[1])
    return meta
  end
  lines = .SSCUtil~readLines(m.1)
  do row over lines
    p = pos("=", row)
    if p = 0 then iterate
    key = row~left(p - 1)~strip
    value = row~substr(p + 1)~strip
    if meta~hasIndex(key) then meta[key] = value
  end
  return meta

::requires "src/crypto.cls"
