/* Read-only, non-booking comparison; shares exactly the tick cost engine. */
parse arg root now
if root='' then exit 2
numeric digits 20
offers=.CloudEconomicIO~read(root||'/offers.tsv')
jobs=.CloudEconomicIO~read(root||'/jobs.tsv')
terms=.CloudEconomicIO~read(root||'/economics/current/terms.tsv')
profiles=.CloudEconomicIO~read(root||'/economics/current/profiles.tsv')
profileById=.directory~new
do p over profiles
  if p['id']=='' | profileById~hasIndex(p['id']) then ,
    raise syntax 93.900 array('Duplicate or empty workload economics profile')
  profileById[p['id']]=p
end
provenance=.CloudEconomicIO~read(root||'/economics/current/provenance.tsv')
do fact over provenance
  say 'ECONOMICS_PROVENANCE' fact['name'] fact['value']
end
engine=.CloudWholeJobEconomics~new
do job over jobs
  assessment=engine~evaluate(job,offers,now,terms,profileById)
  say 'JOB' job['id'] 'STATUS' assessment['status'] 'CANDIDATES' assessment['count']
  say 'BEST' assessment['selected'] 'USD' assessment['cost'] ,
      'UNMANAGED_USD' assessment['baseline'] 'SAVINGS_USD' assessment['savings']
  do option over assessment['candidates']
    say 'OPTION' option['ids'] 'USD' option['cost'] 'BILLED_S' option['billed_seconds'] ,
      'RUNTIME_S' option['duration_seconds']
    say 'BREAKDOWN' option['ids'] 'COMPUTE' option['compute'] ,
      'STARTUP' option['startup'] 'INGRESS' option['ingress'] ,
      'EGRESS' option['egress'] 'STORAGE' option['storage'] ,
      'IO' option['io'] 'FABRIC_COMPUTE' option['fabric_compute'] ,
      'FABRIC_NETWORK' option['fabric_network']
  end
end
::requires 'CloudWholeJobEconomics.cls'
