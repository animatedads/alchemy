/* Terminal Machine dogfood regressions for v0.2.2. */
repoRoot = "/tmp/osc-v022-terminal"
address system "rm -rf '" || repoRoot || "'"
repo = .SemanticRepository~new(repoRoot)
analyzer = .OoRexxSourceAnalyzer~new(repo)

v1 = analyzer~analyzeTree("tests/fixtures_v022/const_attr_v1", "Surface", "MAIN", 1)
v2 = analyzer~analyzeTree("tests/fixtures_v022/const_attr_v2", "Surface", "MAIN", 2)
call assertEq 1, v1~constants~items, "constant entity count"
call assertEq 1, v1~attributes~items, "attribute entity count"
call assertEq "MODE", v1~constants[1]~constantName, "constant name"
call assertEq '"A"', v1~constants[1]~valueContract, "constant value retained"
call assertEq "GET", v1~attributes[1]~accessMode, "attribute v1 getter"
call assertEq "SET", v2~attributes[1]~accessMode, "attribute v2 setter"

deltas = .ContractComparator~new~compare(v1, v2)
call assertEq 2, deltas~items, "constant/attribute-only change count"
call assertDelta deltas, "CONSTANT_VALUE_CHANGED"
call assertDelta deltas, "ATTRIBUTE_ACCESS_CHANGED"

work = analyzer~analyzeTree("tests/fixtures_v022/const_attr_work", "WORK", "WORK", "WORKING")
findings = .ImpactEngine~new~assess(v1, v2, work, deltas)
call assertFinding findings, "CONSTANT_VALUE_CHANGED", "LITERAL_CLASS_MESSAGE"
call assertFinding findings, "ATTRIBUTE_ACCESS_CHANGED", "DYNAMIC_ATTRIBUTE_MESSAGE"

/* Explicit GET/SET attributes can carry executable bodies.  Their public
   accessor contract remains one attribute entity while implementation changes
   are tracked per accessor. */
ab1 = analyzer~analyzeTree("tests/fixtures_v022/attr_body_v1", "AttrBody", "MAIN", 1)
ab2 = analyzer~analyzeTree("tests/fixtures_v022/attr_body_v2", "AttrBody", "MAIN", 2)
call assertEq 1, ab1~attributes~items, "paired get/set aggregate as one attribute"
call assertEq "BOTH", ab1~attributes[1]~accessMode, "paired accessor mode"
abDelta = .ContractComparator~new~compare(ab1, ab2)
call assertEq 1, abDelta~items, "getter body-only change count"
call assertDelta abDelta, "ATTRIBUTE_GETTER_IMPLEMENTATION_CHANGED"

/* New semantic rows survive repository round trip. */
repo~saveSnapshot(v1)
loaded = repo~loadSnapshot("Surface", 1)
call assertEq 1, loaded~constants~items, "persisted constant count"
call assertEq 1, loaded~attributes~items, "persisted attribute count"
call assertEq "GET", loaded~attributes[1]~accessMode, "persisted attribute contract"

/* A pre-v0.2.2 snapshot is re-indexed from immutable source blobs in memory,
   so new semantic entity types do not appear as false additions. */
path = repoRoot || "/components/Surface/levels/1/snapshot.osc"
rows = .SSCUtil~readLines(path)
legacy = .array~new
do row over rows
  if row~left(2) = "V|" then iterate
  if row~left(2) = "A|" then iterate
  if row~left(2) = "N|" then iterate
  legacy~append(row)
end
.SSCUtil~writeLines(path, legacy)
upgraded = repo~loadSnapshot("Surface", 1)
call assertEq 1, upgraded~constants~items, "legacy constant re-index"
call assertEq 1, upgraded~attributes~items, "legacy attribute re-index"
same = analyzer~analyzeTree("tests/fixtures_v022/const_attr_v1", "Surface", "MAIN", 2)
call assertEq 0, .ContractComparator~new~compare(upgraded, same)~items, "analyzer upgrade not application change"

/* Protocol/API identity constants are deliberately elevated. */
hi1 = .SourceSnapshot~new("Hi", "MAIN", 1)
hi2 = .SourceSnapshot~new("Hi", "MAIN", 2)
hi1~addConstant(.SourceConstantRevision~new("N1", "Hi.C.API_VERSION", "C", "API_VERSION", '"1"', .SSCUtil~contentHash('"1"'), "C.cls", 1))
hi2~addConstant(.SourceConstantRevision~new("N1", "Hi.C.API_VERSION", "C", "API_VERSION", '"2"', .SSCUtil~contentHash('"2"'), "C.cls", 1))
hd = .ContractComparator~new~compare(hi1, hi2)
call assertEq "HIGH", hd[1]~risk, "API constant change elevated"

say "PASS test_v022_terminal_dogfood"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertDelta: procedure
  use arg deltas, wanted
  do d over deltas
    if d~kind = wanted then return
  end
  say "FAIL missing delta" wanted
  do d over deltas; say " got" d~kind d~entity; end
  exit 1

assertFinding: procedure
  use arg findings, kind, evidence
  do f over findings
    if f~changeKind = kind & f~evidence = evidence then return
  end
  say "FAIL missing finding" kind evidence
  do f over findings; say " got" f~changeKind f~evidence f~consumer; end
  exit 1

::requires "src/SemanticSourceControl.cls"
