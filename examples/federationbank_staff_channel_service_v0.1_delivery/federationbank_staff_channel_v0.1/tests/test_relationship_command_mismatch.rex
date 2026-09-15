request=.FBStaffChannelTestSupport~relationshipRequest("MISMATCH")
orig=request~command
/* Same relationship evidence, changed banking amount.  The channel must not
 * allow the already-authorised case decision to bless a different command. */
cmd=.FederationBankCommand~new(orig~commandId,orig~operation,orig~idempotencyKey,orig~customerId,orig~sourceAccountId,orig~targetAccountId,orig~currency,orig~amountMinor+1,orig~channel,orig~actorId,orig~requestedAt,orig~productCode,orig~accountId,orig~legalName,orig~dateOfBirth,orig~postcode,orig~addressCountry,orig~applicantResidence,orig~applicantDomicile,orig~applicantSegment,orig~applicantRiskTier,orig~details)
snap=.FederationBankStaffChannelCommandSnapshot~fromCommand(cmd)
tampered=.FederationBankStaffChannelRequest~new(request~requestId,request~workId,request~originClass,request~staffId,request~sessionId,request~branchId,request~deskId,snap,request~relationshipEvidence,request~requestedAt)~seal
ctx=.FBStaffChannelTestSupport~context("TELLER-04","TELLER","S-TEL")
e=.FederationBankStaffCorePolicyFixtures~engine
r=.FBStaffChannelTestSupport~orchestrator(e)~begin(tampered,.FBStaffChannelTestSupport~contexts(ctx))
.FBStaffChannelTestSupport~assertFalse(r~ok,"mismatched command rejected")
.FBStaffChannelTestSupport~assertEq("RELATIONSHIP_COMMAND_IDENTITY_MISMATCH",r~code,"identity binding")
.FBStaffChannelTestSupport~pass("relationship authority cannot be replayed onto altered banking action")
::requires "TestSupport.cls"
