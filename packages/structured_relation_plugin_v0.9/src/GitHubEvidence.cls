/*
 * GitHubEvidence v0.8
 *
 * Rich evidence objects for public forge metadata.  Git remains the source of
 * revision truth; these objects preserve PR/review/CI/intent evidence without
 * pretending that an author, reviewer, committer, and stated rationale are one
 * fact.
 */


::class GitHubRepositoryEvidence public
::attribute slug get
::attribute url get
::attribute retrievedAt get
::attribute pullRequests get
::attribute history get

::method init
  expose slug url retrievedAt pullRequests history
  use arg slugArg, urlArg, retrievedAtArg
  slug = slugArg~string
  url = urlArg~string
  retrievedAt = retrievedAtArg~string
  pullRequests = .table~new
  history = .array~new
  history~append(.RichProcessingEvent~new("SOURCE", "LOAD_GITHUB_EVIDENCE", url, self))

::method addPullRequest
  expose pullRequests history
  use arg pr
  pullRequests[pr~number] = pr
  history~append(.RichProcessingEvent~new("GITHUB", "ADD_PULL_REQUEST", pr~number, pr))
  return pr

::method pullRequest
  expose pullRequests
  use arg number
  return pullRequests[number]

::method document
  return self

::method provenance
  expose slug url retrievedAt pullRequests
  p = .table~new
  p["kind"] = "GITHUB_REPOSITORY_EVIDENCE"
  p["document"] = self
  p["slug"] = slug
  p["url"] = url
  p["retrievedAt"] = retrievedAt
  p["pullRequests"] = pullRequests
  return p


::class GitHubEvidenceSource public
::attribute kind get
::attribute url get
::attribute identifier get
::attribute author get
::attribute timestamp get
::attribute path get
::attribute revision get

::method init
  expose kind url identifier author timestamp path revision
  use arg kindArg, urlArg, identifierArg = "", authorArg = "", timestampArg = "", pathArg = "", revisionArg = ""
  kind = kindArg~string~translate
  url = urlArg~string
  identifier = identifierArg~string
  author = authorArg~string
  timestamp = timestampArg~string
  path = pathArg~string
  revision = revisionArg~string

::method provenance
  expose kind url identifier author timestamp path revision
  p = .table~new
  p["kind"] = kind
  p["url"] = url
  p["identifier"] = identifier
  p["author"] = author
  p["timestamp"] = timestamp
  p["path"] = path
  p["revision"] = revision
  return p

::method string
  expose kind identifier url
  if identifier \= "" then return kind || " " || identifier
  return kind || " " || url


::class GitHubClaimEvidence public
::attribute category get
::attribute statement get
::attribute posture get
::attribute source get
::attribute confidence get
::attribute details get

::method init
  expose category statement posture source confidence details
  use arg categoryArg, statementArg, postureArg, sourceArg, confidenceArg = "UNASSESSED", detailsArg = .nil
  category = categoryArg~string~translate
  statement = statementArg~string
  posture = postureArg~string~translate
  source = sourceArg
  confidence = confidenceArg~string~translate
  if detailsArg == .nil then details = .table~new
  else details = detailsArg

::method provenance
  expose category posture source confidence details
  p = .table~new
  p["kind"] = "GITHUB_CLAIM"
  p["category"] = category
  p["posture"] = posture
  p["source"] = source
  p["confidence"] = confidence
  p["details"] = details
  return p

::method string
  expose category posture statement
  return posture || " " || category || ": " || statement


::class GitHubPullRequestEvidence public
::attribute repositorySlug get
::attribute number get
::attribute title get
::attribute state get
::attribute draft get
::attribute author get
::attribute baseSha get
::attribute headSha get
::attribute url get
::attribute retrievedAt get
::attribute labels get
::attribute claims get
::attribute reviews get
::attribute checks get
::attribute codeChanges get

::method init
  expose repositorySlug number title state draft author baseSha headSha url retrievedAt labels claims reviews checks codeChanges
  use arg repositorySlugArg, numberArg, titleArg, stateArg, draftArg, authorArg, baseShaArg, headShaArg, urlArg, retrievedAtArg
  repositorySlug = repositorySlugArg~string
  number = numberArg
  title = titleArg~string
  state = stateArg~string~translate
  draft = draftArg
  author = authorArg~string
  baseSha = baseShaArg~string
  headSha = headShaArg~string
  url = urlArg~string
  retrievedAt = retrievedAtArg~string
  labels = .array~new
  claims = .array~new
  reviews = .array~new
  checks = .array~new
  codeChanges = .array~new

::method addLabel
  expose labels
  use arg label
  labels~append(label~string)
  return self

::method addClaim
  expose claims
  use arg claim
  claims~append(claim)
  return claim

::method addReview
  expose reviews
  use arg review
  reviews~append(review)
  return review

::method addCheck
  expose checks
  use arg check
  checks~append(check)
  return check

::method addCodeChange
  expose codeChanges
  use arg change
  codeChanges~append(change)
  return change

::method claimsByCategory
  expose claims
  use arg wanted
  out = .array~new
  do claim over claims
    if claim~category~caselessEquals(wanted~string) then out~append(claim)
  end
  return out

::method evidenceSource
  expose url number author headSha retrievedAt
  return .GitHubEvidenceSource~new("PULL_REQUEST", url, "PR#" || number, author, retrievedAt, "", headSha)

::method provenance
  expose repositorySlug number title state draft author baseSha headSha url retrievedAt labels claims reviews checks codeChanges
  p = .table~new
  p["kind"] = "GITHUB_PULL_REQUEST"
  p["repositorySlug"] = repositorySlug
  p["number"] = number
  p["title"] = title
  p["state"] = state
  p["draft"] = draft
  p["author"] = author
  p["baseSha"] = baseSha
  p["headSha"] = headSha
  p["url"] = url
  p["retrievedAt"] = retrievedAt
  p["labels"] = labels
  p["claims"] = claims
  p["reviews"] = reviews
  p["checks"] = checks
  p["codeChanges"] = codeChanges
  return p

::method string
  expose number title
  return "PR#" || number || " " || title


::class RemoteCodeLocation public
::attribute repositorySlug get
::attribute revision get
::attribute sourcePath get
::attribute lineStart get
::attribute lineEnd get
::attribute url get
::attribute symbol get

::method init
  expose repositorySlug revision sourcePath lineStart lineEnd url symbol
  use arg repositorySlugArg, revisionArg, sourcePathArg, lineStartArg = 0, lineEndArg = 0, urlArg = "", symbolArg = ""
  repositorySlug = repositorySlugArg~string
  revision = revisionArg~string
  sourcePath = sourcePathArg~string
  lineStart = lineStartArg
  lineEnd = lineEndArg
  url = urlArg~string
  symbol = symbolArg~string

::method path
  expose revision sourcePath lineStart lineEnd
  p = "/REMOTE/" || revision || "/" || sourcePath
  if lineStart > 0 then p ||= "#L" || lineStart
  if lineEnd > lineStart then p ||= "-L" || lineEnd
  return p

::method provenance
  expose repositorySlug revision sourcePath lineStart lineEnd url symbol
  p = .table~new
  p["kind"] = "REMOTE_CODE_LOCATION"
  p["repositorySlug"] = repositorySlug
  p["revision"] = revision
  p["sourcePath"] = sourcePath
  p["lineStart"] = lineStart
  p["lineEnd"] = lineEnd
  p["url"] = url
  p["symbol"] = symbol
  p["path"] = self~path
  return p

::method string
  return self~path


::class CodeOperationEvidence public
::attribute operationKind get
::attribute api get
::attribute location get
::attribute arguments get
::attribute properties get
::attribute sourceEvidence get

::method init
  expose operationKind api location arguments properties sourceEvidence
  use arg operationKindArg, apiArg, locationArg, argumentsArg = .nil, propertiesArg = .nil, sourceEvidenceArg = .nil
  operationKind = operationKindArg~string~translate
  api = apiArg~string
  location = locationArg
  if argumentsArg == .nil then arguments = .array~new
  else arguments = argumentsArg
  if propertiesArg == .nil then properties = .table~new
  else properties = propertiesArg
  sourceEvidence = sourceEvidenceArg

::method property
  expose properties
  use arg key, defaultValue = .nil
  v = properties[key~string]
  if v == .nil then return defaultValue
  return v

::method provenance
  expose operationKind api location arguments properties sourceEvidence
  p = .table~new
  p["kind"] = "CODE_OPERATION"
  p["operationKind"] = operationKind
  p["api"] = api
  p["location"] = location
  p["arguments"] = arguments
  p["properties"] = properties
  p["sourceEvidence"] = sourceEvidence
  return p

::method string
  expose operationKind api location
  return operationKind || " " || api || " @ " || location~string


::class CodeChangeEvidence public
::attribute beforeOperation get
::attribute afterOperation get
::attribute pullRequest get
::attribute claims get
::attribute tests get
::attribute reviews get
::attribute annotations get

::method init
  expose beforeOperation afterOperation pullRequest claims tests reviews annotations
  use arg beforeArg, afterArg, pullRequestArg
  beforeOperation = beforeArg
  afterOperation = afterArg
  pullRequest = pullRequestArg
  claims = .array~new
  tests = .array~new
  reviews = .array~new
  annotations = .table~new

::method addClaim
  expose claims
  use arg claim
  claims~append(claim)
  return claim

::method addTestEvidence
  expose tests
  use arg evidence
  tests~append(evidence)
  return evidence

::method addReviewEvidence
  expose reviews
  use arg evidence
  reviews~append(evidence)
  return evidence

::method annotate
  expose annotations
  use arg key, value
  annotations[key~string] = value
  return self

::method provenance
  expose beforeOperation afterOperation pullRequest claims tests reviews annotations
  p = .table~new
  p["kind"] = "CODE_CHANGE_EVIDENCE"
  p["beforeOperation"] = beforeOperation
  p["afterOperation"] = afterOperation
  p["pullRequest"] = pullRequest
  p["claims"] = claims
  p["tests"] = tests
  p["reviews"] = reviews
  p["annotations"] = annotations
  return p


::class CodeAnalysisFinding public
::attribute rule get
::attribute severity get
::attribute classification get
::attribute message get
::attribute source get
::attribute evidence get
::attribute counterEvidence get
::attribute confidence get
::attribute createdAt get

::method init
  expose rule severity classification message source evidence counterEvidence confidence createdAt
  use arg ruleArg, severityArg, classificationArg, messageArg, sourceArg, confidenceArg = "UNASSESSED"
  rule = ruleArg~string
  severity = severityArg~string~translate
  classification = classificationArg~string~translate
  message = messageArg~string
  source = sourceArg
  confidence = confidenceArg~string~translate
  evidence = .array~new
  counterEvidence = .array~new
  createdAt = .DateTime~new~utcIsoDate

::method addEvidence
  expose evidence
  use arg item
  evidence~append(item)
  return item

::method addCounterEvidence
  expose counterEvidence
  use arg item
  counterEvidence~append(item)
  return item

::method provenance
  expose rule severity classification source evidence counterEvidence confidence createdAt
  p = .table~new
  p["kind"] = "CODE_ANALYSIS_FINDING"
  p["rule"] = rule
  p["severity"] = severity
  p["classification"] = classification
  p["source"] = source
  p["evidence"] = evidence
  p["counterEvidence"] = counterEvidence
  p["confidence"] = confidence
  p["createdAt"] = createdAt
  return p

::method asBusinessFact
  expose classification source
  diagnostics = .array~new
  diagnostics~append(.RichSourceFinding~new("INFO", "CODE." || classification, self~message, source, self~rule, self~provenance))
  return .RichBusinessFact~new("code_finding", classification, "PRESENT", source, .nil, "CODE_FINDING", classification, diagnostics)

::method string
  expose severity classification message
  return severity || " " || classification || ": " || message

::requires "RichSourceCore.cls"

/*
 * Revision-bound public source snapshots.  These objects are evidence fetched
 * from a forge at an exact revision; when a blob SHA is supplied the snapshot
 * can be tied to Git object identity rather than only a URL/line number.
 */
::class RemoteSourceFileRevision public
::attribute repositorySlug get
::attribute revision get
::attribute sourcePath get
::attribute blobSha get
::attribute content get
::attribute url get
::attribute retrievedAt get
::attribute language get
::attribute binary get
::attribute blobVerificationState get
::attribute computedBlobSha get

::method init
  expose repositorySlug revision sourcePath blobSha content url retrievedAt language binary blobVerificationState computedBlobSha
  use arg repositoryArg, revisionArg, pathArg, blobArg, contentArg, urlArg = "", retrievedAtArg = ""
  repositorySlug = repositoryArg~string
  revision = revisionArg~string
  sourcePath = pathArg~string
  blobSha = blobArg~string~strip
  content = contentArg
  url = urlArg~string
  retrievedAt = retrievedAtArg~string
  binary = content~pos('00'x) > 0
  language = self~guessLanguage(sourcePath)
  computedBlobSha = ""
  if blobSha = "" then blobVerificationState = "UNBOUND"
  else blobVerificationState = "CLAIMED"

/* A remote blob identifier is evidence only after the bytes carried by this
 * object have been checked against Git's canonical blob object identity.
 * Merely supplying a SHA-looking string does not upgrade provenance. */
::method verifyBlobIdentity
  expose blobSha content blobVerificationState computedBlobSha
  use arg gitExecutable = "git"
  if blobSha = "" then do
    blobVerificationState = "UNBOUND"
    computedBlobSha = ""
    return .false
  end

  token = random(100000, 999999) || "_" || random(100000, 999999)
  inPath = "/tmp/oorexx_remote_blob_" || token || ".in"
  outPath = "/tmp/oorexx_remote_blob_" || token || ".out"
  errPath = "/tmp/oorexx_remote_blob_" || token || ".err"
  input = .stream~new(inPath)
  openStatus = input~open("WRITE REPLACE")
  if \openStatus~caselessEquals("READY:") then do
    blobVerificationState = "VERIFICATION_FAILED"
    return .false
  end
  input~charout(content)
  input~close

  cmd = self~quote(gitExecutable) || " hash-object " || self~quote(inPath) || -
        " > " || self~quote(outPath) || " 2> " || self~quote(errPath)
  address system cmd
  commandRc = rc
  if commandRc = 0 then computedBlobSha = self~readAll(outPath)~changestr('0d'x, "")~changestr('0a'x, "")~strip
  else computedBlobSha = ""
  address system "rm -f -- " || self~quote(inPath) || " " || self~quote(outPath) || " " || self~quote(errPath)

  if commandRc \= 0 | computedBlobSha = "" then do
    blobVerificationState = "VERIFICATION_FAILED"
    return .false
  end
  if computedBlobSha~caselessEquals(blobSha) then do
    blobVerificationState = "VERIFIED"
    return .true
  end
  blobVerificationState = "MISMATCH"
  return .false

::method repository
  expose repositorySlug
  return repositorySlug

::method commit
  expose revision
  return revision

::method path
  expose repositorySlug revision sourcePath
  return "/REMOTE_REVISION/" || repositorySlug || "/" || revision || "/" || sourcePath

::method lineSpan
  expose content binary
  use arg startLine, endLine = .nil
  if endLine == .nil then endLine = startLine
  if binary then raise syntax 93.900 array("Cannot create a text span over binary remote source")
  lines = content~makeArray
  if startLine < 1 | endLine < startLine | endLine > lines~items then -
    raise syntax 93.900 array("Invalid remote line span " || startLine || ".." || endLine)
  text = .mutablebuffer~new
  do i = startLine to endLine
    text~append(lines[i])
    if i < endLine then text~append('0a'x)
  end
  return .RemoteSourceSpan~new(self, startLine, endLine, text~string)

::method document
  return self

::method provenance
  expose repositorySlug revision sourcePath blobSha url retrievedAt language binary blobVerificationState computedBlobSha
  p = .table~new
  p["kind"] = "REMOTE_SOURCE_FILE_REVISION"
  p["document"] = self
  p["path"] = self~path
  p["repositorySlug"] = repositorySlug
  p["revision"] = revision
  p["sourcePath"] = sourcePath
  p["blobSha"] = blobSha
  p["computedBlobSha"] = computedBlobSha
  p["blobVerificationState"] = blobVerificationState
  p["url"] = url
  p["retrievedAt"] = retrievedAt
  p["language"] = language
  p["binary"] = binary
  select
    when blobVerificationState = "VERIFIED" then p["identityStrength"] = "GIT_BLOB_BOUND"
    when blobVerificationState = "MISMATCH" then p["identityStrength"] = "GIT_BLOB_MISMATCH"
    when blobVerificationState = "VERIFICATION_FAILED" then p["identityStrength"] = "GIT_BLOB_UNVERIFIED"
    when blobSha \= "" then p["identityStrength"] = "GIT_BLOB_CLAIMED"
    otherwise p["identityStrength"] = "REVISION_PATH_ONLY"
  end
  return p

::method quote private
  use arg value
  text = value~string
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

::method guessLanguage private
  use arg p
  lower = p~lower
  if lower~right(4) = ".cpp" | lower~right(4) = ".cxx" | lower~right(3) = ".cc" then return "C++"
  if lower~right(2) = ".c" then return "C"
  if lower~right(2) = ".h" | lower~right(4) = ".hpp" then return "C/C++ HEADER"
  if lower~right(2) = ".s" | lower~right(4) = ".asm" then return "ASSEMBLY"
  return "UNKNOWN"


::class RemoteSourceSpan public
::attribute fileRevision get
::attribute startLine get
::attribute endLine get
::attribute lexicalValue get

::method init
  expose fileRevision startLine endLine lexicalValue
  use arg revisionArg, startArg, endArg, lexicalArg
  fileRevision = revisionArg
  startLine = startArg
  endLine = endArg
  lexicalValue = lexicalArg

::method document
  expose fileRevision
  return fileRevision

::method path
  expose fileRevision startLine endLine
  return fileRevision~path || "#L" || startLine || "-L" || endLine

::method provenance
  expose fileRevision startLine endLine lexicalValue
  p = .table~new
  p["kind"] = "REMOTE_SOURCE_SPAN"
  p["document"] = fileRevision
  p["path"] = self~path
  p["fileRevision"] = fileRevision
  p["repositorySlug"] = fileRevision~repositorySlug
  p["revision"] = fileRevision~revision
  p["blobSha"] = fileRevision~blobSha
  p["sourcePath"] = fileRevision~sourcePath
  p["startLine"] = startLine
  p["endLine"] = endLine
  p["lexicalValue"] = lexicalValue
  return p

::method string
  return self~path
