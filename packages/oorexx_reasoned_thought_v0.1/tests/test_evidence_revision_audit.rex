/* Independent ooRexx r13196 contract qualification for EvidenceCombiner.cls.
   Mock classes expose Claude's exact current Ground/Proposition method names.
   No validation of upstream evidence authenticity is claimed here. */
signal on syntax name failSyntax
checks = 0
c = .EvidenceCombiner~new
ra = .EvidenceRevisionAudit~new
old = .MockProposition~new("C1",2,4,.nil)
old~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL"))
weak = .MockProposition~new("C1",2,4,.nil)
weak~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL"))
weak~add(.MockGround~new("pressure","REBUT",1,"sourceB","GENERAL"))
r=ra~compare(old,weak,"CONTRA")
rAfter=r["after"]
call check r["classification"]="CLAIMED_FLIP_UNSUPPORTED" & rAfter["stance"]="PRO", -
 "social pressure below existing support cannot justify a claimed CONTRA flip"
r=ra~compare(old,weak)
call check r["classification"]="NO_REVISION", "weak pushback added but belief did not move"
strong = .MockProposition~new("C1",2,4,.nil)
strong~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL"))
strong~add(.MockGround~new("measurement","REBUT",3,"measurement01","GENERAL"))
r=ra~compare(old,strong,"CONTRA")
rAfter=r["after"]; rAdded=r["added"]
call check r["classification"]="ADMITTED_DELTA_BACKED" & rAfter["stance"]="CONTRA", -
 "higher-tier relevant rebuttal supports a policy-relative revision"
call check r["validatedTruth"] = .false & rAdded[1]="measurement", -
 "evidence-backed does not mean the measurement itself was authenticated"
spoof = .MockProposition~new("C1",2,4,.nil)
spoof~add(.MockGround~new("gbase","SUPPORT",4,"sourceA","GENERAL"))
r=ra~compare(old,spoof)
call check r["classification"]="MUTATED_GROUND_ID", -
 "silently mutating evidence priority under an existing ID fails closed"
removed = .MockProposition~new("C1",2,4,.nil)
r=ra~compare(old,removed)
call check r["classification"]="UNVERIFIED_REMOVAL", -
 "silent evidence deletion cannot justify a revision"
policy = .MockProposition~new("C1",3,4,.nil)
policy~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL"))
r=ra~compare(old,policy)
call check r["classification"]="POLICY_CHANGE_REQUIRES_REVIEW", -
 "a changed assertion floor cannot masquerade as new evidence"
/* Dogfood of the combiner itself: previous derivation omitted source origin and
   undercut link, producing the same audit text for distinct premises. */
a=.MockProposition~new("D",2,4,.nil)
a~add(.MockGround~new("same","SUPPORT",2,"source-one","GENERAL"))
b=.MockProposition~new("D",2,4,.nil)
b~add(.MockGround~new("same","SUPPORT",2,"source-two","GENERAL"))
da=c~evaluate(a); db=c~evaluate(b)
call check da["derivation"] \= db["derivation"], -
 "derivation transcript changes when the source identity changes"
/* Two candidate structures may evaluate to the same decision while carrying
   different links. Their replay evidence must not have an identical derivation. */
q1=.MockProposition~new("D2",2,4,.nil)
q1~add(.MockGround~new("x","SUPPORT",2,"src","GENERAL"))
q1~add(.MockGround~new("y","SUPPORT",2,"src2","GENERAL"))
q1~add(.MockGround~new("u","UNDERCUT",1,"src3","GENERAL","x"))
q2=.MockProposition~new("D2",2,4,.nil)
q2~add(.MockGround~new("x","SUPPORT",2,"src","GENERAL"))
q2~add(.MockGround~new("y","SUPPORT",2,"src2","GENERAL"))
q2~add(.MockGround~new("u","UNDERCUT",1,"src3","GENERAL","y"))
dq1=c~evaluate(q1); dq2=c~evaluate(q2)
call check dq1["derivation"] \= dq2["derivation"] & dq1["stance"] = dq2["stance"], -
 "same stance but different UNDERCUT edge yields different trace"
/* A scenario-specific premise must not cross into the real-world decision. */
worldOld=.MockProposition~new("WORLD",2,4,.nil)
worldOld~add(.MockGround~new("worldBase","SUPPORT",2,"speaker","GENERAL"))
worldNew=.MockProposition~new("WORLD",2,4,.nil)
worldNew~add(.MockGround~new("worldBase","SUPPORT",2,"speaker","GENERAL"))
worldNew~add(.MockGround~new("fiction","REBUT",3,"scenario","SCENARIO"))
wr=ra~compare(worldOld,worldNew,"CONTRA"); wd=wr["after"]
call check wr["classification"]="CLAIMED_FLIP_UNSUPPORTED" & wd["stance"]="PRO", -
 "fictional scenario evidence does not overturn an unrelated real-world claim"
worldScoped=.MockProposition~new("WORLD",2,4,.array~of("SCENARIO"))
worldScoped~add(.MockGround~new("worldBase","SUPPORT",2,"speaker","GENERAL"))
worldScoped~add(.MockGround~new("fiction","REBUT",3,"scenario","SCENARIO"))
scoped=c~evaluate(worldScoped)
call check scoped["stance"]="CONTRA" & scoped["status"]="REBUTTED", -
 "same evidence can defeat within the stated fictional scenario scope"

/* V0.3: a stable ID is not proof of stable proposition wording. */
renamed = .MockProposition~new("C1",2,4,.nil,"FISH ARE THE GREATEST")
renamed~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL"))
r = ra~compare(old,renamed)
call check r["classification"]="INVALID_COMPARISON" & r["statementChanged"] & r["identityVerified"], -
 "same ID and evidence but altered proposition text is NOT a warranted belief revision"

/* A scope admission-policy change with unchanged ground inventory is not new evidence. */
scopeBefore = .MockProposition~new("C1",2,4,.nil)
scopeBefore~add(.MockGround~new("base","SUPPORT",2,"uA","GENERAL"))
scopeBefore~add(.MockGround~new("fiction","REBUT",3,"uB","SCENARIO"))
scopeAfter = .MockProposition~new("C1",2,4,.array~of("SCENARIO"))
scopeAfter~add(.MockGround~new("base","SUPPORT",2,"uA","GENERAL"))
scopeAfter~add(.MockGround~new("fiction","REBUT",3,"uB","SCENARIO"))
r = ra~compare(scopeBefore,scopeAfter)
call check r["classification"]="POLICY_CHANGE_REQUIRES_REVIEW" & r["changedBindings"]~items=1, -
 "binding-policy change cannot masquerade as a new contrary ground"
call check r["bindingPolicyCoverage"]="OBSERVED_GROUND_SCOPES_ONLY", -
 "audit states the finite comparison coverage of accepted scopes"

/* Policy thresholds require review even if the conclusion did not change. */
floorOnly = .MockProposition~new("C1",1,4,.nil)
floorOnly~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL"))
r = ra~compare(old,floorOnly)
call check r["classification"]="POLICY_CHANGE_REQUIRES_REVIEW" & \r["changed"], -
 "changed assertion floor is a policy event even without a stance transition"

/* Editing editorial/warrant context under an immutable evidence ID is mutation. */
notedBefore = .MockProposition~new("C1",2,4,.nil)
notedBefore~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL","","alpha note"))
notedAfter = .MockProposition~new("C1",2,4,.nil)
notedAfter~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL","","beta note"))
r = ra~compare(notedBefore,notedAfter)
call check r["classification"]="MUTATED_GROUND_ID", -
 "changed source note under the same ground ID is quarantined"
/* No longer permit identical derivation certificates for changed claim/note
 * contents just because the final stance and ground IDs stayed the same. */
notedOldDecision = c~evaluate(notedBefore)
notedNewDecision = c~evaluate(notedAfter)
call check notedOldDecision["derivation"] \= notedNewDecision["derivation"] & -
 notedOldDecision["stance"] = notedNewDecision["stance"], -
 "changed note changes derivation content even when the result is unchanged"
renamedDecision = c~evaluate(renamed)
baseDecision = c~evaluate(old)
call check baseDecision["derivation"] \= renamedDecision["derivation"] & -
 baseDecision["stance"] = renamedDecision["stance"], -
 "changed exact claim text changes deterministic derivation content"
call check renamedDecision["derivationVersion"]="ordinal-evidence-combiner/0.3", -
 "derivation format version increments after changing bound transcript fields"

/* Control: same proposition, same grounds and policy => no revision. */
same = .MockProposition~new("C1",2,4,.nil)
same~add(.MockGround~new("gbase","SUPPORT",2,"sourceA","GENERAL"))
r = ra~compare(old,same)
call check r["classification"]="NO_REVISION" & r["identityVerified"] & \r["statementChanged"], -
 "unchanged proposition and inputs still produce NO_REVISION"
say "EVIDENCE REVISION AUDIT PASS ("checks" checks)"
exit 0
check:
 use arg ok,label
 checks += 1
 if ok then do; say "PASS" label; return; end
 say "FAIL" label
 exit 1
failSyntax:
 say "SYNTAX" rc sigl condition("D")
 exit 2

::class MockProposition public
::method init
 expose id af sf accept list statement
 use strict arg id,af,sf,accept,statement="BASE CLAIM"
 list=.array~new
::attribute id get
::attribute statement get
::method grounds
 expose list
 return list
::method add
 expose list
 use strict arg g
 g~targetId = self~id
 list~append(g)
::method assertFloorRank
 expose af
 return af
::method settleFloorRank
 expose sf
 return sf
::method acceptsBinding
 expose accept
 use strict arg b
 if b="GENERAL" then return .true
 if accept==.nil then return .false
 return accept~hasItem(b)

::class MockGround public
::method init
 expose id kind tier sourceUtterance binds undercutsGroundId targetId note
 use strict arg id,kind,tier,sourceUtterance,binds,undercutsGroundId="",note=""
 targetId = "P1"
::attribute id get
::attribute note get
::attribute kind get
::attribute tier get
::attribute sourceUtterance get
::attribute binds get
::attribute undercutsGroundId get
::attribute targetId
::requires "EvidenceRevisionAudit.cls"
