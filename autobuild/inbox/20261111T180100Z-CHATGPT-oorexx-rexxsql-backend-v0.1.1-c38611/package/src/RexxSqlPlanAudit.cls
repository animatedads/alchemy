/*
 * RexxSqlPlanAuditSession - a RexxSqlSqliteSession that records every statement whose SQLite
 * query plan scans a whole table (EXPLAIN QUERY PLAN detail starting "SCAN"). Diagnostic only:
 * it doubles the calls per statement. Use it to decide which secondary indexes a caller needs.
 * Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
 */
::class RexxSqlPlanAuditSession public subclass RexxSqlSqliteSession
::method open class
  use strict arg path, options = .nil
  return self~new(.RexxSqlSqliteBackend~new, path, options)
::method init
  expose scans
  scans = .directory~new
  forward class (super) continue
::method execute
  expose scans
  use strict arg statement
  verb = statement~strip~word(1)~upper
  if wordpos(verb, "SELECT UPDATE DELETE") > 0 then do
    plan = self~execute:super("EXPLAIN QUERY PLAN " || statement)
    if plan~status = "SUCCESS" then do row over plan~rows
      detail = row["detail"]
      if detail~upper~startsWith("SCAN") then do
        key = detail~strip
        n = scans[key]; if n == .nil then n = 0
        scans[key] = n + 1
        if \scans~hasIndex(key || " :: example") then scans[key || " :: example"] = statement~substr(1, min(200, statement~length))
      end
    end
  end
  forward class (super)
::method scans
  expose scans
  return scans
::method report
  expose scans
  out = .array~new
  do key over scans~allIndexes~sort
    if key~pos(" :: example") > 0 then iterate
    out~append(right(scans[key], 7) key)
    out~append("        e.g." scans[key || " :: example"])
  end
  return out
::requires "RexxSqlBackend.cls"
