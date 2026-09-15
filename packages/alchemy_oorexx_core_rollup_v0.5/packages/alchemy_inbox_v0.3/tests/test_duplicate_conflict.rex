s=.InboxTestSupport
root=s~tempDir("inbox-conflict")
repo=s~initRepo(root)
s~addSubmission(repo,"CLASH","chatgpt/a","one")
s~addSubmission(repo,"CLASH","chatgpt/b","two")
scan=.AlchemyGitInbox~new~scan(repo)
s~assertEq(1,scan~candidates~items,"conflict count")
c=scan~candidates[1]
s~assertTrue(c~conflicted,"conflict detected")
s~assertTrue(c~conflictMessage~pos("different package trees")>0,"conflict explanation")
say "PASS test_duplicate_conflict"
exit 0
::requires "InboxTestSupport.cls"
::requires "AlchemyInbox.cls"
