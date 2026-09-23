/* Governed package staging.  The caller names an ability, never a shell
 * command.  A stage is an immutable content-addressed generation with a
 * durable receipt; failed generations are retained for inspection. */

::class LlmPaPackageStageRunner public
::attribute commands get

::method init
  expose commands
  commands = .array~new

::method run
  expose commands
  use arg commandArg, cwdArg = ""
  command = commandArg~string
  cwd = cwdArg~string
  commands~append(command || " @cwd=" || cwd)
  out = .array~new
  err = .array~new
  activation = .Method~new("", .array~of( -
    "out = self~stdout", -
    "err = self~stderr", -
    "address system self~commandText with output using (out) error using (err)", -
    "return rc"))
  activationObject = .LlmPaPackageStageActivation~new(command, cwd, out, err)
  previousDirectory = directory()
  if cwd \= "" then call directory cwd
  rc = activationObject~invoke(activation)
  if cwd \= "" then call directory previousDirectory
  d = .directory~new
  d["rc"] = rc
  d["stdout"] = out
  d["stderr"] = err
  return .LlmPaResult~success(d)

::class LlmPaPackageStageActivation public
::attribute commandText get
::attribute cwd get
::attribute stdout get
::attribute stderr get

::method init
  expose commandText cwd stdout stderr
  use arg commandArg, cwdArg, stdoutArg, stderrArg
  commandText = commandArg~string
  cwd = cwdArg~string
  stdout = stdoutArg
  stderr = stderrArg

::method invoke
  use arg methodObject
  return self~run:super(methodObject)

::class LlmPaPackageStage public
::attribute stageRoot get
::attribute runner get

::method init
  expose stageRoot runner minimumFreeBytes minimumFreeInodes
  use arg rootArg = "", runnerArg = .nil, freeBytesArg = 1048576, freeInodesArg = 128
  stageRoot = rootArg~string~strip
  if stageRoot = "" then stageRoot = "/tmp/llmpa-staging"
  if stageRoot~left(1) \= "/" | stageRoot~pos("..") > 0 | stageRoot~pos("'") > 0 then raise syntax 88.900 array("package staging root must be an approved absolute path")
  runner = runnerArg
  if runner == .nil then runner = .LlmPaPackageStageRunner~new
  minimumFreeBytes = freeBytesArg
  minimumFreeInodes = freeInodesArg

::method stage
  expose stageRoot runner minimumFreeBytes minimumFreeInodes
  use arg zipArg
  zipPath = self~absolutePath(zipArg)
  if zipPath = "" then return self~failure("PACKAGE_NOT_FOUND", "ZIP path is empty")
  if zipPath~pos("'") > 0 | zipPath~pos("..") > 0 then return self~failure("PACKAGE_PATH_INVALID", zipPath)
  safe = self~run("test -f " || self~quote(zipPath))
  if \safe~ok | safe~value["rc"] \= 0 then return self~failure("PACKAGE_NOT_FOUND", zipPath)
  ignore = self~run("mkdir -p " || self~quote(stageRoot))
  ignore = self~run("mkdir -p " || self~quote(stageRoot || "/receipts"))
  digest = self~digest(zipPath)
  if digest = "" then return self~failure("PACKAGE_DIGEST_FAILED", zipPath)
  packageName = self~baseName(zipPath)
  generation = stageRoot || "/" || packageName~changestr(".zip", "") || "-" || digest~left(16)
  receipt = stageRoot || "/receipts/" || digest || ".json"
  existing = self~readReceipt(receipt)
  if existing \== .nil then return .LlmPaResult~success(existing)
  preflight = self~preflight(zipPath, stageRoot)
  if \preflight~ok then return self~recordFailure(receipt, digest, zipPath, "PREFLIGHT_FAILED", preflight~detail)
  names = self~archiveNames(zipPath)
  if \names~ok then return self~recordFailure(receipt, digest, zipPath, "ARCHIVE_READ_FAILED", names~detail)
  archiveEntries = names~value["stdout"]
  unsafe = self~unsafeName(archiveEntries)
  if unsafe \= "" then return self~recordFailure(receipt, digest, zipPath, "UNSAFE_ARCHIVE", unsafe)
  types = self~archiveTypes(zipPath)
  if \types~ok then return self~recordFailure(receipt, digest, zipPath, "ARCHIVE_TYPE_READ_FAILED", types~detail)
  unsafeType = self~unsafeType(types~value["stdout"])
  if unsafeType \= "" then return self~recordFailure(receipt, digest, zipPath, "UNSAFE_ARCHIVE_TYPE", unsafeType)
  metadata = self~metadata(archiveEntries)
  if metadata["manifest"] = .false then return self~recordFailure(receipt, digest, zipPath, "MANIFEST_MISSING", "MANIFEST.sha256 is required")
  made = self~run("mkdir " || self~quote(generation))
  if \made~ok | made~value["rc"] \= 0 then return self~recordFailure(receipt, digest, zipPath, "GENERATION_CREATE_FAILED", generation)
  extracted = self~run("unzip -q -n " || self~quote(zipPath) || " -d " || self~quote(generation))
  if \extracted~ok | extracted~value["rc"] \= 0 then return self~recordFailure(receipt, digest, zipPath, "EXTRACTION_FAILED", generation)
  verified = self~verifyManifest(generation)
  if \verified~ok then return self~recordFailure(receipt, digest, zipPath, "MANIFEST_MISMATCH", verified~detail)
  qualified = self~qualify(generation, metadata)
  if \qualified~ok then return self~recordFailure(receipt, digest, zipPath, "QUALIFICATION_FAILED", qualified~detail)
  d = self~receiptData(digest, zipPath, generation, "STAGED_READY")
  d["metadata"] = metadata
  d["preflight"] = preflight~value
  d["qualification"] = qualified~value
  return self~writeReceipt(receipt, d)

::method preflight private
  expose runner minimumFreeBytes minimumFreeInodes
  use arg zipPath, target
  sizeOut = self~run("stat -c %s " || self~quote(zipPath))
  spaceOut = self~run("df -Pk " || self~quote(target))
  inodeOut = self~run("df -Pi " || self~quote(target))
  expansionOut = self~run("unzip -Z -l " || self~quote(zipPath))
  if \sizeOut~ok | \spaceOut~ok | \inodeOut~ok | \expansionOut~ok then return .LlmPaResult~failure("PREFLIGHT_COMMAND_FAILED")
  bytes = self~firstNumber(sizeOut~value["stdout"][1])
  uncompressed = self~uncompressedBytes(expansionOut~value["stdout"])
  if uncompressed < 0 then return .LlmPaResult~failure("ARCHIVE_SIZE_UNKNOWN", "ZIP uncompressed size could not be determined")
  available = self~dfAvailable(spaceOut~value["stdout"])
  inodes = self~dfAvailable(inodeOut~value["stdout"])
  requiredBytes = bytes + uncompressed + minimumFreeBytes
  if available < requiredBytes then return .LlmPaResult~failure("INSUFFICIENT_SPACE", available)
  if inodes < minimumFreeInodes then return .LlmPaResult~failure("INSUFFICIENT_INODES", inodes)
  d = .directory~new
  d["archive_bytes"] = bytes
  d["declared_uncompressed_bytes"] = uncompressed
  d["required_bytes"] = requiredBytes
  d["available_bytes"] = available
  d["available_inodes"] = inodes
  d["minimum_free_bytes"] = minimumFreeBytes
  d["minimum_free_inodes"] = minimumFreeInodes
  return .LlmPaResult~success(d)

::method archiveNames private
  use arg zipPath
  return self~run("unzip -Z1 " || self~quote(zipPath))

::method archiveTypes private
  use arg zipPath
  return self~run("unzip -Z -v " || self~quote(zipPath))

::method unsafeType private
  use arg lines
  do line over lines
    text = line~lower
    if text~pos("symbolic link") > 0 | text~pos("fifo") > 0 | text~pos("character device") > 0 | text~pos("block device") > 0 | text~pos("socket") > 0 then return line
  end
  return ""

::method uncompressedBytes private
  use arg lines
  do line over lines
    if line~pos("bytes uncompressed") > 0 then return word(line, 3) + 0
  end
  return -1

::method unsafeName private
  use arg names
  do name over names
    text = name~string
    if text~left(1) = "/" | text~pos("../") > 0 | text~pos("..\\") > 0 | text~pos("\") > 0 then return text
    if text~length > 1 & text~left(2) = "//" then return text
  end
  return ""

::method metadata private
  use arg names
  d = .directory~new
  d["manifest"] = .false
  d["integration"] = .false
  d["version"] = .false
  do name over names
    leaf = name~string~changestr("\", "/")
    if leaf~left(2) = "./" then leaf = leaf~substr(3)
    if leaf = "MANIFEST.sha256" then d["manifest"] = .true
    if leaf = "integration.json" then d["integration"] = .true
    if leaf = "VERSION.txt" then d["version"] = .true
  end
  d["dependency_check"] = "DECLARED_PENDING_RUNTIME_CHECK"
  return d

::method verifyManifest private
  use arg generation
  manifest = generation || "/MANIFEST.sha256"
  check = self~run("sha256sum -c " || self~quote(manifest), generation)
  if \check~ok | check~value["rc"] \= 0 then return .LlmPaResult~failure("MANIFEST_MISMATCH", self~join(check~value["stderr"]))
  return .LlmPaResult~success(.true)

::method qualify private
  use arg generation, metadata
  if metadata["integration"] then do
    integration = self~readText(generation || "/integration.json")
    if integration = "" then return .LlmPaResult~failure("INTEGRATION_INVALID", "integration.json is empty")
    parseAttempt = .JSON~fromJSON(integration)
    if \parseAttempt~isa(.Directory) then return .LlmPaResult~failure("INTEGRATION_INVALID", "integration.json is not a JSON object")
    dependencies = self~dependencyClosure(parseAttempt)
    if \dependencies~ok then return dependencies
  end
  d = .directory~new
  d["status"] = "QUALIFIED_DECLARED_STRUCTURE"
  d["manifest_present"] = metadata["manifest"]
  d["integration_present"] = metadata["integration"]
  d["version_present"] = metadata["version"]
  d["dependency_check"] = "RUNTIME_PATH_AND_EXTERNAL_DECLARATIONS"
  if metadata["integration"] then d["dependencies"] = dependencies~value
  return .LlmPaResult~success(d)

::method dependencyClosure private
  use arg integration
  if \integration~hasIndex("dependencies") then return .LlmPaResult~failure("DEPENDENCIES_MISSING", "integration.json has no dependencies array")
  declared = integration["dependencies"]
  if \declared~isa(.Array) then return .LlmPaResult~failure("DEPENDENCIES_INVALID", "dependencies must be an array")
  roots = value("REXX_PATH", , "ENVIRONMENT")
  checked = .array~new
  missing = .array~new
  external = .array~new
  do dependency over declared
    if \dependency~isa(.Directory) then return .LlmPaResult~failure("DEPENDENCY_ENTRY_INVALID")
    name = dependency["name"]~string~lower~strip
    required = .true
    if dependency~hasIndex("required") then required = dependency["required"]
    if name = "rxsock" | name = "ollama" then do
      external~append(name)
      iterate
    end
    found = self~pathContains(roots, name)
    row = .directory~new
    row["name"] = name
    row["declared_version"] = self~field(dependency, "version")
    row["required"] = required
    row["available"] = found
    checked~append(row)
    if required & \found then missing~append(name)
  end
  if missing~items > 0 then return .LlmPaResult~failure("DEPENDENCY_MISSING", self~join(missing))
  d = .directory~new
  d["checked"] = checked
  d["external_unprobed"] = external
  return .LlmPaResult~success(d)

::method pathContains private
  use arg roots, name
  probe = name~changestr("oorexx_", "")~changestr("_", "")
  parse var roots root ":" remainder
  do while root \= ""
    if root~lower~pos(name) > 0 | root~lower~pos(probe) > 0 then return .true
    parse var remainder root ":" remainder
  end
  return .false

::method field private
  use arg d, key
  if d~hasIndex(key) then return d[key]
  return ""

::method run private
  expose runner
  use arg command, cwd = ""
  return runner~run(command, cwd)

::method digest private
  use arg path
  checked = self~run("sha256sum " || self~quote(path))
  if \checked~ok | checked~value["rc"] \= 0 then return ""
  return word(checked~value["stdout"][1], 1)

::method writeReceipt private
  use arg path, d
  temporary = path || ".tmp-" || random(100000,999999)
  call lineout temporary, .JSON~toJSON(d)
  call lineout temporary
  ignore = stream(temporary, "C", "CLOSE")
  if stream(path, "C", "QUERY EXISTS") \= "" then call SysFileDelete path
  call SysFileMove temporary, path
  return .LlmPaResult~success(d)

::method readText private
  use arg path
  text = ""
  line = linein(path)
  do while line \= ""
    if text \= "" then text = text || "0a"x
    text = text || line
    line = linein(path)
  end
  ignore = stream(path, "C", "CLOSE")
  return text

::method recordFailure private
  use arg path, digest, zipPath, status, detail
  d = self~receiptData(digest, zipPath, "", status)
  d["detail"] = detail~string
  return self~writeReceipt(path, d)

::method receiptData private
  use arg digest, zipPath, generation, status
  d = .directory~new
  d["schema"] = "llm.pa.package.stage/0.1"
  d["stage_id"] = "stage-" || digest~left(16)
  d["package_sha256"] = digest
  d["package_path"] = zipPath
  d["generation"] = generation
  d["status"] = status
  d["created_at"] = .LlmPaUtil~timestamp
  d["filesystem_changed"] = (generation \= "")
  return d

::method readReceipt private
  use arg path
  if stream(path, "C", "QUERY EXISTS") = "" then return .nil
  line = linein(path)
  ignore = stream(path, "C", "CLOSE")
  if line = "" then return .nil
  parsed = .JSON~fromJSON(line)
  if parsed~isa(.Directory) then return parsed
  return .nil

::method absolutePath private
  use arg pathArg
  path = pathArg~string~strip
  if path = "" then return ""
  if path~left(1) = "/" then return path
  return directory() || "/" || path

::method baseName private
  use arg path
  parse var path . ("/" name)
  return name

::method quote private
  use arg text
  if text~pos("'") > 0 then return "''"
  return "'" || text || "'"

::method firstNumber private
  use arg line
  return word(line~string, 1) + 0

::method dfAvailable private
  use arg lines
  if lines~items < 2 then return 0
  return word(lines[2], 4) + 0

::method join private
  use arg lines
  text = ""
  do line over lines
    if text \= "" then text = text || " "
    text = text || line
  end
  return text

::method failure private
  use arg code, detail = ""
  return .LlmPaResult~failure(code, detail)

::requires "LlmPaCore.cls"
::requires "json.cls"
