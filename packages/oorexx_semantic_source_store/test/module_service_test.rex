sql = .FakeModuleSQL~new
svc = .SemanticSourceModuleService~new(sql)

-- Module min d5 + file min d10 + method min d12 => d12 wins.
sql~scenario = "minimum-chain"
e = svc~effectiveRequirement("app", "maths", "src/Foo.cls", "oorexx://app/Foo/m")
call assert e["effective_constraint"] = "MINIMUM", "minimum chain kind"
call assert e["minimum_deployment_id"] = "maths-d12", "highest minimum wins"
call assert e["minimum_sequence"] = 12, "highest minimum sequence"
r = svc~resolveDevelopmentDependency("app", "maths", "src/Foo.cls", "oorexx://app/Foo/m")
call assert r["deployment_id"] = "maths-d15", "development chooses newest qualified satisfying minimum"

-- Exact d12 satisfies min d10 and must win over newer d15.
sql~scenario = "exact-valid"
e = svc~effectiveRequirement("app", "maths", "src/Foo.cls", "oorexx://app/Foo/m")
call assert e["exact_deployment_id"] = "maths-d12", "exact pin recorded"
r = svc~resolveDevelopmentDependency("app", "maths", "src/Foo.cls", "oorexx://app/Foo/m")
call assert r["deployment_id"] = "maths-d12", "exact pin wins"

-- Exact below minimum must fail closed.
sql~scenario = "exact-below"
call expectConflict svc, "app", "maths", "src/Foo.cls", "oorexx://app/Foo/m", "exact below minimum"

-- Two different exact pins must fail closed.
sql~scenario = "exact-conflict"
call expectConflict svc, "app", "maths", "src/Foo.cls", "oorexx://app/Foo/m", "different exact pins"

say "MODULE SERVICE TEST: PASS"
exit 0

expectConflict: procedure
  use arg svc, requiring, target, filePath, methodId, label
  signal on syntax name caught
  ignore = svc~effectiveRequirement(requiring, target, filePath, methodId)
  signal off syntax
  say "ASSERT FAILED: expected conflict -" label
  exit 1
caught:
  signal off syntax
  return

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class FakeModuleSQL
::attribute scenario
::method init
  self~scenario = ""
::method execute
  use arg statement
  rs = .FakeDatabaseResult~new

  if statement~pos("FROM ssc_module_requirement") > 0 then do
    select
      when self~scenario = "minimum-chain" then do
        rs~rows~append(self~req("r-module", "MODULE", "app", "MINIMUM", "maths-d5"))
        rs~rows~append(self~req("r-file", "FILE", "src/Foo.cls", "MINIMUM", "maths-d10"))
        rs~rows~append(self~req("r-method", "METHOD", "oorexx://app/Foo/m", "MINIMUM", "maths-d12"))
      end
      when self~scenario = "exact-valid" then do
        rs~rows~append(self~req("r-module", "MODULE", "app", "MINIMUM", "maths-d10"))
        rs~rows~append(self~req("r-method", "METHOD", "oorexx://app/Foo/m", "EXACT", "maths-d12"))
      end
      when self~scenario = "exact-below" then do
        rs~rows~append(self~req("r-module", "MODULE", "app", "MINIMUM", "maths-d12"))
        rs~rows~append(self~req("r-method", "METHOD", "oorexx://app/Foo/m", "EXACT", "maths-d10"))
      end
      when self~scenario = "exact-conflict" then do
        rs~rows~append(self~req("r-file", "FILE", "src/Foo.cls", "EXACT", "maths-d10"))
        rs~rows~append(self~req("r-method", "METHOD", "oorexx://app/Foo/m", "EXACT", "maths-d12"))
      end
      otherwise nop
    end
    return rs
  end

  if statement~pos("status='QUALIFIED' AND deployment_sequence>=") > 0 then do
    rs~rows~append(self~dep("maths-d15", 15, "QUALIFIED"))
    rs~rows~append(self~dep("maths-d12", 12, "QUALIFIED"))
    return rs
  end

  if statement~pos("FROM ssc_deployment WHERE deployment_id=") > 0 then do
    if statement~pos("maths-d5") > 0 then rs~rows~append(self~dep("maths-d5", 5, "QUALIFIED"))
    else if statement~pos("maths-d10") > 0 then rs~rows~append(self~dep("maths-d10", 10, "QUALIFIED"))
    else if statement~pos("maths-d12") > 0 then rs~rows~append(self~dep("maths-d12", 12, "QUALIFIED"))
    else if statement~pos("maths-d15") > 0 then rs~rows~append(self~dep("maths-d15", 15, "QUALIFIED"))
    return rs
  end

  return rs

::method req private
  use arg id, scopeKind, scopeId, constraint, deploymentId
  row = .directory~new
  row["module_requirement_id"] = id
  row["scope_kind"] = scopeKind
  row["scope_id"] = scopeId
  row["constraint_kind"] = constraint
  row["required_deployment_id"] = deploymentId
  row["reason"] = "test"
  return row

::method dep private
  use arg id, sequence, status
  row = .directory~new
  row["deployment_id"] = id
  row["module_id"] = "maths"
  row["deployment_label"] = id
  row["deployment_sequence"] = sequence
  row["status"] = status
  row["manifest_sha256"] = "sha-" || id
  row["qualified_at"] = ""
  row["qualified_by"] = ""
  row["qualification_evidence"] = ""
  row["sealed_at"] = ""
  return row

::requires "NoSQLServer.cls"
::requires "../src/SemanticSourceModuleService.cls"

::class FakeDatabaseResult
::attribute status
::attribute error
::attribute message
::attribute rows
::method init
  self~status = .Error~SUCCESS
  self~error = 0
  self~message = ""
  self~rows = .array~new
