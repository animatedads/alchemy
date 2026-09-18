#!/usr/bin/env rexx
/* Small deliberately inspectable application.
 * It contains ordinary subclassing plus multiple inheritance through mixins.
 * Clouseau observes it; the Storage bridge publishes a read-only FUSE tree.
 */

app=.ClouseauDemoApp~new
inspector=.InspectorClouseau~new
inspector~enableProbes(.true)
inspector~dontFollowPackage("REXX")
inspector~reportCollectionSizes(.true)
inspector~reportCollectionItems(.true)
inspector~reportVariable("*")
inspector~reportInheritanceMap(.true)
inspector~suppressInternalClassMethods(.true)
inspector~suppressMethodOutput("__INSPECTOR_CLOUSEAU*")
inspector~suppressObjectOutputForPath("root:.environment*")
inspector~createInspectionReportOnMethod("PRIORITYORDER","ADVANCE","*","*",.nil,.nil,"out/priority-advance")
inspector~attach("app",app)
inspector~attach("priorityOrder",app~priorityOrder)
inspector~attach("queue",app~queue)

bridge=.ClouseauStorageFuseBridge~new(inspector,"/live/demo")
g1=bridge~refresh
say "projection generation" g1
call show bridge,"/live/demo"
call show bridge,"/live/demo/objects"
call show bridge,"/live/demo/classes/PRIORITYORDER"
call show bridge,"/live/demo/classes/PRIORITYORDER/methods"

say ""
say "Before trigger:"
call showObjectValues bridge,"PRIORITYORDER"

say ""
say "Executing live application: priorityOrder~advance('PACKED')"
app~priorityOrder~bumpPriority(3)
app~priorityOrder~advance("PACKED")

g2=bridge~refresh
say "projection generation" g2
say "After trigger / refresh:"
call showObjectValues bridge,"PRIORITYORDER"

say ""
say "Method resolution evidence:"
call cat bridge,"/live/demo/classes/PRIORITYORDER/methods/ADVANCE/origin_kind"
call cat bridge,"/live/demo/classes/PRIORITYORDER/methods/ADVANCE/origin_class"
call cat bridge,"/live/demo/classes/PRIORITYORDER/methods/AUDITLABEL/origin_kind"
call cat bridge,"/live/demo/classes/PRIORITYORDER/methods/AUDITLABEL/origin_class"
call cat bridge,"/live/demo/classes/PRIORITYORDER/inheritance/lineage"

say ""
say "Trigger evidence count:"
call cat bridge,"/live/demo/triggers/.count"

say ""
say "PASS illuminating Clouseau -> Storage FUSE projection demo"
exit 0

show:
  use arg bridge,path
  say path||":"
  entries=bridge~listVirtual(path)
  if entries==.nil then do; say "  <not a directory>"; return; end
  do e over entries; say "  " e; end
  return

cat:
  use arg bridge,path
  say path "=" bridge~readVirtual(path)
  return

showObjectValues:
  use arg bridge,className
  objects=bridge~listVirtual("/live/demo/objects")
  if objects==.nil then return
  do oid over objects
    c=bridge~readVirtual("/live/demo/objects/"||oid||"/class")
    if c=className then do
      say "object" oid "class" c "path" bridge~readVirtual("/live/demo/objects/"||oid||"/path")
      attrs=bridge~listVirtual("/live/demo/objects/"||oid||"/attributes")
      if attrs<>.nil then do a over attrs
        if left(a,1)="." then iterate
        say "  " a "=" bridge~readVirtual("/live/demo/objects/"||oid||"/attributes/"||a||"/value")
      end
    end
  end
  return

::requires "InspectorClouseau.cls"
::requires "ClouseauStorageFuse.cls"

::class InspectorCooperative MIXINCLASS Object
::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName, source, scope="OBJECT"
  self~setMethod(probeName,source,scope)
  return .true
::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName)
  return .true

::class Auditable MIXINCLASS Object
::attribute auditTag
::method auditLabel
  expose auditTag
  return "audit:"||auditTag

::class Prioritised MIXINCLASS Object
::attribute priority
::method bumpPriority
  expose priority
  use strict arg amount=1
  priority=priority+amount
  return priority

::class WorkItem public inherit InspectorCooperative
::attribute id
::attribute state
::method init
  expose id state
  use strict arg idArg
  id=idArg; state="NEW"
::method advance
  expose state
  use strict arg nextState
  state=nextState
  return state
::method summary
  expose id state
  return id||":"||state

::class Order public subclass WorkItem inherit Auditable
::attribute customer
::attribute total
::method init
  expose customer total
  use strict arg idArg,customerArg,totalArg
  self~init:super(idArg)
  customer=customerArg; total=totalArg; self~auditTag="ORDER"
::method summary
  expose customer total
  return self~summary:super||":"||customer||":"||total

::class PriorityOrder public subclass Order inherit Prioritised
::method init
  use strict arg idArg,customerArg,totalArg,priorityArg=1
  self~init:super(idArg,customerArg,totalArg)
  self~priority=priorityArg
  self~auditTag="PRIORITY"
::method dispatchClass
  expose priority
  if priority>=5 then return "EXPEDITE"
  return "NORMAL"

::class ClouseauDemoApp public inherit InspectorCooperative
::attribute priorityOrder
::attribute queue
::method init
  expose priorityOrder queue
  priorityOrder=.PriorityOrder~new("ORD-471","Alice",125.50,4)
  queue=.array~of(priorityOrder)