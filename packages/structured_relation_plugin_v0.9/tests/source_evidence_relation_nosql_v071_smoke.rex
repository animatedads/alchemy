root = .NoSQLServerTestSupport~createBlankDatabase('source-evidence-v071')
fed = .FederatedDatabaseEngine~new(root)
corpus = .BitcoinCorePublicCorpus~build
provider = .SourceEvidenceRelationProvider~new(.DatabaseResult)
definition = provider~definePullRequestRelation('bitcoin_prs', corpus)
ignore = fed~addEngine(provider)

relation = provider~table('bitcoin_prs')
rows = relation~readRows
call assert rows~items = 3, 'three public corpus PRs'
call assert rows[1]~origin~isA(.GitHubPullRequestEvidence), 'row retains PR object'

r = fed~execute("SELECT number, title, author FROM bitcoin_prs WHERE number=35688")
call ok r
call assert r~rows~items = 1, 'PR predicate'
call assert r~rows[1]['author'] = 'l0rinc', 'PR author projection'
direct = .nil
do rr over rows
  if rr['number'] = 35688 then direct = rr
end
call assert direct \== .nil, 'direct rich PR row found'
fact = direct~fact('title')
call assert fact~source == corpus~pullRequest(35688), 'direct fact source is rich PR object'
call assert fact~isEvidenceBearing, 'direct fact evidence bearing'
call assert r~accessPath = 'SOURCE_EVIDENCE_RICH_PROJECTION', 'provider access path'

meta = fed~tableMetadata('bitcoin_prs')
call assert meta \== .nil, 'provider metadata'
call assert meta~columns~items = 8, 'metadata columns'

bad = fed~execute("UPDATE bitcoin_prs SET title='x' WHERE number=35688")
call assert bad~error = .Error~SQLUNSUPPORTED, 'public evidence relation read only'
ignore = .NoSQLServerTestSupport~removeDatabase(root)
say 'SOURCE EVIDENCE RELATION NOSQL V0.71 SMOKE: OK'
exit 0

ok: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say 'FAILED:' rs~status rs~error rs~message
    exit 1
  end
return .true

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say 'ASSERT FAILED:' message
    exit 1
  end
return .true

::requires 'NoSQLServer.cls'
::requires 'TestSupport.cls'
::requires '../src/BitcoinCorePublicCorpus.cls'
::requires '../src/SourceEvidenceRelationAdapter.cls'
