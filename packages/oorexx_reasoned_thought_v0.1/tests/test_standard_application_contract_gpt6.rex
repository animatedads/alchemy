/* Owner-side contract and attack vectors; does not replace Claude's adversarial fixture. */
signal on syntax name onSyntax
checks = 0
call testExisting
call testComparability
call testMissing
call testLowerWorse
say 'OWNER CONTRACT PASS:' checks 'checks'
exit 0

testExisting: procedure expose checks
 a = .StandardApplicationAudit~new
 a~standard('S','DISQUALIFY','problem')
 a~applied('S','A',2,'REJECTED'); a~applied('S','B',2,'ACCEPTED')
 r=a~audit('S')
 call check r['classification']='DISPARATE_TREATMENT','equal severity opposite disposition'
 call check r['pairs']~items=1,'names pair'
 call check r['validatedTruth']=.false,'scope ceiling'
 b = .StandardApplicationAudit~new
 b~standard('B','DISQUALIFY','problem')
 b~applied('B','A',3,'REJECTED');b~applied('B','B',1,'ACCEPTED')
 call check b~audit('B')['classification']='CONSISTENT_APPLICATION','worse problem rejected correctly'
 t=.StandardApplicationAudit~new
 t~standard('T','THRESHOLD','evidence',4)
 t~selfMaterial('T',3)
 call check t~audit('T')['classification']='UNMEETABLE_BAR','existing threshold API contract'
 call check t~audit('T')['validatedTruth']=.false,'threshold never proves merits'
 return

testComparability: procedure expose checks
 a=.StandardApplicationAudit~new
 a~standard('S','DISQUALIFY','internal_consistency')
 a~applied('S','WITNESS',1,'REJECTED','internal_consistency','interview-v1')
 a~applied('S','FILE',4,'ACCEPTED','document_support','document-v1')
 r=a~audit('S')
 call check r['classification']='INDETERMINATE_COMPARABILITY','different dimension not disparity'
 call check r['pairs']~items=0,'uncomparable examples not false positive'
 call check r['incomparablePairs'][1]['reason']='DIMENSION_MISMATCH','dimension reason explicit'
 b=.StandardApplicationAudit~new
 b~standard('S','DISQUALIFY','internal_consistency')
 b~applied('S','P1',1,'REJECTED','internal_consistency','interview-v1')
 b~applied('S','P2',4,'ACCEPTED','internal_consistency','interview-v2')
 call check b~audit('S')['classification']='INDETERMINATE_COMPARABILITY','different measurement basis cannot compare'
 call check b~audit('S')['incomparablePairs'][1]['reason']='MEASUREMENT_BASIS_MISMATCH','basis reason explicit'
 return

testMissing: procedure expose checks
 a=.StandardApplicationAudit~new
 a~standard('S','DISQUALIFY','problem')
 call check a~audit('S')['classification']='INSUFFICIENT_APPLICATIONS','empty comparison is not consistent'
 a~applied('S','P1',1,'REJECTED')
 call check a~audit('S')['classification']='INSUFFICIENT_APPLICATIONS','one case cannot establish parity'
 a~applied('S','P2','UNKNOWN','ACCEPTED')
 call check a~audit('S')['classification']='INDETERMINATE_COMPARABILITY','unknown metric cannot be ordered as zero'
 t=.StandardApplicationAudit~new
 t~standard('T','THRESHOLD','evidence',4)
 call check t~audit('T')['classification']='INSUFFICIENT_SELF_MATERIAL','missing self tier is not evidence of equal treatment'
 return

testLowerWorse: procedure expose checks
 a=.StandardApplicationAudit~new
 a~standard('S','DISQUALIFY','integrity_score','','','LOWER_WORSE')
 a~applied('S','LOW',10,'REJECTED')
 a~applied('S','HIGH',5,'ACCEPTED')
 call check a~audit('S')['classification']='DISPARATE_TREATMENT','reverse severity dimension handled'
 b=.StandardApplicationAudit~new
 b~standard('S','DISQUALIFY','problem')
 b~applied('S','A',2,'REJECTED')
 b~applied('S','B',3,'ACCEPTED')
 b~applied('S','C','UNKNOWN','ACCEPTED')
 call check b~audit('S')['classification']='DISPARATE_TREATMENT','valid violating pair detected despite other missing values'
 call check b~audit('S')['incomparablePairs']~items>0,'partial coverage retained in report'
 return

check: procedure expose checks
 use arg ok, label
 checks += 1
 if ok==.true | ok==1 then do;say 'PASS' label;return;end
 say 'FAIL' label
 exit 1
onSyntax:
 say 'SYNTAX' sigl condition('D');exit 2
::requires 'StandardApplicationAudit.cls'
