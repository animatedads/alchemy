parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v013_version")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)

v = db~version
call assert v~isA(.NoSQLServerVersionInfo), "version object class"
call assert v~product = "NoSQLServer", "product"
call assert v~release = .NoSQLServerBuild~RELEASE, "release"
call assert v~engine = "FILE", "engine"
call assert v~storage = "YAML+DELIMITED", "storage"
call assert v~storageFormatVersion = 1, "storage format from catalog"
call assert v~sqlLevel = .NoSQLServerBuild~SQLLEVEL, "SQL capability level"
call assert v~runtimeVersion = .rexxinfo~version, "runtime version"
call assert v~runtimeLanguageLevel = .rexxinfo~languageLevel, "runtime language level"
call assert v~platform = .rexxinfo~platform, "runtime platform"
call assert v~architecture = .rexxinfo~architecture, "runtime architecture"
call assert v~supports("GROUP_BY"), "supported feature query"
call assert \v~supports("WINDOW_FUNCTIONS"), "unsupported feature query"
call assert v~string~pos("NoSQLServer " || .NoSQLServerBuild~RELEASE) > 0, "human string release"
call assert v~string~pos("ooRexx=" || .rexxinfo~version) > 0, "human string runtime"
call assert sql~version~string = v~string, "SQL facade version forwards engine contract"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.13 VERSION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return
::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
