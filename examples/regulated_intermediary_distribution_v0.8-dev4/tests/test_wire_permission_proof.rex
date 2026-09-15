ctx=.RIDWireSecurityPolicyFixtures~context("ADVISER","RID:ADVISER:REP-1",.true,.true)
entered=ctx~enter("WEB")
.RIDTestSupport~ok(entered,"access control entry")
.RIDTestSupport~assertTrue(entered~value~proved,"access control decision is cryptographically proved")
permitted=ctx~permit("RID.CASE:CASE-PROOF","RIDDISTRIBUTIONCASE","CASE.OPEN")
.RIDTestSupport~ok(permitted,"exact case method permission")
.RIDTestSupport~assertTrue(permitted~value~proved,"permission decision is cryptographically proved")
.RIDTestSupport~assertTrue(ctx~permissionDecisionRef<>"","permission proof reference exposed")
say "PASS RID carries cryptographically proved exact method/object permission decisions"
exit 0

::requires "TestSupport.cls"
::requires "RIDWireSecurityPolicyFixtures.cls"
