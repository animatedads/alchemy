say 'ALGORITHM INPUT RELATION START'

schema = .AlgorithmSchema~new('SOURCE_ROWS')
schema~add('ROW_ID', 'TEXT', .false)
schema~add('SCORE', 'NUMBER', .false)
schema~add('FLAG', 'BOOLEAN', .false)

rowA = .directory~new
rowA['ROW_ID'] = 'A'
rowA['SCORE'] = 10
rowA['FLAG'] = .true
rowB = .directory~new
rowB['ROW_ID'] = 'B'
rowB['SCORE'] = -3
rowB['FLAG'] = .false

b1 = .AlgorithmInputRelationBuilder~new(schema)
call assert b1~addValues(rowA), 'add A'
call assert b1~addValues(rowB), 'add B'
s1 = b1~freeze('INPUT-1', 'SELECT ...', 'TEST')
call assert s1 \== .nil, 'freeze first bag'

b2 = .AlgorithmInputRelationBuilder~new(schema)
call assert b2~addValues(rowB), 'add B reversed'
call assert b2~addValues(rowA), 'add A reversed'
s2 = b2~freeze('INPUT-2', 'SELECT ...', 'TEST')
call assert s2 \== .nil, 'freeze second bag'
call assert s1~contentHash == s2~contentHash, 'unordered bag identity ignores row order'

/* Provenance does not contaminate content identity. */
bp = .AlgorithmInputRelationBuilder~new(schema)
call assert bp~addValues(rowA), 'provenance add A'
call assert bp~addValues(rowB), 'provenance add B'
sp = bp~freeze('CALLER-OID-DIFFERENT', 'SELECT entirely_different_query', 'OTHER_SOURCE')
call assert sp~contentHash == s1~contentHash, 'same typed bag has same content hash across provenance'
call assert sp~sourceQueryHash \== s1~sourceQueryHash, 'query provenance remains distinct'
call assert sp~sourceIdentity \== s1~sourceIdentity, 'source identity provenance remains distinct'
call assert s1~rows[1]~value('ROW_ID') == 'A', 'unordered provider row order canonicalised'
call assert s2~rows[1]~value('ROW_ID') == 'A', 'reversed input canonicalises same'

bo1 = .AlgorithmInputRelationBuilder~new(schema, 'SOURCE_ROWS', .AlgorithmInputRelationConstant~ORDERED)
call assert bo1~addValues(rowA), 'ordered add A'
call assert bo1~addValues(rowB), 'ordered add B'
so1 = bo1~freeze('ORDER-1', 'SELECT ... ORDER BY ...', 'TEST')
bo2 = .AlgorithmInputRelationBuilder~new(schema, 'SOURCE_ROWS', .AlgorithmInputRelationConstant~ORDERED)
call assert bo2~addValues(rowB), 'ordered reversed B'
call assert bo2~addValues(rowA), 'ordered reversed A'
so2 = bo2~freeze('ORDER-2', 'SELECT ... ORDER BY ...', 'TEST')
call assert so1~contentHash \== so2~contentHash, 'ordered relation identity includes row order'

/* Duplicate rows retain bag multiplicity. */
bd = .AlgorithmInputRelationBuilder~new(schema)
call assert bd~addValues(rowA), 'dup first'
call assert bd~addValues(rowA), 'dup second'
sd = bd~freeze('DUP-1', '', 'TEST')
call assert sd~rowCount = 2, 'duplicate rows retained'

/* The builder copied source values; later source mutation cannot alter snapshot. */
rowA['SCORE'] = 999999
call assert s1~rows[1]~value('SCORE') = 10, 'source mutation does not alter frozen input'
call assert \s1~rows[1]~hasMethod('PUT'), 'frozen row has no write method'

bad = .directory~new
bad['ROW_ID'] = 'BAD'
bad['SCORE'] = 'not-a-number'
bad['FLAG'] = .true
bb = .AlgorithmInputRelationBuilder~new(schema)
call assert \bb~addValues(bad), 'bad numeric input rejected'
call assert bb~errors~items > 0, 'bad input records validation error'

say 'hash:' s1~contentHash
say 'ALGORITHM INPUT RELATION: OK'
exit 0

assert: procedure
  use arg condition, message
  if condition then return .true
  say 'ASSERT FAILED:' message
  exit 1

::requires '../algorithm/AlgorithmInputRelation.cls'
