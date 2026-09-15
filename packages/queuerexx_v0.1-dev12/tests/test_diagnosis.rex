call RxFuncAdd 'SysLoadFuncs', 'rexxutil', 'SysLoadFuncs'
call SysLoadFuncs
root = value('QREXX_DIAG_ROOT',, 'ENVIRONMENT')
if root == '' then do; say 'FAIL missing QREXX_DIAG_ROOT'; exit 1; end
store = .QueueStateStore~new(root)
service = .QueueDiagnosisService~new(store)

d = service~diagnose('ri')
if d['diagnosis_code'] \= .QueueDiagnosisKind~RUNNING_INTERRUPTED then do; say 'FAIL running+interrupted kind'; exit 1; end
if d['recommendation_code'] \= .QueueDiagnosisRecommendation~KEEP_RUNNING_ARCHIVE_STALE_DUPLICATE then do; say 'FAIL running+interrupted recommendation'; exit 1; end

d = service~diagnose('rp')
if d['diagnosis_code'] \= .QueueDiagnosisKind~RUNNING_POL_BLOCKED then do; say 'FAIL running+pol kind'; exit 1; end
if d['recommendation_code'] \= .QueueDiagnosisRecommendation~KEEP_RUNNING_ARCHIVE_STALE_DUPLICATE then do; say 'FAIL running+pol recommendation'; exit 1; end

d = service~diagnose('ip')
if d['diagnosis_code'] \= .QueueDiagnosisKind~INTERRUPTED_POL_BLOCKED then do; say 'FAIL interrupted+pol kind'; exit 1; end
if d['recommendation_code'] \= .QueueDiagnosisRecommendation~MANUAL_REVIEW then do; say 'FAIL interrupted+pol manual review'; exit 1; end

say 'PASS diagnosis duplicate classification'
exit 0
::requires "../src/QueueRexxDiagnosis.cls"
