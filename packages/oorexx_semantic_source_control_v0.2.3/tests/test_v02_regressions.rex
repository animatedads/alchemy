/* Regression acceptance from IBM 4361 and FederationBank dogfooding. */
repoRoot = "/tmp/osc-v02-regression"
address system "rm -rf '" || repoRoot || "'"
repo = .SemanticRepository~new(repoRoot)
analyzer = .OoRexxSourceAnalyzer~new(repo)

/* IBM 4361: one-line methods are real methods and inline body changes count. */
in1 = analyzer~analyzeTree("tests/fixtures_v02/inline_v1", "IBM4361", "MAIN", 1)
in2 = analyzer~analyzeTree("tests/fixtures_v02/inline_v2", "IBM4361", "MAIN", 2)
call assertEq 1, in1~methods~items, "inline method count"
call assertEq "cylinder", in1~methods[1]~methodName, "inline method name strips separator"
call assertTrue in1~methods[1]~bodyHash <> in2~methods[1]~bodyHash, "inline body participates in hash"
d = .ContractComparator~new~compare(in1, in2)
call assertDelta d, "METHOD_IMPLEMENTATION_CHANGED"
repo~saveSnapshot(in1)
call assertContains repo~methodSource("IBM4361", 1, "IBM4361.IBM370CKDRecord.cylinder"), "return cyl", "inline method source lookup"

/* IBM 4361: package directives are semantic surfaces. */
p1 = analyzer~analyzeTree("tests/fixtures_v02/package_v1", "IBM4361PKG", "MAIN", 1)
pNoOptions = analyzer~analyzeTree("tests/fixtures_v02/package_no_options", "IBM4361PKG", "MAIN", 2)
pNoRequires = analyzer~analyzeTree("tests/fixtures_v02/package_no_requires", "IBM4361PKG", "MAIN", 2)
call assertEq 1, p1~packages~items, "package entity count"
call assertContains p1~packages[1]~optionsContract, "digits 30", "package options retained"
call assertContains p1~packages[1]~requiresContract, "JournalPointedState.cls", "package requires retained"
call assertDelta .ContractComparator~new~compare(p1, pNoOptions), "PACKAGE_OPTIONS_CHANGED"
call assertDelta .ContractComparator~new~compare(p1, pNoRequires), "SOURCE_REQUIREMENT_REMOVED"

/* IBM 4361: .Class~new is an exact dependency on Class.init; init:super is not. */
c1 = analyzer~analyzeTree("tests/fixtures_v02/ctor_v1", "IBM4361", "MAIN", 1)
c2 = analyzer~analyzeTree("tests/fixtures_v02/ctor_v2", "IBM4361", "MAIN", 2)
work = analyzer~analyzeTree("tests/fixtures_v02/ctor_work", "WORK", "WORK", "WORKING")
cd = .ContractComparator~new~compare(c1, c2)
call assertDelta cd, "METHOD_CONTRACT_CHANGED"
ctorUses = 0; superUses = 0
 do u over work~uses
   if u~useKind = "CONSTRUCTOR" & u~targetClass = "IBM4361Machine" & u~message = "init" then ctorUses += 1
   if u~useKind = "SUPER_MESSAGE" & u~message = "init" then superUses += 1
 end
call assertEq 2, ctorUses, "constructor edges include package executable code"
call assertEq 1, superUses, "super edge retained separately"
findings = .ImpactEngine~new~assess(c1, c2, work, cd)
ctorFind = 0; superFind = 0
 do f over findings
   if f~evidence = "CONSTRUCTOR" then ctorFind += 1
   if f~path = "Consumer.cls" & f~line = 8 then superFind += 1
 end
call assertEq 2, ctorFind, "constructor consumers reported"
call assertEq 0, superFind, "unrelated init:super not reported"

/* Package/class/method-looking text inside block comments is not source. */
lex = analyzer~analyzeTree("tests/fixtures_v02/comment_lex", "Lex", "MAIN", 1)
call assertEq 1, lex~classes~items, "comment lexer class count"
call assertEq "Real", lex~classes[1]~className, "comment lexer ignores fake class"
call assertEq 1, lex~methods~items, "comment lexer method count"
call assertEq "ping", lex~methods[1]~methodName, "comment lexer ignores fake method"
call assertEq 1, lex~packages~items, "comment lexer package count"
call assertContains lex~packages[1]~optionsContract, "digits 30", "real package option retained"
call assertTrue pos("digits 9", lex~packages[1]~optionsContract) = 0, "commented option ignored"
call assertContains lex~packages[1]~requiresContract, "RealDep.cls", "real package require retained"
call assertTrue pos("Fake.cls", lex~packages[1]~requiresContract) = 0, "commented require ignored"

/* Instance/class/object method sides have distinct semantic identity. */
s1 = analyzer~analyzeTree("tests/fixtures_v02/scope_v1", "Dual", "MAIN", 1)
s2 = analyzer~analyzeTree("tests/fixtures_v02/scope_v2", "Dual", "MAIN", 2)
call assertEq 2, s1~methods~items, "same-name instance and class methods both retained"
inst = s1~methodByQualifiedName("Dual.Dual.init")
clsm = s1~methodByQualifiedName("Dual.Dual.init#CLASS")
call assertEq "INSTANCE", inst~scope, "unqualified selector defaults instance side"
call assertEq "CLASS", clsm~scope, "class-side selector"
call assertTrue inst~entityId <> clsm~entityId, "method sides have different entity ids"
call assertEq "Dual.Dual.init", inst~identityKey, "instance key remains v0.1 compatible"
call assertEq "Dual.Dual.init#CLASS", clsm~identityKey, "class key carries side"
objm = .SourceMethodRevision~new("MO", "Dual.Dual.init", "Dual", "init", "OBJECT", "PUBLIC", "", "C", "B", "", 1, 1)
call assertEq "Dual.Dual.init#OBJECT", objm~identityKey, "live object-scope method identity"
sd = .ContractComparator~new~compare(s1, s2)
call assertEq 1, sd~items, "class-only edit is one semantic delta"
call assertEq "METHOD_IMPLEMENTATION_CHANGED", sd[1]~kind, "class-side body edit kind"
call assertEq "Dual.Dual.init#CLASS", sd[1]~entity, "class-side delta identity"
swork = analyzer~analyzeTree("tests/fixtures_v02/scope_work", "WORK", "WORK", "WORKING")
sfind = .ImpactEngine~new~assess(s1, s2, swork, sd)
ctorHits = 0; classHits = 0; dynamicHits = 0
do f over sfind
  if f~evidence = "CONSTRUCTOR" then ctorHits += 1
  if f~evidence = "LITERAL_CLASS_MESSAGE" then classHits += 1
  if f~evidence = "DYNAMIC_MESSAGE_NAME" then dynamicHits += 1
end
call assertEq 0, ctorHits, "class-side edit does not hit constructor/instance init"
call assertEq 1, classHits, "class-side literal consumer reported"
call assertEq 1, dynamicHits, "unknown dynamic init retained as verification evidence"

/* v0.1 repositories are re-indexed from immutable blobs in memory, so new
   analyzer surfaces do not appear as application changes. */
legacyRoot = "/tmp/osc-v02-legacy-view"
address system "rm -rf '" || legacyRoot || "'"
legacyRepo = .SemanticRepository~new(legacyRoot)
legacyAnalyzer = .OoRexxSourceAnalyzer~new(legacyRepo)
legacyBase = legacyAnalyzer~analyzeTree("tests/fixtures_v02/package_v1", "LegacyPkg", "MAIN", 1)
legacyRepo~saveSnapshot(legacyBase)
legacyPath = legacyRoot || "/components/LegacyPkg/levels/1/snapshot.osc"
rows = .SSCUtil~readLines(legacyPath)
oldRows = .array~new
do row over rows
  if row~left(2) <> "K|" then oldRows~append(row)
end
.SSCUtil~writeLines(legacyPath, oldRows)
legacyLoaded = legacyRepo~loadSnapshot("LegacyPkg", 1)
call assertEq 1, legacyLoaded~packages~items, "legacy snapshot package semantics re-indexed"
legacySame = legacyAnalyzer~analyzeTree("tests/fixtures_v02/package_v1", "LegacyPkg", "MAIN", 2)
legacyDelta = .ContractComparator~new~compare(legacyLoaded, legacySame)
call assertEq 0, legacyDelta~items, "analyzer upgrade does not create false application delta"

/* FederationBank: all release files are immutable evidence, not only Rexx. */
release = analyzer~analyzeTree("tests/fixtures_v02/release_v1", "Release", "MAIN", 1)
call assertEq 4, release~files~items, "whole release file count"
repo2 = .SemanticRepository~new("/tmp/osc-v02-release")
address system "rm -rf '/tmp/osc-v02-release' '/tmp/osc-v02-export'"
repo2 = .SemanticRepository~new("/tmp/osc-v02-release")
release = .OoRexxSourceAnalyzer~new(repo2)~analyzeTree("tests/fixtures_v02/release_v1", "Release", "MAIN", 1)
repo2~saveSnapshot(release)
loaded = repo2~loadLatest("Release")
call assertEq 4, repo2~exportSnapshot(loaded, "/tmp/osc-v02-export"), "whole release export count"
address system "cmp tests/fixtures_v02/release_v1/schema/postgresql.sql /tmp/osc-v02-export/schema/postgresql.sql"
call assertEq 0, rc, "schema exported byte exact"
address system "cmp tests/fixtures_v02/release_v1/README.md /tmp/osc-v02-export/README.md"
call assertEq 0, rc, "README exported byte exact"
address system "cmp tests/fixtures_v02/release_v1/run_tests.sh /tmp/osc-v02-export/run_tests.sh"
call assertEq 0, rc, "test runner exported byte exact"

/* FederationBank: SQL semantics must not retain host Rexx call delimiters. */
sql = analyzer~analyzeTree("tests/fixtures_v02/sql_suffix", "Bank", "MAIN", 1)
call assertEq 1, sql~candidates~items, "SQL candidate count"
contract = sql~candidates[1]~semanticContract
call assertContains contract, "predicate=IDEMPOTENCY_KEY = ?", "clean predicate"
call assertTrue pos('?\")', contract) = 0, "host suffix absent from SQL contract"

say "PASS test_v02_regressions"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

assertContains: procedure
  use arg text, needle, label
  if pos(needle, text) = 0 then do
    say "FAIL" label "missing=" needle "in=" text
    exit 1
  end
  return

assertDelta: procedure
  use arg deltas, wanted
  do delta over deltas
    if delta~kind = wanted then return
  end
  say "FAIL missing delta" wanted
  do delta over deltas
    say "  got" delta~kind delta~entity delta~detail
  end
  exit 1

::requires "src/SemanticSourceControl.cls"
