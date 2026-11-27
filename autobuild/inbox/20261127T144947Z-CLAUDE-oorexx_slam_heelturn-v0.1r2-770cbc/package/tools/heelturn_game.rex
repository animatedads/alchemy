/* heelturn_game.rex - run a game with Heel Turn SLAM in every seat.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Usage: rexx heelturn_game.rex DIPLOMACY_ROOT PROMPT_DIR END_YEAR SEED JOURNAL [LOG] [QUIET]
   PROMPT_DIR holds AUS.txt ... TUR.txt. The journal must not exist.
   HEELTURN_ROOT names the Heel Turn package (default .). */
parse arg droot pdir endYear seed journalPath logPath quiet
if journalPath == '' then do
  say 'usage: rexx heelturn_game.rex DIPLOMACY_ROOT PROMPT_DIR END_YEAR SEED JOURNAL [LOG] [QUIET]'
  exit 2
end
hroot = value('HEELTURN_ROOT', , 'ENVIRONMENT')
if hroot == '' then hroot = '.'
r = .HeelTurnGame~new~run(droot, hroot, pdir, endYear, seed, journalPath, logPath, quiet \== 'QUIET')
say 'HEELTURN_GAME|'r['STATUS']'|order_calls='r['ORDER_CALLS']'|press_calls='r['PRESS_CALLS']'|invalid='r['INVALID']'|seconds='r['SECONDS']
exit (r['STATUS'] \== 'FINISHED')
::requires 'HeelTurnGame.cls'
