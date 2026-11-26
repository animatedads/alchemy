/* Native command-line stub game and replay runner. */
parse arg operation arg1 arg2 arg3
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
initial = diplomacyInitialUnits(board,'data/initial-1901.source')
ownership = judge~initialOwnership
if operation == 'run' then do
  mode = arg1~upper
  seed = arg2
  out = arg3
  config = .DiplomacyGameConfig~load('data/game.conf')
  source = .DiplomacyStubSource~new(board,seed,mode)
end
else if operation == 'replay' then do
  original = arg1
  out = arg2
  source = .DiplomacyReplaySource~new(original)
  config = source~config
  seed = source~seed
end
else do
  say 'Usage: rexx tools/game.rex run HOLD|RANDOM seed new-log'
  say '       rexx tools/game.rex replay original-log new-log'
  exit 2
end
if out == '' then exit 2
if .stream~new(out)~query('EXISTS') \== '' then do
  say 'Refusing to replace an existing journal:' out
  exit 2
end
journal = .DiplomacyGameJournal~new(out,.true)
game = .DiplomacyGame~new(board,judge,config,initial,ownership,source,journal,seed)
status = game~run
say 'Game:' status game~finishReason 'winner:' game~winner 'year:' game~year 'phases:' game~phaseCount 'calls:' game~callCount 'invalid:' game~invalidCount
if status \== 'FINISHED' then exit 1
if operation == 'replay' then do
  if \diplomacySameJournal(original,out) then do
    say 'Replay journal differs'
    exit 1
  end
  say 'PASS byte-identical replay'
end
exit 0
::requires 'DiplomacyGame.cls'
::requires 'DiplomacyReplaySource.cls'
::requires 'DiplomacyStubSource.cls'
