world = .RYTAWorldState~new
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('CUSTOMER_ELIGIBLE', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true, 'PASSENGER_DECLARATION', 'DECLARED')
world~putKnown('IMMEDIATE_ACCESS', .true, 'POLICY', 'AUTHORITATIVE')
world~putKnown('GUARANTEED_CUSTODY', .false, 'BAG_POLICY', 'AUTHORITATIVE')

ryta = .VirtualRYTA~new
decisionRun = ryta~evaluate(world)
do line over decisionRun~render
  say line
end
exit 0

::requires '../VirtualRYTA.cls'
