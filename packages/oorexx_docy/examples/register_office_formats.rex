/* Extend the published format destinations for an existing DOCY fixture.
   This is a bootstrap/migration step only: direct mutation of output routes
   is NOT an event-plan transaction in DOCY/2 and must not be used for
   concurrent edits to a production graph.
*/
source=.DocyStore~open('alchemy_shared_graph.docy')
if source['report']~hasStops then do
  say source['report']~summary
  exit 1
end
graph=source['graph']
doc=graph~document('doc.grid-plan')
doc~outputs~append('alchemy_grid_plan.pdf')
doc~outputs~append('alchemy_grid_plan.odt')
.DocyStore~save(graph,'alchemy_shared_graph_office.docy')
plan=graph~planFactChange('grid.ed209f.address','213.255.246.55','source:machines','office output fanout probe')
if plan~impactCount \== 6 then do
  say 'FAIL: expected six output impacts, found' plan~impactCount
  exit 2
end
say 'PASS: a shared fact update impacts six registered outputs across three documents.'
say 'No change event was applied.'
exit 0
::requires 'docy_store.cls'
