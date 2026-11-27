/* Operator-only one-game-year live gate. Requires the estate SecretBroker
   v0.2 and its pinned AlchemyObject dependencies on REXX_PATH.
   Usage: rexx tools/live.rex profile rules-text prompt-dir game-id seed log
   This does not choose or authorize the runtime or spend. */
parse arg profilePath rulePath promptDir gameId seed out
if out == '' then exit 2
if .stream~new(out)~query('EXISTS') \== '' then exit 2
if .stream~new(out'.operator.log')~query('EXISTS') \== '' then exit 2
profile = .DiplomacyEngineProfile~load(profilePath)
if profile~provider == 'STUB' then exit 2
rules = readText(rulePath)
prompts = .directory~new
do power over .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
  prompts[power] = readText(promptDir'/'power'.txt')
end
mapping = .directory~new
mapping['diplomacy.haiku'] = 'ANTHROPIC_API_KEY'
mapping['diplomacy.sol'] = 'OPENAI_API_KEY'
reference = 'diplomacy.'||profile~provider~lower
broker = .SecretBroker~new(.MappedEnvironmentSecretProvider~new(mapping))
lease = broker~acquire(reference)
if \lease~ok then do
  say 'No runtime credential available from Secret Broker.'
  exit 2
end
lease~retire
transport = .DiplomacyCurlTransport~new(broker,reference)
engine = .DiplomacyEngine~new(profile,transport)
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
configured = .DiplomacyGameConfig~load('data/game.conf')
config = .DiplomacyGameConfig~new(configured~startYear,configured~startYear,configured~soloCentres,configured~pressRounds)
initial = diplomacyInitialUnits(board,'data/initial-1901.source')
journal = .DiplomacyGameJournal~new(out,.true)
source = .DiplomacyPlayer~new(engine,prompts,rules,journal,gameId,seed)
game = .DiplomacyGame~new(board,judge,config,initial,judge~initialOwnership,source,journal,seed)
status = game~run
say 'Game:' status 'order calls:' game~callCount 'press calls:' game~pressCallCount 'invalid:' game~invalidCount
say 'Inspect operator call statuses before accepting the live gate.'
exit (status \== 'FINISHED')
::routine readText
  use strict arg path
  src = .stream~new(path)
  if src~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read required text:' path)
  body = src~charin(1,src~chars)
  src~close
  return body
::requires 'DiplomacyGame.cls'
::requires 'DiplomacyPlayer.cls'
::requires 'DiplomacyEngine.cls'
::requires 'DiplomacyCurlTransport.cls'
::requires 'SecretBroker.cls'
