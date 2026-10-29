/* Full qualification: 200k backing store -> filter-window pull -> ooRexx ->
 * JavaScript Alchemy dev23 -> QuickJS-NG 0.17 -> JS predicate -> ooRexx ->
 * filter window -> native TestRenderer. */
backing=.BackingStore~new(200000)
runtime=.AlchemyJavaScriptQuickJSRuntime~new(.true,"",128,1024,1000)
predicate=.WireQuickJSPredicate~new(runtime)
window=.FilterWindow~new(backing,100,predicate)
rows=window~next(100)
render=.WireNativeRenderer~new~render(rows)
call check 'engine',runtime~engineInfo,'quickjs-ng/0.17.0'
call check 'produced',rows~items,100
call check 'backingPulls',backing~pulls,8
call check 'backingTouched',backing~touched,800
call check 'predicateCalls',predicate~executions,793
call check 'candidatesSeen',window~candidatesSeen,793
call check 'upstreamNext',window~upstreamNext,793
call check 'visible',render['VISIBLE'],100
call check 'firstIdentity',render['FIRSTIDENTITY'],0
call check 'lastIdentity',render['LASTIDENTITY'],792
runtime~uninit
say 'wire-oorexx-javascript-alchemy-quickjs-filter=PASS'
exit 0
check: procedure
 use strict arg label,got,expected
 if got \== expected then do; say label '=FAIL got='got 'expected='expected; exit 1; end
 return

::class BackingStore
::method init; expose total pullCount touchCount; use strict arg total; pullCount=0;touchCount=0
::method count; expose total; return total
::method pulls; expose pullCount; return pullCount
::method touched; expose touchCount; return touchCount
::method range
 expose total pullCount touchCount
 use strict arg start,n
 pullCount+=1; rows=.array~new
 if start>=total then return rows
 last=start+n-1; if last>=total then last=total-1
 do id=start to last
   row=.directory~new; row['IDENTITY']=id; row['STABLEID']='INBOX|4242|'id; row['FROM']='sender'||(id//13)||'@example.com'; row['SUBJECT']='Message 'id
   rows~append(row); touchCount+=1
 end
 return rows

::class FilterWindow
::method init; expose source pullSize predicate nextOrd seen; use strict arg source,pullSize,predicate; nextOrd=0;seen=0
::method upstreamNext; expose nextOrd; return nextOrd
::method candidatesSeen; expose seen; return seen
::method next
 expose source pullSize predicate nextOrd seen
 use strict arg wanted
 out=.array~new
 do while out~items<wanted & nextOrd<source~count
   candidates=source~range(nextOrd,pullSize)
   if candidates~items=0 then leave
   do row over candidates
     nextOrd+=1; seen+=1
     if predicate~accept(row) then out~append(row)
     if out~items=wanted then leave
   end
 end
 return out

::class WireQuickJSPredicate
::method init; expose runtime executionCount; use strict arg runtime; executionCount=0
::method executions; expose executionCount; return executionCount
::method accept
 expose runtime executionCount
 use strict arg row
 executionCount+=1
 id=row['IDENTITY']; sender=row['FROM']
 source='(function(){const row={identity:'id',from:' || jsQuote(sender) || '}; return row.from.endsWith("@example.com") && (row.identity % 8) === 0;})()'
 return runtime~evaluate(source)

::class WireNativeRenderer
::method render external "LIBRARY wire_oorexx_renderer_package wire_render"

::routine jsQuote
 use strict arg s
 s=s~changestr('\\','\\\\')~changestr('"','\\"')
 return '"'s'"'

::requires 'AlchemyJavaScriptQuickJSRuntime.cls'
