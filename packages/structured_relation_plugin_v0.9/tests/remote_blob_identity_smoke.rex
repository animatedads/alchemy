say 'REMOTE BLOB IDENTITY SMOKE START'

unbound=.RemoteSourceFileRevision~new('example/repo','rev1','x.txt','', 'abc')
call assertEqual 'UNBOUND', unbound~blobVerificationState, 'empty blob starts unbound'
call assertEqual 'REVISION_PATH_ONLY', unbound~provenance['identityStrength'], 'empty blob is not blob-bound'
call assertTrue \unbound~verifyBlobIdentity, 'empty blob cannot verify'

claimed=.RemoteSourceFileRevision~new('example/repo','rev1','x.txt','f2ba8f84ab5c1bce84a7b441cb1959cfc7093b7f', 'abc')
call assertEqual 'CLAIMED', claimed~blobVerificationState, 'supplied blob starts claimed'
call assertEqual 'GIT_BLOB_CLAIMED', claimed~provenance['identityStrength'], 'claim is not verification'
call assertTrue claimed~verifyBlobIdentity, 'matching Git blob verifies'
call assertEqual 'VERIFIED', claimed~blobVerificationState, 'matching blob verified state'
call assertEqual 'f2ba8f84ab5c1bce84a7b441cb1959cfc7093b7f', claimed~computedBlobSha, 'computed Git blob identity retained'
call assertEqual 'GIT_BLOB_BOUND', claimed~provenance['identityStrength'], 'verified blob becomes bound'

mismatch=.RemoteSourceFileRevision~new('example/repo','rev1','x.txt','0000000000000000000000000000000000000000', 'abc')
call assertTrue \mismatch~verifyBlobIdentity, 'mismatching Git blob rejected'
call assertEqual 'MISMATCH', mismatch~blobVerificationState, 'mismatch retained explicitly'
call assertEqual 'GIT_BLOB_MISMATCH', mismatch~provenance['identityStrength'], 'mismatch cannot masquerade as bound'
call assertEqual 'f2ba8f84ab5c1bce84a7b441cb1959cfc7093b7f', mismatch~computedBlobSha, 'actual blob retained on mismatch'

change=.BitcoinCorePublicCorpus~semantic35688
base=change~beforeSymbol~sourceSpan~fileRevision
head=change~afterSymbol~sourceSpan~fileRevision
call assertEqual 'VERIFIED', base~blobVerificationState, 'Bitcoin base bytes verified'
call assertEqual 'GIT_BLOB_BOUND', base~provenance['identityStrength'], 'Bitcoin base strongly bound'
call assertEqual base~blobSha, base~computedBlobSha, 'Bitcoin base claim equals computed blob'
call assertEqual 'VERIFIED', head~blobVerificationState, 'Bitcoin head bytes verified'
call assertEqual 'GIT_BLOB_BOUND', head~provenance['identityStrength'], 'Bitcoin head strongly bound'
call assertEqual head~blobSha, head~computedBlobSha, 'Bitcoin head claim equals computed blob'

say 'REMOTE BLOB IDENTITY SMOKE: OK'
exit 0

assertTrue: procedure
  use arg condition,label
  if \condition then do
    say 'ASSERT TRUE FAILED:' label
    exit 1
  end
return

assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do
    say 'ASSERT EQUAL FAILED:' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
return

::requires '../src/BitcoinCorePublicCorpus.cls'
