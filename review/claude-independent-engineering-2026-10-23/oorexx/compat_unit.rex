/* Unit test: SemanticSourceSqlCompatibility rewrite. Claude (Opus 5.5). */
c = .SemanticSourceSqlCompatibility~new(.object~new)
call t "SELECT a FROM t WHERE o.id IN ('x','y') AND k IN ('A')", "SELECT a FROM t WHERE (o.id='x' OR o.id='y') AND (k='A')"
call t "SELECT a FROM t WHERE id IN ('it''s','b')", "SELECT a FROM t WHERE (id='it''s' OR id='b')"
call t "SELECT a FROM t WHERE id NOT IN ('x')", "SELECT a FROM t WHERE id NOT IN ('x')"
call t "SELECT a FROM t WHERE id IN (SELECT b FROM u)", "SELECT a FROM t WHERE id IN (SELECT b FROM u)"
call t "SELECT a FROM t WHERE v='if x IN (''a'')' AND id IN ('z')", "SELECT a FROM t WHERE v='if x IN (''a'')' AND (id='z')"
call t "INSERT INTO t (v) VALUES ('if x IN (''a'')')", "INSERT INTO t (v) VALUES ('if x IN (''a'')')"
call t "SELECT a FROM t WHERE id IN ()", "SELECT a FROM t WHERE (id='__ssc_empty_in_list__')"
say "COMPAT REWRITE UNIT: PASS" n
exit 0
t: use arg input, want
  if symbol("n") = "LIT" then n = 0
  n += 1
  got = c~rewriteInLists(input)
  if got \== want then do; say "FAIL" input; say "  got " got; say "  want" want; exit 1; end
  return
::requires "SemanticSourceSqlCompatibility.cls"
