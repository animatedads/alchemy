call addPath
/* Wire3D CrimeEnterprise application fixture.
   The supplied photographs are deliberately attached only to fictional SUBJECT ids.
   No identity or criminal allegation is inferred from a photograph. */
scene=.Wire3DScene~new('crime-enterprise-demo','SANDFORD / INVESTIGATION SPACE')
app=.Wire3DSpaceApp~new('crime-enterprise','crime-enterprise://demo','0.1')

names=.array~of('SUBJECT 01','SUBJECT 02','SUBJECT 03','SUBJECT 04','SUBJECT 05','SUBJECT 06','SUBJECT 07')
xs=.array~of(-5,-2.5,0,2.5,5,-1.5,2)
zs=.array~of(0,-1.5,0,-1.2,0,2,2.2)
people=.array~new; projections=.array~new

do i=1 to names~items
  p=.Person~new('SUBJECT',right(i,2,'0'))
  p~occupation='DEMO FIXTURE'
  p~nationality='UNASSIGNED'
  p~addRole('PERSON_OF_INTEREST')
  media=.MediaReference~new('PHOTOGRAPH','assets/people/subject-'right(i,2,'0')'.png')
  media~mediaDescription='Supplied demonstration headshot; identity deliberately unassigned'
  media~relatesTo=p
  p~photographReference='/resource/person/CE-'right(i,3,'0')'/headshot'
  people~append(p)
  key='subject-'right(i,2,'0')
  app~expose(key,p,'READ')
  rep=.Wire3DRepresentation~new('person',names[i],'person')
  pr=app~project(key,key,rep)~moveTo(xs[i],0,zs[i])~scaleTo(.72,1.05,.32)
  pr~describe('entityType','PERSON')
  pr~describe('displayName',names[i])
  pr~describe('role','PERSON OF INTEREST')
  pr~describe('status','DEMO / UNASSIGNED IDENTITY')
  card=.directory~new
  card['kind']='person'; card['title']=names[i]; card['subtitle']='PERSON / DEMONSTRATION RECORD'
  card['headshot']=p~photographReference
  details=.directory~new
  details['Reference']='CE-'right(i,3,'0')
  details['Role']='PERSON OF INTEREST'
  details['Identity']='UNASSIGNED'
  details['Authority']='READ'
  details['Map context']='55.82331, -4.43032'
  card['details']=details
  medias=.array~new; md=.directory~new; md['label']='HEADSHOT'; md['type']='PHOTOGRAPH'; md['src']=p~photographReference; medias~append(md); card['media']=medias
  card['links']=.array~new
  pr~describe('card',card)
  projections~append(pr)
end

/* Relationships are real domain Relationship objects first, spatial edges second. */
call relation 1,2,'KNOWN_CONTACT','HIGH'
call relation 2,3,'ASSOCIATE','MEDIUM'
call relation 3,4,'KNOWN_CONTACT','HIGH'
call relation 4,5,'ASSOCIATE','MEDIUM'
call relation 3,6,'KNOWN_CONTACT','HIGH'
call relation 3,7,'KNOWN_CONTACT','HIGH'
call relation 1,6,'ASSOCIATE','LOW'

/* Semantic presentation demo: same Person objects are referenced by the transcript. */
registry=.Wire3DPresentationRegistry~new
layouts=.Wire3DLayoutCollection~new('investigation')
personInfo=.Wire3DPersonInfoLayout~new
transcriptedMediaInfo=.Wire3DTranscriptedMediaLayout~new
layouts~put(personInfo); layouts~put(transcriptedMediaInfo); registry~addCollection(layouts)
registry~for(.Person,'inspect',personInfo)
registry~for(.TranscriptedMedia,'inspect',transcriptedMediaInfo)
.Wire3D~current=registry
transcript=.Transcript~new
transcript~setText('00:00:04  PERSON A: Where were you Tuesday evening?'||.endOfLine|| -
                   '00:00:08  PERSON B: I already told you.'||.endOfLine|| -
                   '00:00:12  PERSON A: Then tell me again.'||.endOfLine|| -
                   '00:00:17  PERSON B: I was nowhere near the location.')
transcript~assignPerson('PERSON A',people[1])
transcript~assignPerson('PERSON B',people[2])
tm=.TranscriptedMedia~new; tm~title='INTERVIEW / TRANSCRIPT 01'
tm~addTranscript(transcript); tm~addMedia('assets/demo-interview.wav')
presentation=tm~display3d

scene~add(app)
/* Scene snapshot flattens the mounted application children. */
snapshot=scene~snapshot
objects=.directory~new
do i=1 to projections~items; objects[projections[i]~spatialId]=projections[i]; end
objects[app~spatialId]=app

do nd over snapshot['nodes']
  if objects~hasIndex(nd['id']) then nd['modelMatrix']=.Wire3DMathsAdapter~columnMajor(.Wire3DMathsAdapter~transform(objects[nd['id']]~transform))
  else nd['modelMatrix']=.Wire3DMathsAdapter~columnMajor(.Wire3DMathsAdapter~transform(.Wire3DTransform~new))
end
camera=.Wire3DSpatialCamera~new(.Wire3DVector3~new(0,6,15),.Wire3DVector3~new(0,0,0))
cd=camera~asDirectory; cd['viewMatrix']=.Wire3DMathsAdapter~columnMajor(camera~viewTransform); snapshot['camera']=cd
contract=.directory~new; contract['matrixStorage']='COLUMN_MAJOR'; contract['vectorConvention']='COLUMN_VECTOR'; contract['clipConvention']='OPENGL'; contract['projectionAuthority']='VIEWPORT_ADAPTER'; contract['mathAuthority']='OOREXX_MATHS_V0.8'; snapshot['rendererContract']=contract
tracking=.Wire3DTrackingField~new('4A91C37D'); snapshot['trackingField']=tracking~asDirectory; snapshot['trackingField']['enabled']=.JSON~true; snapshot['trackingField']['applicationState']=.JSON~false
map=.directory~new; map['provider']='OPENSTREETMAP'; map['latitude']=55.82331; map['longitude']=-4.43032; map['zoom']=16; map['url']='https://www.openstreetmap.org/#map=16/55.82331/-4.43032'; map['embedUrl']='https://www.openstreetmap.org/export/embed.html?bbox=-4.44532%2C55.81531%2C-4.41532%2C55.83131&layer=mapnik&marker=55.82331%2C-4.43032'; map['attribution']='© OpenStreetMap contributors'; map['licenseUrl']='https://www.openstreetmap.org/copyright'; snapshot['mapContext']=map
snapshot['presentationWorkspace']=presentation
snapshot['layoutCollection']='investigation'
snapshot['fixtureNotice']='Photographs are demonstration resources with deliberately unassigned identities; no allegation is inferred from an image.'
json=.JSON~new~toJSON(snapshot)
out=value('WIRE3D_SCENE_OUT',,'ENVIRONMENT'); if out='' then out='web/scene.json'
call stream out,'c','open write replace'; call charout out,json; call stream out,'c','close'
say 'Wrote' out
exit 0

relation: procedure expose people projections scene
  use arg a,b,kind,confidence
  r=.Relationship~new(people[a],people[b],kind); r~confidence=confidence
  e=scene~connect(projections[a],projections[b],kind)~signal('active')
  call addLink projections[a], projections[b], kind, confidence
  call addLink projections[b], projections[a], kind, confidence
  return
addLink: procedure
  use arg from,to,kind,confidence
  card=from~metadata['card']; links=card['links']; l=.directory~new
  l['label']=to~representation~label; l['relation']=kind; l['confidence']=confidence; l['targetId']=to~spatialId
  links~append(l); return
addPath: procedure
  here=filespec('location',parse source . . src)
  call value 'REXX_PATH', here'../src:'here'domain:'value('REXX_PATH',,'ENVIRONMENT'),'ENVIRONMENT'
  return

::requires 'Wire3DAll.cls'
::requires 'CrimeEnterprise.cls'
::requires 'TranscriptedMediaDemo.cls'
