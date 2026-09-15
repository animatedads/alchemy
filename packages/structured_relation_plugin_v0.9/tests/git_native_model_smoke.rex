fixtureRoot = value('GIT_FIXTURE_ROOT',, 'ENVIRONMENT')
if fixtureRoot = '' then fixtureRoot = '/tmp/oorexx_git_fixture'
repo = .GitRepositoryContext~new(fixtureRoot, 'fixture/example', 'https://example.invalid/fixture.git')
head = repo~commit('HEAD')
call assertTrue head~sha~length >= 7, 'head sha'
call assertEqual 'Bob Perf', head~author~name, 'author preserved'
call assertEqual 'Merge Maintainer', head~committer~name, 'committer preserved'
call assertTrue head~authorDiffersFromCommitter, 'author/committer distinction'
call assertEqual 1, head~parents~items, 'parent preserved'
call assertTrue head~body~pos('empty-range') > 0, 'commit intent body preserved'
parentCommit = repo~commit(head~parents[1])
call assertEqual 'C', repo~fileRevision(parentCommit~sha, 'helper.c')~language, 'C source classification'
call assertEqual 'ASSEMBLY', repo~fileRevision(parentCommit~sha, 'fast.S')~language, 'assembly source classification'
changes = repo~changedFiles(head~sha)
call assertEqual 1, changes~items, 'changed file count'
call assertEqual 'crypto.cpp', changes[1]~newPath, 'changed path'
change = repo~hydrateChange(changes[1])
call assertTrue change~beforeRevision \== .nil, 'before revision retained'
call assertTrue change~afterRevision \== .nil, 'after revision retained'
call assertTrue change~beforeRevision~blobSha \== change~afterRevision~blobSha, 'before/after blob identities differ'
call assertTrue change~hunks~items >= 1, 'structured diff hunk'
removed = .nil; added = .nil
do h over change~hunks
  do dl over h~deletedLines
    if dl~text~pos('memcpy') > 0 then removed = dl
  end
  do al over h~addedLines
    if al~text~pos('std::copy') > 0 then added = al
  end
end
call assertTrue removed \== .nil, 'deleted memory operation retained'
call assertTrue added \== .nil, 'added memory operation retained'
call assertTrue removed~beforeSpan \== .nil, 'deleted line points to parent blob span'
call assertTrue added~afterSpan \== .nil, 'added line points to successor blob span'
call assertTrue removed~beforeSpan~fileRevision~blobSha \== added~afterSpan~fileRevision~blobSha, 'diff line provenance distinguishes revisions'
file = repo~fileRevision(head~sha, 'crypto.cpp')
call assertEqual 'C++', file~language, 'language'
span = file~lineSpan(2, 4)
call assertTrue span~lexicalValue~pos('std::copy') > 0, 'source span lexical code'
call assertEqual head~sha, span~commit~sha, 'span revision identity'
p = span~provenance
call assertEqual 'GIT_SOURCE_SPAN', p['kind'], 'span provenance kind'
call assertTrue p['path']~pos('crypto.cpp#L2-L4') > 0, 'span path'
say 'GIT NATIVE MODEL SMOKE: OK'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'ASSERT TRUE FAILED:' label
    exit 1
  end
return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say 'ASSERT EQUAL FAILED:' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
return

::requires '../src/GitNativeSource.cls'
