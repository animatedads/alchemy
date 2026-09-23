/* WirePresentation.cls -- renderer-neutral presentation objects.
   Applications compose semantic views. Android/Web/Swing/Wire3D render them. */

::class WireSelector public
::attribute selectorId get
::attribute revision get
::attribute selected get
::method init
  expose selectorId revision selected observers
  use strict arg selectorId='selector'
  revision=0; selected=.nil; observers=.array~new
::method select
  expose selected revision observers
  use strict arg value
  selected=value; revision=revision+1
  do observer over observers
    observer~selectionChanged(self,value)
  end
  return value
::method observe
  expose observers
  use strict arg observer
  observers~append(observer); return observer

::class WireObjectSelector subclass WireSelector public

::class WireRangeSelector subclass WireSelector public
::attribute rangeStart get
::attribute rangeEnd get
::method init
  expose rangeStart rangeEnd
  use strict arg selectorId='range', rangeStart='', rangeEnd=''
  self~init:super(selectorId); self~setRange(rangeStart,rangeEnd)
::method setRange
  expose rangeStart rangeEnd
  use strict arg firstValue, lastValue
  rangeStart=firstValue; rangeEnd=lastValue; return self

::class WireTimeSelector subclass WireRangeSelector public
::attribute granularity get
::method init
  expose granularity
  use strict arg selectorId='time', rangeStart='', rangeEnd='', granularity='MONTH'
  self~init:super(selectorId,rangeStart,rangeEnd); granularity=granularity~upper
::method jumpTo
  use strict arg period
  return self~select(period)

::class WireDataFeed public
::attribute feedId get
::attribute source get
::attribute revision get
::method init
  expose feedId source revision
  use strict arg feedId='feed', source=.nil, revision=''
::method snapshot
  expose source
  return source

::class WireDataSeries public
::attribute seriesId get
::attribute source get
::attribute xRole get
::attribute yRole get
::method init
  expose seriesId source xRole yRole
  use strict arg seriesId='series', source=.nil, xRole='x', yRole='value'
::method points
  expose source
  if source==.nil then return .array~new
  return source~points

::class WirePresentationElement public
::attribute elementId get
::attribute elementKind get
::attribute source get
::attribute properties get
::method init
  expose elementId elementKind source properties selectors
  use strict arg elementKind, elementId='', source=.nil
  properties=.directory~new; selectors=.directory~new
::method property
  expose properties
  use strict arg name,value
  properties[name]=value; return self
::method selector
  expose selectors
  use strict arg role, selector
  selectors[role~upper]=selector; return self
::method selectorFor
  expose selectors
  use strict arg role
  if selectors~hasIndex(role~upper) then return selectors[role~upper]
  return .nil
::method semanticDescription
  expose elementId elementKind source properties selectors
  d=.directory~new; d['id']=elementId; d['kind']=elementKind; d['source']=source; d['properties']=properties
  sd=.directory~new; do role over selectors; sd[role]=selectors[role]~selectorId; end; d['selectors']=sd
  return d

::class WireGraph subclass WirePresentationElement public
::method init
  use strict arg elementId='graph', source=.nil
  self~init:super('graph',elementId,source)
::method objectSelector
  use strict arg selector
  self~selector('OBJECT',selector); return self

::class WireTimeGraph subclass WireGraph public
::method init
  use strict arg elementId='timeGraph', source=.nil
  self~init:super(elementId,source); self~property('graphRole','time-series')
::method timeSelector
  use strict arg selector
  self~selector('TIME',selector); return self
::method activateTime
  use strict arg period
  selector=self~selectorFor('TIME')
  if selector==.nil then return .nil
  return selector~jumpTo(period)

::class WireGeometryMap subclass WirePresentationElement public
::method init
  use strict arg elementId='geometryMap', source=.nil
  self~init:super('geometry-map',elementId,source)
::method objectSelector
  use strict arg selector
  self~selector('OBJECT',selector); return self
::method timeSelector
  use strict arg selector
  self~selector('TIME',selector); return self
::method selectObject
  use strict arg object
  selector=self~selectorFor('OBJECT')
  if selector==.nil then return .nil
  return selector~select(object)

::class WireFilterPanel subclass WirePresentationElement public
::attribute selection get
::method init
  expose selection
  use strict arg elementId='filters', catalog=.nil, selection=.nil
  self~init:super('filter-panel',elementId,catalog)

::class WireObjectDetails subclass WirePresentationElement public
::method init
  use strict arg elementId='details'
  self~init:super('object-details',elementId,.nil)
::method objectSelector
  use strict arg selector
  self~selector('OBJECT',selector); return self
::method currentObject
  selector=self~selectorFor('OBJECT')
  if selector==.nil then return .nil
  return selector~selected

::class WirePresentation public
::attribute presentationId get
::method init
  expose presentationId elements
  use strict arg presentationId='presentation'
  elements=.array~new
::method add
  expose elements
  use strict arg element
  elements~append(element); return element
::method elements
  expose elements
  return elements~copy
::method describe
  expose presentationId elements
  d=.directory~new; d['presentationId']=presentationId
  a=.array~new; do element over elements; a~append(element~semanticDescription); end; d['elements']=a
  return d
