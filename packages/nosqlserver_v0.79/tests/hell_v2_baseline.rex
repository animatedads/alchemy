corpus = arg(1)
if corpus = "" then corpus = "hell_corpus_v2.sql"
if stream(corpus, "c", "query exists") = "" then do
  say "corpus not found:" corpus
  exit 2
end
root = .NoSQLServerTestSupport~createBlankDatabase("hell")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)
phase = "LOAD"
statement = ""
currentTitle = ""
queryTotal = 0
pass = 0
unsupported = 0
parseErrors = 0
wrong = 0
execErrors = 0
loadFailures = 0
say "NOSQLSERVER HELL CORPUS BASELINE"
say "corpus:" corpus
say

do while lines(corpus) > 0
  line = linein(corpus)
  stripped = line~strip
  if stripped~startsWith("--") then do
    if stripped~pos("-- QUERIES") > 0 | stripped~pos("QUERIES") > 0 then phase = "QUERY"
    if phase = "QUERY" & stripped~startsWith("-- [") then currentTitle = stripped~substr(4)~strip
    iterate
  end
  if stripped = "" then iterate
  if statement = "" then statement = stripped
  else statement ||= " " || stripped
  if stripped~right(1) \= ";" then iterate
  rs = sql~execute(statement)
  if phase = "LOAD" then do
    if rs~status \= .Error~SUCCESS then do
      loadFailures += 1
      say "LOAD FAILURE:" rs~error "|" rs~message
      say "  SQL:" statement
    end
  end
  else do
    queryTotal += 1
    classification = classify(rs, queryTotal, sql)
    select
      when classification = "PASS" then pass += 1
      when classification = "UNSUPPORTED" then unsupported += 1
      when classification = "PARSE_ERROR" then parseErrors += 1
      when classification = "WRONG_RESULT" then wrong += 1
      otherwise execErrors += 1
    end
    n = queryTotal~format(2,0)~changestr(" ", "0")
    say "QUERY" n || ":" classification "|" currentTitle
    if rs~status \= .Error~SUCCESS then say "       " rs~error "|" rs~message
    else say "       rows=" rs~rowCount "affected=" rs~affectedRows "path=" rs~accessPath
  end
  statement = ""
end
call lineout corpus
say
say "load failures :" loadFailures
say "queries       :" queryTotal
say "  PASS           :" pass
say "  UNSUPPORTED    :" unsupported
say "  PARSE_ERROR    :" parseErrors
say "  WRONG_RESULT   :" wrong
say "  EXECUTION_ERROR:" execErrors
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
if loadFailures > 0 then exit 1
exit 0

classify: procedure
  use arg rs, queryNumber, sql
  if rs~status = .Error~SUCCESS then return "WRONG_RESULT"  -- unverified success
  if rs~error = .Error~SQLUNSUPPORTED then return "UNSUPPORTED"
  if rs~error = .Error~SQLPARSEERROR then return "PARSE_ERROR"
  return "EXECUTION_ERROR"

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
