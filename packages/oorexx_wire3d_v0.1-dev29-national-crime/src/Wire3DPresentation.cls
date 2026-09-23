/* Wire3DPresentation.cls -- renderer-neutral semantic presentation/layout objects.
   Layouts describe meaning and composition. Renderers choose pixels and spatial mechanics. */

::class Wire3DUIElement public
::attribute kind get
::attribute elementId get
::attribute role get
::attribute value get
::attribute semanticRef get
::attribute properties get
::method init
  expose kind elementId role value semanticRef properties children
  use strict arg kind, elementId='', value='', role='', semanticRef=''
  properties=.directory~new; children=.array~new
::method property
  expose properties
  use strict arg name, value
  properties[name]=value; return self
::method add
  expose children
  use strict arg child
  children~append(child); return child
::method children
  expose children
  return children~copy
::method asDirectory
  expose kind elementId role value semanticRef properties children
  d=.directory~new; d['kind']=kind; d['id']=elementId; d['role']=role
  d['value']=value; d['semanticRef']=semanticRef; d['properties']=properties
  a=.array~new; do child over children; a~append(child~asDirectory); end; d['children']=a
  return d


/* Geographic presentation element. It describes a geographic context; the renderer
   chooses whether that becomes an embedded map, a spatial ground plane, or both. */
::class Wire3DMapElement subclass Wire3DUIElement public
::method init
  use strict arg elementId, geographicRef=''
  self~init:super('map',elementId,'','geographic-context',geographicRef)
::method at
  use strict arg latitude, longitude, zoom=16
  self~property('latitude',latitude); self~property('longitude',longitude); self~property('zoom',zoom)
  return self

::class Wire3DLayout public
::attribute name get
::attribute purpose get
::method init
  expose name purpose elements
  use strict arg name, purpose='inspect'
  if name='' then raise syntax 93.900 array ('Wire3D layout requires a name')
  elements=.array~new
::method add
  expose elements
  use strict arg element
  elements~append(element); return element
::method elements
  expose elements
  return elements~copy
::method asDirectory
  expose name purpose elements
  d=.directory~new; d['layout']=name; d['purpose']=purpose
  a=.array~new; do e over elements; a~append(e~asDirectory); end; d['elements']=a
  return d

::class Wire3DLayoutCollection public
::attribute name get
::method init
  expose name layouts
  use strict arg name='default'
  layouts=.directory~new
::method put
  expose layouts
  use strict arg layout
  layouts[layout~name~upper]=layout; return layout
::method at
  expose layouts
  use strict arg name
  if layouts~hasIndex(name~upper)==.false then return .nil
  return layouts[name~upper]
::method names
  expose layouts
  a=.array~new; do key over layouts; a~append(layouts[key]~name); end; return a

/* Registry entries deliberately retain class objects. This permits isA() matching
   without flattening ooRexx inheritance into renderer-side string tests. */
::class Wire3DPresentationRegistry public
::method init
  expose entries collections
  entries=.array~new; collections=.directory~new
::method addCollection
  expose collections
  use strict arg collection
  collections[collection~name~upper]=collection; return collection
::method for
  expose entries
  use strict arg domainClass, purpose, layout
  e=.directory~new; e['class']=domainClass; e['purpose']=purpose~upper; e['layout']=layout
  entries~append(e); return layout
::method resolve
  expose entries
  use strict arg object, purpose='inspect'
  p=purpose~upper
  do e over entries
    if e['purpose']==p, object~isA(e['class']) then return e['layout']
  end
  return .nil
::method present
  use strict arg object, purpose='inspect'
  layout=self~resolve(object,purpose)
  if layout==.nil then raise syntax 93.900 array ('No Wire3D presentation layout for requested object/purpose')
  return layout~present(object)

/* Reusable semantic layout for Person-like objects. The domain object remains
   authoritative; this class only projects fields/resources it is given access to. */
::class Wire3DPersonInfoLayout subclass Wire3DLayout public
::method init
  self~init:super('personInfo','inspect')
::method present
  use strict arg person
  d=.directory~new; d['layout']='personInfo'; d['purpose']='inspect'; d['kind']='personInfo'
  d['title']=person~surname person~givenNames
  d['headshot']=person~photographReference
  facts=.array~new
  call fact facts,'Surname',person~surname
  call fact facts,'Given names',person~givenNames
  call fact facts,'Occupation',person~occupation
  call fact facts,'Nationality',person~nationality
  d['facts']=facts
  return d
fact: procedure
  use arg facts,label,value
  f=.directory~new; f['label']=label; f['value']=value; facts~append(f); return

/* Transcripted media is intentionally duck-typed: it consumes the application's
   transcript/media protocol, not a duplicate Wire3D domain model. */
::class Wire3DTranscriptedMediaLayout subclass Wire3DLayout public
::method init
  self~init:super('transcriptedMedia','inspect')
::method present
  use strict arg tm
  d=.directory~new; d['layout']='transcriptedMedia'; d['purpose']='inspect'; d['kind']='transcriptedMedia'
  d['title']=tm~title
  media=.array~new
  do m over tm~media
    md=.directory~new; md['src']=m; md['mediaType']=mediaType(m); media~append(md)
  end
  d['media']=media
  transcripts=.array~new
  do t over tm~transcripts
    td=.directory~new; td['source']=t~source; td['text']=t~text
    speakers=.array~new
    personLabels=t~personLabels
    do personLabel over personLabels
      person=t~person(personLabel)
      sd=.directory~new; sd['label']=personLabel; sd['semanticRef']=personLabel
      sd['displayName']=person~surname person~givenNames
      sd['headshot']=person~photographReference
      speakers~append(sd)
    end
    td['speakers']=speakers; transcripts~append(td)
  end
  d['transcripts']=transcripts
  return d
mediaType: procedure
  use arg path
  p=path~lower
  if right(p,4)=='.mp4' | right(p,5)=='.webm' then return 'video'
  if right(p,4)=='.mp3' | right(p,4)=='.wav' | right(p,4)=='.ogg' then return 'audio'
  return 'media'

/* Current presentation context is process-local convenience, not application truth.
   It makes object~display3d practical while keeping the registry/layout authoritative. */
::class Wire3D public
::attribute current class
