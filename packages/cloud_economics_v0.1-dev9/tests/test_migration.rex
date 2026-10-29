/* Native ooRexx tests for advisory-only incremental migration economics. */
numeric digits 20
base=arg(1)
running=.CloudEconomicIO~read(base||'/fixtures/mobility_running.tsv')
routes=.CloudEconomicIO~read(base||'/fixtures/mobility_routes.tsv')
offers=.CloudEconomicIO~read(base||'/fixtures/mobility_offers.tsv')
terms=.CloudEconomicIO~read(base||'/fixtures/mobility_terms.tsv')
originalOffers=.CloudEconomicIO~read(base||'/fixtures/offers.tsv')
originalTerms=.CloudEconomicIO~read(base||'/fixtures/economic_terms.tsv')
engine=.CloudMigrationEconomics~new
call assert engine~validateMobilityInputs(running,routes),'admission'
first=engine~compare(running[1],routes,offers,1791000000,terms)
call assert first['status']='PAPER_MOVE_FAVORED','beneficial move'
call assert first['selected']='oci-64','destination'
call assert first['baseline']>first['cost'],'incremental savings'
call assert first['savings']>0,'positive savings'
call assert first['options']~items=1,'one qualified alternative'
call assert first['downtime_s']>60 & first['downtime_s']<180,'transfer duration in seconds'
call assert first['breakdown']['transfer']>0,'nonzero egress/route costs'
call assert first['mode']='ADVISORY_PAPER_ONLY','no mutation intent'
second=engine~compare(running[2],routes,offers,1791000000,terms)
call assert second['status']='PAPER_STAY','nonmovable job'
call assert second['options']~items=0,'nonmovable does not admit route'
/* Low hourly rate can lose because of a whole-hour billing boundary. */
oldQuote=engine~compare(running[1],routes,originalOffers,1791000000,originalTerms)
call assert oldQuote['status']='PAPER_STAY','cheap hourly tariff loses due to billing quantum'
/* Recently-moved jobs must observe an anti-churn residence period. */
recent=running[1]~copy; recent['last_move_epoch']=1790999950
cooldown=engine~compare(recent,routes,offers,1791000000,terms)
call assert cooldown['status']='PAPER_STAY','minimum residence gate'
call assert cooldown['reason']='MINIMUM_RESIDENCE_TIME_NOT_REACHED','residence reason'
/* No capacity, no action even if another tariff is cheaper. */
noCapacity=offers[6]~copy; noCapacity['capacity']='0'
noCapacityOffers=.array~new
do quote over offers
  if quote['id']='oci-64' then noCapacityOffers~append(noCapacity)
  else noCapacityOffers~append(quote)
end
call assert engine~compare(running[1],routes,noCapacityOffers,1791000000,terms)['status']='PAPER_STAY','capacity veto'
/* High transfer rate reverses selection while preserving a costed option. */
expensive=routes[1]~copy
expensive['transfer_usd_gib']=9
single=.array~of(expensive)
third=engine~compare(running[1],single,offers,1791000000,terms)
call assert third['status']='PAPER_STAY','expensive transfer retains source'
call assert third['options'][1]['cost']>third['baseline'],'expensive alternative shown'
/* Restricting downtime, stale evidence, and residency must veto transfers. */
short=running[1]~copy; short['max_downtime_s']=1
call assert engine~compare(short,routes,offers,1791000000,terms)['status']='PAPER_STAY','downtime veto'
call assert engine~compare(running[1],routes,offers,1791000301,terms)['status']='PAPER_STAY','stale route veto'
wrong=running[1]~copy; wrong['jurisdiction']='FR'
call assert engine~compare(wrong,routes,offers,1791000000,terms)['status']='PAPER_STAY','jurisdiction veto'
/* Deadline expiring before either continuation must not claim savings. */
late=running[1]~copy; late['deadline_epoch']=1791000001
lateAns=engine~compare(late,routes,offers,1791000000,terms)
call assert lateAns['status']='PAPER_HOLD','neither option finishes in time'
/* Ongoing prepaid compute is an explicit incremental credit. */
prepaid=running[1]~copy; prepaid['source_prepaid_s']=7200
p=engine~compare(prepaid,routes,offers,1791000000,terms)
call assert p['status']='PAPER_STAY','sunk/source prepaid drives stay'
/* Stronger anti-churn thresholds can veto otherwise positive savings. */
threshold=running[1]~copy; threshold['min_saving_usd']=100
call assert engine~compare(threshold,routes,offers,1791000000,terms)['status']='PAPER_STAY','hysteresis'
/* Input rows cannot be mutated by the engine. */
call assert routes[1]['transfer_usd_gib']='0.01','route intact'
call assert running[1]['remaining_s']='7200','running job intact'
call assert offers[1]['rate']='1.00','offer intact'
say 'PASS migration marginal comparison, transfer costs, sunk spend, vetoes, deadlines, non-mutation'
exit 0
assert: procedure
  use strict arg test, label
  if test then return
  say 'FAIL' label
  exit 1
::requires 'CloudEconomics.cls'
::requires 'CloudMigrationEconomics.cls'
