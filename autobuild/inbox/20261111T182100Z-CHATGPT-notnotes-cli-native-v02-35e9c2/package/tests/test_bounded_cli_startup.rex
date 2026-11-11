/* Current NotNotes CLI bounded UI candidate: large population without full row projection. */
app=.FakeApp~new(1103)
ui=.MiniNotesCliUi~new(app)
call check 50,ui~screen~table~count,"first page bounded"
call check 1,app~calls,"one first page request"
call check 50,app~rowsProjected,"only visible rows projected"
call check "DOC-0001",ui~screen~table~row(1)[2][1],"first key"
ui~executeCommand("PAGE NEXT")
call check "DOC-0051",ui~screen~table~row(1)[2][1],"next page key"
ui~executeCommand("PAGE PREVIOUS")
call check "DOC-0001",ui~screen~table~row(1)[2][1],"previous page key"
ui~screen~table~select(50)
ui~semanticCommand("TABLE_NEXT")
call check "DOC-0051",app~selected~DocKey,"down crosses page"
ui~semanticCommand("TABLE_PREVIOUS")
call check "DOC-0050",app~selected~DocKey,"up crosses page"
ui~executeCommand("SELECT DOC-1002")
call check "DOC-1002",app~selected~DocKey,"select off page"
call check "DETAIL",ui~mode,"open selected detail"
ui~semanticCommand("RETURN")
ui~executeCommand("QUERY evidence")
call check 2,ui~screen~table~count,"filter list count"
ui~screen~table~select(2)
ui~semanticCommand("TABLE_NEXT")
call check 2,ui~screen~table~count,"filter does not escape"
ui~executeCommand("PAGE NEXT")
call check .true,ui~status~pos("Type DOCUMENTS first")>0,"page rejected in query"
ui~executeCommand("VIEW all")
ui~executeCommand("PAGE NEXT")
call check .true,ui~status~pos("Type DOCUMENTS first")>0,"page rejected in view"
ui~executeCommand("DOCUMENTS")
seen=.Set~new; pages=0; n=0
do forever
  pages += 1
  tab=ui~screen~table
  do k=1 to tab~count
    key=tab~row(k)[2][1]
    if seen~hasIndex(key) then raise syntax 93.900 array("duplicate key" key)
    seen~put(key)
    n += 1
  end
  if n>=1103 then leave
  ui~executeCommand("PAGE NEXT")
  if pages>23 then raise syntax 93.900 array("page loop")
end
call check 1103,n,"all unique keys"
call check 23,pages,"page count"
call check 3,ui~screen~table~count,"last partial page"
empty=.MiniNotesCliUi~new(.FakeApp~new(0))
call check 0,empty~screen~table~count,"empty result"
say "BOUNDED_CLI_STARTUP_PASS total=1103 page_size=50 pages=23 initial_rows=50"
exit 0
check: procedure
 use strict arg expected,actual,label
 if expected==actual then return
 say "FAIL" label "expected="expected "actual="actual
 exit 1
::class FakeDocument public
::method init; expose n; use strict arg n
::method DocKey; expose n; return "DOC-"||n~right(4,"0")
::method documentId; expose n; return "ID-"||n~right(4,"0")
::method formName; return "Alchemy Evidence"
::method Title; expose n; return "Evidence "||n
::method ApprovalStatus; return "DRAFT"
::method DependsOn; return ""
::method Amount; return 0
::method Risk; return "LOW"
::method Workflow; return ""
::method revision; return 1
::method fieldNames; return .Array~new
::class FakeApp public
::method init
 expose docs byId chosen calls projected
 use strict arg count
 docs=.Array~new; byId=.Directory~new; chosen=.nil; calls=0; projected=0
 do i=1 to count
  d=.FakeDocument~new(i)
  ignore=docs~append(d)
  byId[d~documentId]=d
 end
::method semanticCollectionRange
 expose docs calls projected
 use strict arg surface,start,count
 if surface\="documents" | count>50 then raise syntax 93.900 array("BAD_WINDOW")
 calls += 1
 p=.Directory~new
 p["TOTAL"]=docs~items
 rows=.Array~new
 last=start+count
 if last>docs~items then last=docs~items
 do i=start+1 to last
  d=docs[i]
  r=.Directory~new
  r["IDENTITY"]=d~documentId
  r["KEY"]=d~DocKey
  r["FORM"]=d~formName
  r["TITLE"]=d~Title
  r["STATUS"]=d~ApprovalStatus
  ignore=rows~append(r)
  projected += 1
 end
 p["ROWS"]=rows
 return p
::method allDocuments
 raise syntax 93.900 array("UNBOUNDED_UI_DOCUMENT_SCAN_FORBIDDEN")
::method query; expose docs; use strict arg text; return .Array~of(docs[1],docs[2])
::method viewDocuments; expose docs; use strict arg text; return .Array~of(docs[1],docs[2])
::method node; return self
::method document
 expose byId
 use strict arg identity
 if \byId~hasIndex(identity) then return .nil
 return byId[identity]
::method select
 expose docs chosen
 use strict arg key
 do d over docs
  if d~DocKey~upper=key~upper then do
   chosen=d
   return d
  end
 end
 return .nil
::method selected; expose chosen; return chosen
::method calls; expose calls; return calls
::method rowsProjected; expose projected; return projected
::method dependencyState; return "OK"
::method renderReferencesFor; return ""
::method renderSubviewsFor; return ""
::requires 'src/MiniNotesCliUi.cls'
