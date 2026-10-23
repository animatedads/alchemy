parse source . . here
root=filespec("L",here)||"/.."
dataRoot=value("TEST_DATA_ROOT",,"ENVIRONMENT")
if dataRoot="" then do; say "FAIL TEST_DATA_ROOT required"; exit 2; end
session=.InitechHelpDeskSession~new(dataRoot,"bob")
r=session~handle("please recalibrate the quantum stapler")
call assertEq "UNKNOWN",r["STATUS"],"unknown request remains unknown"
close=session~close
call assertEq "FAILURE",close["RATING"],"failed session TPS process rating"
review=session~app~byKey(close["REVIEW_KEY"])
call assertEq "FAILURE",review~field("TheRating")~string,"failure persisted in TPS review"
next=.InitechHelpDeskSession~new(dataRoot,"bob")
h=next~handle("show my failed Help Desk TPS processes")
call assertEq "SUCCESS",h["STATUS"],"later session discovers failed process"
call assertContains h["TEXT"],close["TPS_NUMBER"],"failed history contains prior process"
d=next~handle("what happened in " || close["TPS_NUMBER"])
call assertEq "SUCCESS",d["STATUS"],"failed process detail available"
call assertContains d["TEXT"],"FAILURE","failed process linked review returned"
say "PASS failed help-desk session writes and later exposes FAILURE TPS review"
exit 0
::routine assertEq
 use strict arg e,a,l
 if e \== a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed:" l); end
::routine assertContains
 use strict arg text,needle,label
 if pos(needle,text)=0 then do; say "FAIL" label "missing="needle; raise syntax 88.900 array("test assertion failed:" label); end
::requires "InitechHelpDesk.cls"
