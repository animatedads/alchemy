/* Preserve Source Editor candidate objects without reinterpretation. */
items=.array~new
first=.directory~new
first['label']='alpha'
second=.directory~new
second['label']='beta'
items~append(first)
items~append(second)
view=.CliUiCompletionPresentation~new(items)
if view~count<>2 then raise syntax 93.900 array('candidate count changed')
if view~candidate(1) \== first then raise syntax 93.900 array('candidate identity changed')
if view~select(2)<>.true then raise syntax 93.900 array('selection failed')
if view~current \== second then raise syntax 93.900 array('selected object changed')
if view~select(3)<>.false then raise syntax 93.900 array('invalid selection accepted')
if view~current \== second then raise syntax 93.900 array('invalid selection changed current')
view~replaceCandidates(.array~of(first))
if view~selected<>0 then raise syntax 93.900 array('stale selection retained')
if view~current<>.nil then raise syntax 93.900 array('stale candidate retained')
say 'PASS completion presentation preserves candidate identity and order'
::requires 'CliUiCompletionPresentation.cls'
