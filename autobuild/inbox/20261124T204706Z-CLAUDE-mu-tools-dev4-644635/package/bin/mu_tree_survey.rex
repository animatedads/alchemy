/* mu_tree_survey.rex - classify every path on an MU against witness rules.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  23 Nov 2026.
 *
 *   rexx mu_tree_survey.rex RULES PATHLIST [DEPTH]
 *
 * PATHLIST is the output of `find / -xdev` (or plain `find /`) from the MU.
 * Exit code: 0 report written, 2 usage or input error.
 */
parse arg rulePath listPath depth .
if rulePath == '' | listPath == '' then do
  say 'usage: rexx mu_tree_survey.rex RULES PATHLIST [DEPTH]'
  exit 2
end
if depth == '' then depth = 3
.NewShellLog~setup(.true)
-- dev3: SIGNAL ON SYNTAX, not CATCH, so the survey runs on any ooRexx 5
signal on syntax name failed
survey = .MuTreeSurvey~new
survey~loadRules(rulePath)
survey~survey(listPath, depth)
do line over survey~report
  say line
end
exit 0

failed:
  c = condition('O')
  detail = c~message
  if c~additional \== .nil, c~additional~items > 0 then detail = c~additional~makeString('L', ' ')
  .error~lineout('[mu_tree_survey] failed:' c~code detail)
  exit 2

::requires '../src/NewShellMuTree.cls'
