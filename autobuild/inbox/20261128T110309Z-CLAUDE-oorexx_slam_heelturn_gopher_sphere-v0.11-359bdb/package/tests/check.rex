/* Validate the Heel Turn sphere documents under native ooRexx.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
dir = 'packs/slam-heelturn/'
names = .array~of('00-sphere-slam-heelturn.json=slam-heelturn=sphere', '01-access-policy-slam-heelturn-access.json=slam-heelturn-access=access-policy')
do a over .array~of('start', 'engine-face', 'testimony', 'tactics', 'prompt', 'press', 'truth', 'orders', 'qualification', 'continuation')
  names~append('02-article-slam-heelturn.'a'.json=slam-heelturn.'a'=article')
end
count = 0
do n over names
  parse var n file '=' id '=' kind
  if \check(dir || file, id, kind) then exit 3
  count += 1
end
if \check('profiles/slam-heelturn.json', 'slam-heelturn', 'profile') then exit 3
say 'PASS sphere document IDs and kinds:' count + 1
exit 0
::routine check
  use strict arg path, id, kind
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then do
    say 'missing' path
    return .false
  end
  doc = .json~fromJson(input~charin(1, input~chars))
  input~close
  if doc['id'] \== id | doc['kind'] \== kind then do
    say 'bad id or kind in' path
    return .false
  end
  return .true
::requires 'json.cls'
