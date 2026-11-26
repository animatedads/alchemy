/* Validate required sphere documents under native ooRexx. */
paths = .array~of('packs/llm-diplomacy/00-sphere-llm-diplomacy.json','packs/llm-diplomacy/01-access-policy-llm-diplomacy-access.json','packs/llm-diplomacy/02-article-diplomacy.current.json','packs/llm-diplomacy/02-article-diplomacy.board-and-parser.json','packs/llm-diplomacy/02-article-diplomacy.competition.json','profiles/llm-diplomacy.json')
ids = .array~of('llm-diplomacy','llm-diplomacy-access','diplomacy.current','diplomacy.board-and-parser','diplomacy.competition','llm-diplomacy')
kinds = .array~of('sphere','access-policy','article','article','article','profile')
do i = 1 to paths~items
  input = .stream~new(paths[i])
  if input~open('READ') \== 'READY:' then exit 2
  doc = .json~fromJson(input~charin(1,input~chars))
  input~close
  if doc['id'] \== ids[i] then exit 3
  if doc['kind'] \== kinds[i] then exit 4
end
say 'PASS sphere document IDs and kinds:' paths~items
exit 0
::requires 'json.cls'
