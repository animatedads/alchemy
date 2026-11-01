/* Power SLAM: specific north-shore candidate at Jeffrey Street area.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01.
 * Landmark geometry unchanged from v0.4.
 * Position explicitly supplied by user; neither ground-level nor sight-line
 * occlusion is certified. Camera z=50 metres ASL, not 50m above ground.
 */
::requires 'SlamHarbourWharves.cls'

::class HarbourNorthShorePanorama public subclass HarbourWharfPanorama
::method init
  self~init:super
  self~sites['NORTH_SHORE'] = .array~of('North shore: Jeffrey Street area (candidate)', -33.848849, 151.213921)
::method candidateMeta
  m=.directory~new
  m['SITE']='NORTH_SHORE'
  m['LAT']=-33.848849
  m['LON']=151.213921
  m['ASL']=50
  m['SITE_PROVENANCE']='USER_SUPPLIED'
  m['LAND_MASK_QUALIFIED']=.false
  m['OCCLUSION_QUALIFIED']=.false
  m['SOURCE']='user-provided 2026-11-01; approximately 116m north of Jeffrey Street Wharf'
  return m
