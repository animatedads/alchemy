s=.InboxTestSupport
root=s~tempDir("inbox-dedupe")
repo=s~initRepo(root)
/* Same ID/tree appears on main and branch; branch copy is preferred and deduped. */
s~addSubmission(repo,"SAME","autobuild-submit/SAME","same")
/* Copy exact submission branch tree into main, preserving package tree. */
s~sh("git -C " || .AlchemyShell~quote(repo) || " fetch -q origin autobuild-submit/SAME")
s~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q main")
s~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q origin/autobuild-submit/SAME -- autobuild/inbox/SAME")
s~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m compatibility-main autobuild/inbox/SAME")
s~sh("git -C " || .AlchemyShell~quote(repo) || " push -q origin main")
scan=.AlchemyGitInbox~new~scan(repo)
s~assertEq(1,scan~candidates~items,"deduped count")
c=scan~candidates[1]
s~assertEq("SAME",c~submissionId,"same id")
s~assertTrue(\c~conflicted,"not conflicted")
s~assertTrue(c~aliases~items>=2,"aliases recorded")
say "PASS test_duplicate_dedupe"
exit 0
::requires "InboxTestSupport.cls"
::requires "AlchemyInbox.cls"
