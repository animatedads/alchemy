/* Independent ooRexx r13196 contract qualification for EvidenceCombiner.cls.
   Mock classes expose Claude's exact current Ground/Proposition method names.
   No validation of upstream evidence authenticity is claimed here. */
signal on syntax name failSyntax
checks = 0
p = .MockProposition~new("P1",2,4,.array~of("PASSAGE_GENERATION"))
p~add(.MockGround~new("style","SUPPORT",1,"u0","GENERAL"))
c = .EvidenceCombiner~new
d = c~evaluate(p)
call check d["status"]="HINT" & \d["assertible"],"A stylistic hint not assertion"
p~add(.MockGround~new("bracket","SUPPORT",2,"u1","GENERAL"))
d=c~evaluate(p)
call check d["status"]="SUPPORTED" & d["assertible"],"B editorial testimony supports"
p~add(.MockGround~new("messageid","SUPPORT",4,"u2","MAIL_DOCUMENT"))
d=c~evaluate(p)
call check \d["settled"] & d["ineligible"]~hasItem("messageid"),"D message-id not passage provenance"
p~add(.MockGround~new("transcript","SUPPORT",4,"u3","PASSAGE_GENERATION"))
d=c~evaluate(p)
call check d["settled"],"E admitted passage-bound provenance (assuming upstream validator)"
orig=d["derivation"]
p~add(.MockGround~new("attack1","REBUT",1,"r1","GENERAL"))
p~add(.MockGround~new("attack2","REBUT",1,"r2","GENERAL"))
d=c~evaluate(p)
call check d["settled"] & d["rebutTier"]=1,"F higher-tier evidence defeats multiple low-tier contrary grounds"
p2=.MockProposition~new("P2",2,4,.nil)
p2~add(.MockGround~new("yes","SUPPORT",2,"s","GENERAL"))
p2~add(.MockGround~new("no","REBUT",2,"r","GENERAL"))
d=c~evaluate(p2)
call check d["status"]="DISPUTED" & \d["assertible"],"G equal tier is disputed"
p2~add(.MockGround~new("no-copy","REBUT",2,"r","GENERAL"))
d=c~evaluate(p2)
call check d["duplicates"]~hasItem("no-copy") & d["status"]="DISPUTED","G repeats from same origin deduplicated"
p3=.MockProposition~new("P3",2,4,.nil)
p3~add(.MockGround~new("base","SUPPORT",2,"s","GENERAL"))
p3~add(.MockGround~new("u1","UNDERCUT",2,"r1","GENERAL","u2"))
p3~add(.MockGround~new("u2","UNDERCUT",2,"r2","GENERAL","u1"))
d=c~evaluate(p3)
call check d["status"]="INVALID" & \d["settled"],"H cyclic undercuts fail closed"
p4=.MockProposition~new("P4",2,4,.nil)
p4~add(.MockGround~new("base","SUPPORT",1,"s","GENERAL"))
p4~add(.MockGround~new("u","UNDERCUT",2,"r","GENERAL","base"))
d=c~evaluate(p4)
call check d["defeated"]~hasItem("base"),"B higher-tier undercut defeats inference"
p5=.MockProposition~new("P5",2,4,.nil)
p5~add(.MockGround~new("base","SUPPORT",2,"s","GENERAL"))
p5~add(.MockGround~new("u","UNDERCUT",2,"r","GENERAL","base"))
d=c~evaluate(p5)
call check d["status"]="DISPUTED" & \d["settled"],"H equal-tier undercut quarantines inference"
p6=.MockProposition~new("P6",2,4,.nil)
p6~add(.MockGround~new("u","UNDERCUT",4,"r","GENERAL","missing"))
d=c~evaluate(p6)
call check d["status"]="INVALID","H missing ground fails closed"
p7=.MockProposition~new("P7",2,4,.nil)
p7~add(.MockGround~new("b","SUPPORT",2,"one","GENERAL"))
p7~add(.MockGround~new("a","REBUT",1,"two","GENERAL"))
v1=c~evaluate(p7)["derivation"]
p8=.MockProposition~new("P7",2,4,.nil)
p8~add(.MockGround~new("a","REBUT",1,"two","GENERAL"))
p8~add(.MockGround~new("b","SUPPORT",2,"one","GENERAL"))
v2=c~evaluate(p8)["derivation"]
call check v1==v2,"I input order invariant derivation"
say "EVIDENCE COMBINER CONTRACT PASS ("checks" checks)"
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
 expose id af sf accept list
 use strict arg id,af,sf,accept
 list=.array~new
::attribute id get
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
 expose id kind tier sourceUtterance binds undercutsGroundId targetId
 use strict arg id,kind,tier,sourceUtterance,binds,undercutsGroundId=""
 targetId = "P1"
::attribute id get
::attribute kind get
::attribute tier get
::attribute sourceUtterance get
::attribute binds get
::attribute undercutsGroundId get
::attribute targetId
::requires "EvidenceCombiner.cls"