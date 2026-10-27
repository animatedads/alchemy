parse arg root
if root=='' then exit 2
journal=.WireDeploymentAdmissionJournal~new(root)
body=.table~new
body['requestId']='request-1'
body['artifactDigest']='sha256:'||copies('a',64)
body['artifactRef']='storage-fabric://packages/notnotes'
body['target']='ed209h:staging'
r=journal~recordDisposition('delivery-1','ACCEPTED',body)
call check r~ok & r~value='ACCEPTED','admitted'
r=journal~recordDisposition('delivery-2','ACCEPTED',body)
call check r~ok & r~value='DUPLICATE_REQUEST','duplicate request'
conflict=.table~new
conflict['requestId']=body['requestId']
conflict['artifactDigest']='sha256:'||copies('f',64)
conflict['artifactRef']=body['artifactRef']
conflict['target']=body['target']
r=journal~recordDisposition('delivery-3','ACCEPTED',conflict)
call check r~ok & r~value='REJECTED_REQUEST_ID_CONFLICT','changed immutable digest'
journal=.WireDeploymentAdmissionJournal~new(root)
call check journal~pending~items=1,'restart pending'
call check journal~recordDisposition('delivery-2','ACCEPTED',body)~value='DUPLICATE_REQUEST','delivery replay'
r=journal~complete('request-1','PROBED_ACTIVE','evidence://qualified')
call check r~ok,'completion'
r=journal~complete('request-1','PROBED_ACTIVE','evidence://qualified')
call check r~ok & r~code='ALREADY_COMPLETED','completion repeat'
journal=.WireDeploymentAdmissionJournal~new(root)
call check journal~pending~items=0,'restart completed'
say 'PASS admission journal replay'
exit 0
check: procedure
 use strict arg okay,label
 if \okay then do
   say 'FAIL' label
   exit 1
 end
 say 'PASS' label
 return
::requires 'WireDeploymentAdmissionJournal.cls'
