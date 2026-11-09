"""Apply optional columnar SELECT hook to NoSQLServer.cls in a checkout.

Only accepts the exactly reviewed source snippet; otherwise refuses to edit.
The runtime remains 100% ooRexx. No Python runtime orchestration is introduced.
"""
from pathlib import Path
import sys

source = Path(sys.argv[1] if len(sys.argv) > 1 else 'src/NoSQLServer.cls')
original = source.read_text()
old = '''  relation = .SQLRelationDefinition~new(t~definition, alias)
  if predicate \\== .nil then do
    if \\self~normalizeSinglePredicate(predicate, relation) then return self~sqlFailure("Unknown or ambiguous WHERE column")
    queryResult = self~engine~selectWhere(tableName, predicate)
    if queryResult~status = .Error~SUCCESS then self~engine~queryPatternLog~record(tableName, predicate, queryResult~rowsScanned, queryResult~rows~items)
  end
  else queryResult = self~engine~selectAll(tableName)
  if queryResult~status \\= .Error~SUCCESS then return queryResult
'''
new = '''  relation = .SQLRelationDefinition~new(t~definition, alias)
  if predicate \\== .nil then do
    if \\self~normalizeSinglePredicate(predicate, relation) then return self~sqlFailure("Unknown or ambiguous WHERE column")
  end
  queryResult = .nil
  -- Optional top-level column projection, independent of physical provider.
  if self~engine~hasMethod("selectColumnar") then ,
    queryResult = self~engine~selectColumnar(tableName, predicate, projection, orderBy)
  if queryResult == .nil then do
    if predicate \\== .nil then queryResult = self~engine~selectWhere(tableName, predicate)
    else queryResult = self~engine~selectAll(tableName)
  end
  if predicate \\== .nil then do
    if queryResult~status = .Error~SUCCESS then self~engine~queryPatternLog~record(tableName, predicate, queryResult~rowsScanned, queryResult~rows~items)
  end
  if queryResult~status \\= .Error~SUCCESS then return queryResult
'''
if original.count(old) != 1:
    raise SystemExit('refusing patch: original SQL method is different or already patched')
source.write_text(original.replace(old, new, 1))
print('columnar pushdown hook installed in', source)
