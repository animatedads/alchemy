/* Native eastern landmarks admission test */
c=.HarbourPtzAnchors~catalogue
if c~items<>7 then call fail 'count'
x=.HarbourPtzAnchors~find('BRADLEYS_HEAD_LIGHT')
if x['LAT']<>-33.853487 then call fail 'lighthouse lat'
if x['LON']<>151.246664 then call fail 'lighthouse lon'
if x['PHOTO_ASSOCIATION']<>'UNVERIFIED' then call fail 'photo'
x=.HarbourPtzAnchors~find('CAPTAIN_COOK_GRAVING_DOCK')
if x['KIND']<>'GARDEN_ISLAND_NAVAL_DOCK' then call fail 'dock type'
if x['LAT']<>-33.866406787364 then call fail 'dock latitude'
x=.HarbourPtzAnchors~find('CLIFFORD_RESIDENCES')
if x['LAT']<>'UNKNOWN' then call fail 'building geolocation'
if x['GEOGRAPHIC_POINT_STATUS']<>'NOT_GEOREGISTERED' then call fail 'not registered'
x=.HarbourPtzAnchors~find('MOSMAN_ROWERS')
if x['ROOF_ELEVATION']<>'UNKNOWN' then call fail 'roof'
if x['PHOTO_ASSOCIATION']<>'UNVERIFIED' then call fail 'image unverified'
x=.HarbourPtzAnchors~find('SOUTH_MOSMAN_WHARF')
if x['KIND']<>'MOSMAN_WHARF' then call fail 'wharf'
if x['PROVENANCE']<>'PUBLISHED_WHARF_LOCATION_APPROX' then call fail 'precision'
say 'PTZ GEOGRAPHIC ANCHORS PASS 12 checks'
exit 0
fail:
parse arg reason
say 'ANCHOR FAIL' reason
exit 2
::requires 'SlamHarbourPtzAnchors.cls'