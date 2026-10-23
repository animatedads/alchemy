/* Advisory-only pricing of a running job's continuation vs a hypothetical
 * approved route. This operation does not write accounts or decisions. */
parse arg state now
numeric digits 20
jobs=.CloudEconomicIO~read(state||'/mobility/current/running.tsv')
routes=.CloudEconomicIO~read(state||'/mobility/current/routes.tsv')
offers=.CloudEconomicIO~read(state||'/offers.tsv')
terms=.CloudEconomicIO~read(state||'/economics/current/terms.tsv')
planner=.CloudMigrationEconomics~new
say 'job'||'09'x||'status'||'09'x||'source'||'09'x||'destination'||'09'x|| ,
  'stay_usd'||'09'x||'move_usd'||'09'x||'savings_usd'||'09'x|| ,
  'downtime_s'||'09'x||'options'||'09'x||'evidence'
do job over jobs
  d=planner~compare(job,routes,offers,now,terms)
  evidence=d['reason']
  if d['status']='PAPER_MOVE_FAVORED' then do
    b=d['breakdown']
    evidence=evidence||';route='||b['route_ref']||';intention='||b['intention_ref']|| ,
      ';source_compute='||b['compute_source']||';dest_compute='||b['compute_dest']|| ,
      ';network='||b['transfer']||';io='||b['io']||';storage='||b['storage']|| ,
      ';startup='||b['startup']||';stop='||b['termination']|| ,
      ';fixed='||b['fixed']||';unavoidable='||b['unavoidable']
  end
  say d['job']||'09'x||d['status']||'09'x||job['source_id']||'09'x|| ,
    d['selected']||'09'x||d['baseline']||'09'x||d['cost']||'09'x|| ,
    d['savings']||'09'x||d['downtime_s']||'09'x|| ,
    d['options']~items||'09'x||evidence
end
exit 0
::requires 'CloudEconomics.cls'
::requires 'CloudMigrationEconomics.cls'
