sql = .FakeBranchSQL~new
svc = .SemanticSourceBranchService~new(sql)

-- Hard conflict creates a conflict branch and two candidate overrides.
b = svc~createConflictBranch("br-1", "family", "dep-10", "oorexx://family/Family/method/calc", "r17", "r18", "r19", "2026-09-27T17:40:00Z", "coder-a")
call assert b["classification"] = "CONFLICT", "hard conflict branch classification"
call assert sql~overrideCount = 2, "two conflict candidates retained"

-- Next module request exposes branch notice.
n = svc~branchNoticeForModule("family")
call assert n["has_branch"], "branch notice present"
call assert n["has_conflict_branch"], "conflict branch notice present"

-- Intentional branch accepts non-conflicting upstream by policy.
b = svc~confirmIntentional("br-1", "ACCEPT_NON_CONFLICTING", "2026-09-27T17:41:00Z", "architect")
ctx = .directory~new
ctx["module_id"] = "family"
ctx["file_path"] = "src/family.cls"
ctx["class_id"] = "oorexx://family/Family"
ctx["method_id"] = "oorexx://family/Family/method/formatOutput"
call assert svc~decideUpstreamChange("br-1", ctx, 0) = "ADOPTED", "non-conflicting upstream adopted"
call assert svc~decideUpstreamChange("br-1", ctx, 1) = "REJECTED_CONFLICT", "local collision rejects upstream"

-- Method protection wins over branch accept policy.
ignore = svc~protect("p-1", "br-1", "METHOD", ctx["method_id"], "customer override", "2026-09-27T17:42:00Z", "architect")
call assert svc~decideUpstreamChange("br-1", ctx, 0) = "REJECTED_PROTECTED", "method protection rejects upstream"

-- Class protection inherits to another method in that class.
ctx2 = .directory~new
ctx2["module_id"] = "family"
ctx2["file_path"] = "src/family.cls"
ctx2["class_id"] = "oorexx://family/Family"
ctx2["method_id"] = "oorexx://family/Family/method/addChild"
ignore = svc~protect("p-2", "br-1", "CLASS", ctx2["class_id"], "freeze class", "2026-09-27T17:43:00Z", "architect")
call assert svc~decideUpstreamChange("br-1", ctx2, 0) = "REJECTED_PROTECTED", "class protection inherited by method"

say "BRANCH SERVICE TEST: PASS"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class FakeBranchSQL
::attribute overrideCount
::attribute branchClass
::attribute branchPolicy
::method init
  self~overrideCount = 0
  self~branchClass = "CONFLICT"
  self~branchPolicy = "UNDECIDED"
  self~protections = .array~new
::attribute protections

::method execute
  use arg statement
  rs = .FakeDatabaseResult~new
  if statement~pos("INSERT INTO ssc_branch_override") > 0 then do
    self~overrideCount += 1
    return rs
  end
  if statement~pos("UPDATE ssc_branch SET classification='INTENTIONAL'") > 0 then do
    self~branchClass = "INTENTIONAL"
    if statement~pos("ACCEPT_NON_CONFLICTING") > 0 then self~branchPolicy = "ACCEPT_NON_CONFLICTING"
    else self~branchPolicy = "REJECT_NON_CONFLICTING"
    return rs
  end
  if statement~pos("INSERT INTO ssc_branch_protection") > 0 then do
    p=.directory~new
    if statement~pos("'METHOD'") > 0 then p["scope_kind"]="METHOD"
    else if statement~pos("'CLASS'") > 0 then p["scope_kind"]="CLASS"
    else if statement~pos("'FILE'") > 0 then p["scope_kind"]="FILE"
    else if statement~pos("'MODULE'") > 0 then p["scope_kind"]="MODULE"
    else p["scope_kind"]="ATTRIBUTE"
    parse var statement . "VALUES ('" . "','" . "','" scopeId "','" .
    -- Easier deterministic IDs for the test cases.
    if p["scope_kind"]="METHOD" then p["scope_id"]="oorexx://family/Family/method/formatOutput"
    else if p["scope_kind"]="CLASS" then p["scope_id"]="oorexx://family/Family"
    self~protections~append(p)
    return rs
  end
  if statement~pos("FROM ssc_branch_protection") > 0 then do
    do p over self~protections
      rs~rows~append(p)
    end
    return rs
  end
  if statement~pos("FROM ssc_branch WHERE module_id=") > 0 then do
    row=.directory~new; row["branch_id"]="br-1"; row["classification"]=self~branchClass; row["upstream_policy"]=self~branchPolicy; row["status"]="OPEN"; row["base_deployment_id"]="dep-10"; rs~rows~append(row); return rs
  end
  if statement~pos("FROM ssc_branch WHERE branch_id=") > 0 then do
    row=.directory~new; row["branch_id"]="br-1"; row["module_id"]="family"; row["parent_branch_id"]=""; row["base_deployment_id"]="dep-10"; row["classification"]=self~branchClass; row["upstream_policy"]=self~branchPolicy; row["status"]="OPEN"; row["created_at"]=""; row["created_by"]=""; row["confirmed_at"]=""; row["confirmed_by"]=""; rs~rows~append(row); return rs
  end
  return rs

::requires "NoSQLServer.cls"
::requires "../src/SemanticSourceBranchService.cls"

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
