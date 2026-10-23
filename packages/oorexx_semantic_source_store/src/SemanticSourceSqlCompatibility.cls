/*
 * Semantic Source Control - SQL compatibility executor.
 *
 * Author: Claude (Opus 5.5), 2026-10-23.  Architecture: Tom Dyer.
 *
 * Wraps the provider executor chosen at the composition root.  Two behaviours
 * observed on NoSQLServer v0.79 (r13196) made the existing SSC readers unable to
 * run against a real database; they had only ever run against a stub:
 *
 *   1. "IN lists are not implemented" / "Unsupported predicate operator: IN".
 *      In SELECT statements only, a literal list  expr IN ('a','b')  outside any
 *      quoted literal is rewritten to  (expr='a' OR expr='b').  Sub-select lists,
 *      NOT IN, and every non-SELECT statement pass through unchanged, so stored
 *      source text containing "in (" can never be altered.
 *   2. Join results are keyed by qualified names ("r.object_id"), while the
 *      readers index rows by the bare column name.  Each qualified column is also
 *      exposed under its bare name when that name is not already present.
 *
 * Both are valid on a backend that already supports IN and bare names, so the
 * wrapper is safe to keep when the backend is upgraded.  All other messages are
 * forwarded to the wrapped executor unchanged.
 */

::class SemanticSourceSqlCompatibility public

::method init
  expose inner
  use strict arg providerExecutor
  if providerExecutor == .nil then raise syntax 88.900 array("providerExecutor is required")
  inner = providerExecutor

::method execute
  expose inner
  use strict arg statement
  rs = inner~execute(self~rewriteInLists(statement))
  if rs~status \= "SUCCESS" then return rs
  do row over rs~rows
    if \row~hasMethod("VALUES") then iterate
    names = row~values~allIndexes
    do name over names
      if name~pos(".") = 0 then iterate
      bare = name~substr(name~lastPos(".") + 1)
      if row~values[bare] == .nil then row[bare] = row~values[name]
    end
  end
  return rs

::method rewriteInLists
  use strict arg statement
  if statement~strip~left(6)~upper \= "SELECT" then return statement
  out = ""
  rest = statement
  do forever
    p = self~posOutsideQuotes(rest~upper, " IN (")
    if p = 0 then leave
    before = rest~left(p - 1)
    operandStart = before~lastPos(" ") + 1
    operand = before~substr(operandStart)
    listOpen = p + 4
    parsed = .nil
    if operand~upper \= "NOT" & operand \= "" then parsed = self~literalList(rest, listOpen + 1)
    if parsed == .nil then do
      out = out || rest~left(listOpen)
      rest = rest~substr(listOpen + 1)
      iterate
    end
    values = parsed["values"]
    if values~items = 0 then replacement = "(" || operand || "='__ssc_empty_in_list__')"
    else do
      replacement = "("
      do i = 1 to values~items
        if i > 1 then replacement = replacement || " OR "
        replacement = replacement || operand || "=" || values[i]
      end
      replacement = replacement || ")"
    end
    out = out || before~left(operandStart - 1) || replacement
    rest = rest~substr(parsed["close"] + 1)
  end
  return out || rest

/* First position of needle that is not inside a single-quoted SQL literal. */
::method posOutsideQuotes private
  use strict arg text, needle
  inQuote = .false
  n = needle~length
  do i = 1 to text~length
    ch = text~substr(i, 1)
    if ch = "'" then do
      inQuote = \inQuote
      iterate
    end
    if \inQuote then if text~substr(i, n) == needle then return i
  end
  return 0

/* Parses  'a','b'')c' )  starting at pos; returns .nil unless it is a pure literal list. */
::method literalList private
  use strict arg text, pos
  values = .array~new
  i = pos
  len = text~length
  do forever
    do while i <= len
      if text~substr(i, 1) \= " " then leave
      i += 1
    end
    if i > len then return .nil
    ch = text~substr(i, 1)
    if ch = ")" & values~items = 0 then leave
    if ch \= "'" then return .nil
    j = i + 1
    do forever
      if j > len then return .nil
      if text~substr(j, 1) = "'" then do
        if j < len then if text~substr(j + 1, 1) = "'" then do
          j += 2
          iterate
        end
        leave
      end
      j += 1
    end
    values~append(text~substr(i, j - i + 1))
    i = j + 1
    do while i <= len
      if text~substr(i, 1) \= " " then leave
      i += 1
    end
    if i > len then return .nil
    ch = text~substr(i, 1)
    if ch = ")" then leave
    if ch \= "," then return .nil
    i += 1
  end
  out = .directory~new
  out["values"] = values
  out["close"] = i
  return out

::method unknown
  expose inner
  use arg name, args
  return inner~sendWith(name, args)
