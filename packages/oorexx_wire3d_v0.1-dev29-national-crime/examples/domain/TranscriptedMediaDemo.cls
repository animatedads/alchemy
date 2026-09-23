/* Small demonstration domain. These are application objects, not Wire3D classes. */
::class Transcript public
::attribute source get
::attribute text get
::method init
  expose source text people
  source=''; text=''; people=.directory~new
::method loadFile
  expose source text
  use strict arg source
  text=charin(source,1,chars(source)); call stream source,'c','close'; return self
::method setText
  expose text
  use strict arg text
  return self
::method assignPerson
  expose people
  use strict arg label, person
  people[label]=person; return person
::method person
  expose people
  use strict arg label
  if people~hasIndex(label)==.false then return .nil
  return people[label]
::method personLabels
  expose people
  a=.array~new; do personLabel over people; a~append(personLabel); end; return a

::class TranscriptedMedia public
::attribute title
::method init
  expose transcripts media title
  transcripts=.array~new; media=.array~new; title='TRANSCRIPTED MEDIA'
::method addTranscript
  expose transcripts
  use strict arg transcript
  transcripts~append(transcript); return transcript
::method addMedia
  expose media
  use strict arg mediaRef
  media~append(mediaRef); return mediaRef
::method transcripts
  expose transcripts
  return transcripts~copy
::method media
  expose media
  return media~copy
::method display3d
  if .Wire3D~current==.nil then raise syntax 93.900 array ('No current Wire3D presentation registry')
  return .Wire3D~current~present(self,'inspect')

::requires 'Wire3DAll.cls'
