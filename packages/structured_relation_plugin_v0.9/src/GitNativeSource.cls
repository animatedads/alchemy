/*
 * GitNativeSource v0.6
 *
 * Information-preserving local Git source adapter for ooRexx.
 * Git is used as the object database; its output is consumed through
 * explicit machine-oriented protocols and immediately reified as objects.
 * The authoritative representation is NOT `git log` text or a flattened diff.
 */

::class GitIdentity public
::attribute name get
::attribute email get
::attribute timestamp get
::attribute role get

::method init
  expose name email timestamp role
  use arg nameArg = "", emailArg = "", timestampArg = "", roleArg = ""
  name = nameArg~string
  email = emailArg~string
  timestamp = timestampArg~string
  role = roleArg~string~translate

::method provenance
  expose name email timestamp role
  p = .table~new
  p["kind"] = "GIT_IDENTITY"
  p["name"] = name
  p["email"] = email
  p["timestamp"] = timestamp
  p["role"] = role
  return p

::method string
  expose name email role
  return role || " " || name || " <" || email || ">"


::class GitCommandResult public
::attribute rc get
::attribute stdout get
::attribute stderr get
::attribute command get

::method init
  expose rc stdout stderr command
  use arg rcArg, stdoutArg = "", stderrArg = "", commandArg = ""
  rc = rcArg
  stdout = stdoutArg
  stderr = stderrArg
  command = commandArg

::method ok
  expose rc
  return rc = 0


::class GitShellRunner public
::attribute repositoryPath get
::attribute gitExecutable get

::method init
  expose repositoryPath gitExecutable counter
  use arg repositoryPathArg, gitExecutableArg = "git"
  repositoryPath = repositoryPathArg~string
  gitExecutable = gitExecutableArg~string
  counter = 0

::method git
  expose repositoryPath gitExecutable counter
  use arg argumentText
  counter += 1
  token = random(100000, 999999) || "_" || counter
  outPath = "/tmp/oorexx_git_" || token || ".out"
  errPath = "/tmp/oorexx_git_" || token || ".err"
  cmd = self~quote(gitExecutable) || " -C " || self~quote(repositoryPath) || " " || argumentText || -
        " > " || self~quote(outPath) || " 2> " || self~quote(errPath)
  address system cmd
  commandRc = rc
  out = self~readAll(outPath)
  err = self~readAll(errPath)
  address system "rm -f -- " || self~quote(outPath) || " " || self~quote(errPath)
  return .GitCommandResult~new(commandRc, out, err, cmd)

::method quote private
  use arg value
  text = value~string
  /* POSIX shell single-quote escaping: ' becomes '\'' */
  text = text~changestr("'", "'\''")
  return "'" || text || "'"

::method readAll private
  use arg path
  s = .stream~new(path)
  openStatus = s~open("READ")
  if \openStatus~caselessEquals("READY:") then return ""
  available = s~chars
  if available > 0 then data = s~charin(1, available)
  else data = ""
  s~close
  return data


::class GitRepositoryContext public
::attribute path get
::attribute slug get
::attribute remoteUrl get
::attribute history get
::attribute findings get

::method init
  expose path slug remoteUrl history findings runner commitCache
  use arg pathArg, slugArg = "", remoteUrlArg = "", gitExecutable = "git"
  path = pathArg~string
  slug = slugArg~string
  remoteUrl = remoteUrlArg~string
  history = .array~new
  findings = .array~new
  commitCache = .table~new
  runner = .GitShellRunner~new(path, gitExecutable)
  history~append(.RichProcessingEvent~new("SOURCE", "OPEN_GIT_REPOSITORY", path, self))

::method runner private
  expose runner
  return runner

::method headSha
  r = self~runner~git("rev-parse HEAD")
  self~requireOk(r, "GIT.HEAD")
  return r~stdout~changestr('0d'x, "")~changestr('0a'x, "")~strip

::method resolve
  use arg revision
  r = self~runner~git("rev-parse " || self~quoteRevision(revision))
  self~requireOk(r, "GIT.RESOLVE")
  return r~stdout~changestr('0d'x, "")~changestr('0a'x, "")~strip

::method commit
  expose commitCache history
  use arg revision = "HEAD"
  sha = self~resolve(revision)
  cached = commitCache[sha]
  if cached \== .nil then return cached

  fmt = "%H%x00%P%x00%an%x00%ae%x00%aI%x00%cn%x00%ce%x00%cI%x00%s%x00%b%x00%T%x00"
  r = self~runner~git("show -s --no-show-signature --format=" || self~q(fmt) || " " || self~q(sha))
  self~requireOk(r, "GIT.COMMIT")
  f = self~nulFields(r~stdout)
  if f~items < 11 then raise syntax 93.900 array("Malformed git commit record for " || sha)

  parents = .array~new
  parentText = f[2]~strip
  if parentText \= "" then do word over parentText
    parents~append(word)
  end
  author = .GitIdentity~new(f[3], f[4], f[5], "AUTHOR")
  committer = .GitIdentity~new(f[6], f[7], f[8], "COMMITTER")
  c = .GitCommitContext~new(self, f[1], parents, author, committer, f[9], f[10], f[11])
  commitCache[sha] = c
  history~append(.RichProcessingEvent~new("GIT", "LOAD_COMMIT", sha, c))
  return c

::method changedFiles
  use arg revision = "HEAD"
  c = self~commit(revision)
  r = self~runner~git("diff-tree --root --no-commit-id --name-status -r -z " || self~q(c~sha))
  self~requireOk(r, "GIT.CHANGED_FILES")
  fields = self~nulFields(r~stdout)
  changes = .array~new
  i = 1
  do while i <= fields~items
    status = fields[i]
    i += 1
    if status = "" then iterate
    code = status~left(1)
    if code = "R" | code = "C" then do
      if i + 1 > fields~items then leave
      oldPath = fields[i]
      newPath = fields[i + 1]
      i += 2
    end
    else do
      if i > fields~items then leave
      oldPath = ""
      newPath = fields[i]
      i += 1
      if code = "D" then do
        oldPath = newPath
        newPath = ""
      end
      else if code \= "A" then oldPath = newPath
    end
    ch = .GitChangeRef~new(self, c, status, oldPath, newPath)
    changes~append(ch)
    c~addChange(ch)
  end
  return changes

::method fileRevision
  use arg revision, sourcePath
  c = self~commit(revision)
  spec = c~sha || ":" || sourcePath~string
  blobResult = self~runner~git("rev-parse " || self~q(spec))
  self~requireOk(blobResult, "GIT.BLOB_ID")
  blobSha = blobResult~stdout~changestr('0d'x, "")~changestr('0a'x, "")~strip
  contentResult = self~runner~git("show " || self~q(spec))
  self~requireOk(contentResult, "GIT.BLOB_READ")
  return .GitFileRevision~new(self, c, sourcePath, blobSha, contentResult~stdout)

::method hydrateChange
  use arg change
  c = change~commit
  if c~parents~items = 0 then return change
  parentSha = c~parents[1]
  statusCode = change~status~left(1)
  if statusCode \= "A" then do
    if change~oldPath \= "" then change~beforeRevision = self~fileRevision(parentSha, change~oldPath)
  end
  if statusCode \= "D" then do
    if change~newPath \= "" then change~afterRevision = self~fileRevision(c~sha, change~newPath)
  end

  targetPath = change~newPath
  if targetPath = "" then targetPath = change~oldPath
  r = self~runner~git("diff --no-ext-diff --no-color --unified=3 " || self~q(parentSha) || " " || self~q(c~sha) || " -- " || self~q(targetPath))
  self~requireOk(r, "GIT.DIFF")
  self~parseUnifiedDiff(change, r~stdout)
  return change

::method parseUnifiedDiff private
  use arg change, diffText
  lines = diffText~makeArray
  current = .nil
  oldLine = 0
  newLine = 0
  do raw over lines
    if raw~left(3) = "@@ " then do
      parse var raw "@@ -" oldSpec " +" newSpec " @@" rest
      parse var oldSpec oldStart "," oldCount
      if oldCount = "" then oldCount = 1
      parse var newSpec newStart "," newCount
      if newCount = "" then newCount = 1
      current = .GitDiffHunk~new(change, oldStart, oldCount, newStart, newCount, raw)
      change~addHunk(current)
      oldLine = oldStart
      newLine = newStart
      iterate
    end
    if current == .nil then iterate
    if raw = "\\ No newline at end of file" then do
      current~noNewlineMarker = .true
      iterate
    end
    prefix = raw~left(1)
    text = raw~substr(2)
    beforeSpan = .nil
    afterSpan = .nil
    select
      when prefix = " " then do
        if change~beforeRevision \== .nil then beforeSpan = change~beforeRevision~lineSpan(oldLine)
        if change~afterRevision \== .nil then afterSpan = change~afterRevision~lineSpan(newLine)
        lineObj = .GitDiffLine~new("CONTEXT", text, oldLine, newLine, beforeSpan, afterSpan, raw)
        oldLine += 1
        newLine += 1
      end
      when prefix = "-" then do
        if change~beforeRevision \== .nil then beforeSpan = change~beforeRevision~lineSpan(oldLine)
        lineObj = .GitDiffLine~new("DELETE", text, oldLine, 0, beforeSpan, .nil, raw)
        oldLine += 1
      end
      when prefix = "+" then do
        if change~afterRevision \== .nil then afterSpan = change~afterRevision~lineSpan(newLine)
        lineObj = .GitDiffLine~new("ADD", text, 0, newLine, .nil, afterSpan, raw)
        newLine += 1
      end
      otherwise iterate
    end
    current~addLine(lineObj)
  end
  return change

::method provenance
  expose path slug remoteUrl
  p = .table~new
  p["kind"] = "GIT_REPOSITORY"
  p["path"] = path
  p["slug"] = slug
  p["remoteUrl"] = remoteUrl
  p["document"] = self
  return p

::method document
  return self

::method requireOk private
  use arg commandResult, code
  if commandResult~ok then return
  details = .table~new
  details["command"] = commandResult~command
  details["stderr"] = commandResult~stderr
  details["rc"] = commandResult~rc
  finding = .RichSourceFinding~new("ERROR", code, commandResult~stderr~strip, self, "git", details)
  self~findings~append(finding)
  raise syntax 93.900 array(code || ": " || commandResult~stderr~strip)

::method q private
  use arg value
  text = value~string~changestr("'", "'\''")
  return "'" || text || "'"

::method quoteRevision private
  use arg revision
  text = revision~string
  /* A revision is passed as a single shell argument, never interpolated syntax. */
  return self~q(text)

::method nulFields private
  use arg data
  fields = .array~new
  start = 1
  nul = '00'x
  do forever
    p = data~pos(nul, start)
    if p = 0 then do
      if start <= data~length then fields~append(data~substr(start))
      leave
    end
    fields~append(data~substr(start, p - start))
    start = p + 1
  end
  return fields


::class GitCommitContext public
::attribute repository get
::attribute sha get
::attribute parents get
::attribute author get
::attribute committer get
::attribute subject get
::attribute body get
::attribute treeSha get
::attribute changes get
::attribute githubEvidence

::method init
  expose repository sha parents author committer subject body treeSha changes githubEvidence
  use arg repositoryArg, shaArg, parentsArg, authorArg, committerArg, subjectArg, bodyArg, treeShaArg
  repository = repositoryArg
  sha = shaArg~string
  parents = parentsArg
  author = authorArg
  committer = committerArg
  subject = subjectArg
  body = bodyArg
  treeSha = treeShaArg~string
  changes = .array~new
  githubEvidence = .nil

::method addChange
  expose changes
  use arg change
  do existing over changes
    if existing == change then return change
  end
  changes~append(change)
  return change

::method message
  expose subject body
  if body~strip = "" then return subject
  return subject || '0a'x || '0a'x || body

::method authorDiffersFromCommitter
  expose author committer
  if \author~name~caselessEquals(committer~name) then return .true
  if \author~email~caselessEquals(committer~email) then return .true
  return .false

::method document
  expose repository
  return repository

::method path
  expose sha
  return "/COMMIT/" || sha

::method provenance
  expose repository sha parents author committer subject treeSha githubEvidence
  p = .table~new
  p["kind"] = "GIT_COMMIT"
  p["document"] = repository
  p["path"] = self~path
  p["sha"] = sha
  p["parents"] = parents
  p["author"] = author
  p["committer"] = committer
  p["subject"] = subject
  p["treeSha"] = treeSha
  p["githubEvidence"] = githubEvidence
  return p

::method string
  expose sha subject
  return sha~left(12) || " " || subject


::class GitFileRevision public
::attribute repository get
::attribute commit get
::attribute sourcePath get
::attribute blobSha get
::attribute content get
::attribute language get
::attribute binary get

::method init
  expose repository commit sourcePath blobSha content language binary
  use arg repositoryArg, commitArg, sourcePathArg, blobShaArg, contentArg
  repository = repositoryArg
  commit = commitArg
  sourcePath = sourcePathArg~string
  blobSha = blobShaArg~string
  content = contentArg
  language = self~guessLanguage(sourcePath)
  binary = content~pos('00'x) > 0

::method document
  expose repository
  return repository

::method path
  expose commit sourcePath
  return "/REVISION/" || commit~sha || "/" || sourcePath

::method lineSpan
  expose content binary
  use arg startLine, endLine = .nil
  if endLine == .nil then endLine = startLine
  if binary then raise syntax 93.900 array("Cannot create a text line span over binary Git blob")
  lines = content~makeArray
  if startLine < 1 | endLine < startLine | endLine > lines~items then -
    raise syntax 93.900 array("Invalid line span " || startLine || ".." || endLine)
  text = .mutablebuffer~new
  do i = startLine to endLine
    text~append(lines[i])
    if i < endLine then text~append('0a'x)
  end
  return .GitSourceSpan~new(self, startLine, endLine, text~string)

::method provenance
  expose repository commit sourcePath blobSha language binary
  p = .table~new
  p["kind"] = "GIT_FILE_REVISION"
  p["document"] = repository
  p["path"] = self~path
  p["commit"] = commit
  p["sourcePath"] = sourcePath
  p["blobSha"] = blobSha
  p["language"] = language
  p["binary"] = binary
  return p

::method guessLanguage private
  use arg p
  lower = p~lower
  if lower~right(4) = ".cpp" | lower~right(4) = ".cxx" | lower~right(3) = ".cc" then return "C++"
  if lower~right(2) = ".c" then return "C"
  if lower~right(2) = ".h" | lower~right(4) = ".hpp" then return "C/C++ HEADER"
  if lower~right(2) = ".s" | lower~right(2) = ".S" then return "ASSEMBLY"
  if lower~right(4) = ".asm" then return "ASSEMBLY"
  if lower~right(3) = ".rb" then return "RUBY"
  if lower~right(5) = ".html" | lower~right(4) = ".htm" then return "HTML"
  return "UNKNOWN"

::method string
  expose sourcePath commit
  return sourcePath || "@" || commit~sha~left(12)


::class GitSourceSpan public
::attribute fileRevision get
::attribute startLine get
::attribute endLine get
::attribute lexicalValue get

::method init
  expose fileRevision startLine endLine lexicalValue
  use arg fileRevisionArg, startLineArg, endLineArg, lexicalArg
  fileRevision = fileRevisionArg
  startLine = startLineArg
  endLine = endLineArg
  lexicalValue = lexicalArg

::method document
  expose fileRevision
  return fileRevision~repository

::method commit
  expose fileRevision
  return fileRevision~commit

::method sourcePath
  expose fileRevision
  return fileRevision~sourcePath

::method path
  expose fileRevision startLine endLine
  return fileRevision~path || "#L" || startLine || "-L" || endLine

::method provenance
  expose fileRevision startLine endLine lexicalValue
  p = .table~new
  p["kind"] = "GIT_SOURCE_SPAN"
  p["document"] = fileRevision~repository
  p["path"] = self~path
  p["fileRevision"] = fileRevision
  p["commit"] = fileRevision~commit
  p["sourcePath"] = fileRevision~sourcePath
  p["blobSha"] = fileRevision~blobSha
  p["startLine"] = startLine
  p["endLine"] = endLine
  p["lexicalValue"] = lexicalValue
  return p

::method string
  return self~path


::class GitDiffLine public
::attribute kind get
::attribute text get
::attribute oldLineNumber get
::attribute newLineNumber get
::attribute beforeSpan get
::attribute afterSpan get
::attribute rawLine get

::method init
  expose kind text oldLineNumber newLineNumber beforeSpan afterSpan rawLine
  use arg kindArg, textArg, oldLineArg, newLineArg, beforeSpanArg = .nil, afterSpanArg = .nil, rawLineArg = ""
  kind = kindArg~string~translate
  text = textArg
  oldLineNumber = oldLineArg
  newLineNumber = newLineArg
  beforeSpan = beforeSpanArg
  afterSpan = afterSpanArg
  rawLine = rawLineArg

::method source
  expose kind beforeSpan afterSpan
  if kind = "DELETE" then return beforeSpan
  if kind = "ADD" then return afterSpan
  if afterSpan \== .nil then return afterSpan
  return beforeSpan

::method provenance
  expose kind text oldLineNumber newLineNumber beforeSpan afterSpan rawLine
  p = .table~new
  p["kind"] = "GIT_DIFF_LINE"
  p["changeKind"] = kind
  p["text"] = text
  p["oldLineNumber"] = oldLineNumber
  p["newLineNumber"] = newLineNumber
  p["beforeSpan"] = beforeSpan
  p["afterSpan"] = afterSpan
  p["rawLine"] = rawLine
  return p

::method string
  expose kind text
  return kind || " " || text


::class GitDiffHunk public
::attribute change get
::attribute oldStart get
::attribute oldCount get
::attribute newStart get
::attribute newCount get
::attribute rawHeader get
::attribute lines get
::attribute noNewlineMarker

::method init
  expose change oldStart oldCount newStart newCount rawHeader lines noNewlineMarker
  use arg changeArg, oldStartArg, oldCountArg, newStartArg, newCountArg, rawHeaderArg
  change = changeArg
  oldStart = oldStartArg
  oldCount = oldCountArg
  newStart = newStartArg
  newCount = newCountArg
  rawHeader = rawHeaderArg
  lines = .array~new
  noNewlineMarker = .false

::method addLine
  expose lines
  use arg line
  lines~append(line)
  return line

::method addedLines
  expose lines
  out = .array~new
  do line over lines
    if line~kind = "ADD" then out~append(line)
  end
  return out

::method deletedLines
  expose lines
  out = .array~new
  do line over lines
    if line~kind = "DELETE" then out~append(line)
  end
  return out

::method provenance
  expose change oldStart oldCount newStart newCount rawHeader lines noNewlineMarker
  p = .table~new
  p["kind"] = "GIT_DIFF_HUNK"
  p["change"] = change
  p["oldStart"] = oldStart
  p["oldCount"] = oldCount
  p["newStart"] = newStart
  p["newCount"] = newCount
  p["rawHeader"] = rawHeader
  p["lines"] = lines
  p["noNewlineMarker"] = noNewlineMarker
  return p

::class GitChangeRef public
::attribute repository get
::attribute commit get
::attribute status get
::attribute oldPath get
::attribute newPath get
::attribute beforeRevision
::attribute afterRevision
::attribute hunks get

::method init
  expose repository commit status oldPath newPath beforeRevision afterRevision hunks
  use arg repositoryArg, commitArg, statusArg, oldPathArg = "", newPathArg = ""
  repository = repositoryArg
  commit = commitArg
  status = statusArg~string
  oldPath = oldPathArg~string
  newPath = newPathArg~string
  beforeRevision = .nil
  afterRevision = .nil
  hunks = .array~new

::method addHunk
  expose hunks
  use arg hunk
  hunks~append(hunk)
  return hunk

::method document
  expose repository
  return repository

::method path
  expose commit oldPath newPath
  p = newPath
  if p = "" then p = oldPath
  return "/CHANGE/" || commit~sha || "/" || p

::method provenance
  expose repository commit status oldPath newPath beforeRevision afterRevision hunks
  p = .table~new
  p["kind"] = "GIT_CHANGE"
  p["document"] = repository
  p["path"] = self~path
  p["commit"] = commit
  p["status"] = status
  p["oldPath"] = oldPath
  p["newPath"] = newPath
  p["beforeRevision"] = beforeRevision
  p["afterRevision"] = afterRevision
  p["hunks"] = hunks
  return p

::method string
  expose status oldPath newPath
  return status || " " || oldPath || " -> " || newPath

::requires "RichSourceCore.cls"
