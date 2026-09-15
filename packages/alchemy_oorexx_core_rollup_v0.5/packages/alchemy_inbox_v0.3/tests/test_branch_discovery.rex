s=.InboxTestSupport
root=s~tempDir("inbox-branch")
repo=s~initRepo(root)
/* Old marker is accepted-main history and has a terminal receipt. */
s~addMainSubmission(repo,"OLD","old")
s~addReceipt(repo,"OLD")
/* New branch inherits OLD but adds only NEW. */
s~addSubmission(repo,"NEW","autobuild-submit/NEW","new")
scan=.AlchemyGitInbox~new~scan(repo)
s~assertEq(1,scan~candidates~items,"pending count")
c=scan~candidates[1]
s~assertEq("NEW",c~submissionId,"new candidate")
s~assertTrue(c~sourceRef~pos("autobuild-submit/NEW")>0,"branch source")
s~assertEq(1,scan~suppressedReceipts~items,"receipt suppressed once")
say "PASS test_branch_discovery"
exit 0
::requires "InboxTestSupport.cls"
::requires "AlchemyInbox.cls"
