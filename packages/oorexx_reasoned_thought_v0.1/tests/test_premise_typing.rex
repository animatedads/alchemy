/* Reasoned Thought qualification 17: descriptive/normative/definitional premise
 * typing (Sonnet #3). Adversarial: each case FAILS against a degenerate operator.
 *   - an always-WELL_TYPED operator fails IS1, OI1, THK1 (misses the is/ought smuggle);
 *   - an always-IS_OUGHT_GAP operator fails WT1 (false positive once a bridge is added);
 *   - an operator that tags a thick concept as one type fails THK1 (untaggable) / THK2.
 * Scope ceiling (Sonnet #4): typing never says the conclusion is true.
 *
 * Architecture: Tom Dyer. Coding & test: Claude (Opus 4.8). Pure ooRexx 5.3.
 */
signal on syntax name onSyntax

/* IS1: a normative conclusion drawn from purely descriptive premises => IS_OUGHT_GAP */
a = .ArgumentTyping~new
a~clause('p1','the return happened in 2024','DESCRIPTIVE')
a~clause('p2','no detention was recorded','DESCRIPTIVE')
a~clause('c1','therefore the claim ought to be refused','NORMATIVE')
a~argument('A1'); a~premise('A1','p1'); a~premise('A1','p2'); a~conclusion('A1','c1')
call check a~audit('A1')['classification']='IS_OUGHT_GAP', -
  "normative conclusion from descriptive premises alone is an is/ought gap"

/* WT1: add an explicit normative bridge premise => the same conclusion is WELL_TYPED */
a~clause('p3','a claimant who faces persecution should not be refused','NORMATIVE')
a~argument('A2'); a~premise('A2','p1'); a~premise('A2','p3'); a~conclusion('A2','c1')
call check a~audit('A2')['classification']='WELL_TYPED', -
  "once a normative premise bridges, the normative conclusion is licensed"

/* OI1: a descriptive conclusion resting only on normative premises => OUGHT_IS_GAP */
a~clause('n1','everyone ought to be believed','NORMATIVE')
a~clause('d1','therefore the account is internally consistent','DESCRIPTIVE')
a~argument('A3'); a~premise('A3','n1'); a~conclusion('A3','d1')
call check a~audit('A3')['classification']='OUGHT_IS_GAP', -
  "descriptive conclusion from normative premises alone is an ought/is gap"

/* THK1: a THICK concept ('credible') used WHOLE as a premise => UNTAGGABLE_PREMISE */
a~clause('thick','the applicant is credible','THICK')
a~clause('c2','therefore the claim ought to be accepted','NORMATIVE')
a~argument('A4'); a~premise('A4','thick'); a~conclusion('A4','c2')
r4 = a~audit('A4')
call check r4['classification']='UNTAGGABLE_PREMISE' & r4['untaggable'][1]='thick', -
  "a thick descriptive+normative concept used whole is untaggable, named explicitly"

/* THK2: DECOMPOSE 'credible' into its descriptive + normative parts (not rewrite);
         the normative part then bridges the normative conclusion => WELL_TYPED */
a~decompose('thick','cred_desc','the account is internally consistent', -
                     'cred_norm','consistency of this kind should be believed')
a~argument('A5'); a~premise('A5','cred_desc'); a~premise('A5','cred_norm'); a~conclusion('A5','c2')
call check a~audit('A5')['classification']='WELL_TYPED', -
  "decomposing the thick concept into typed parts (not rewriting) licenses the argument"

/* feeds #5: the descriptive and normative parts are now separately typed clauses */
call check a~audit('A5')['untaggable']~items=0, -
  "after decomposition the argument has no untaggable clause - each part is testable on its own"

/* CEIL: typing never certifies the conclusion true */
call check a~audit('A2')['validatedTruth']=.false & a~audit('A2')['scope']='ARGUMENT_TYPING_ONLY', -
  "typing reports structure only - it never establishes the conclusion is true"

say ""
say "PREMISE TYPING: PASS (" || checks || " checks)"
say "is/ought and ought/is gaps caught; thick concepts decomposed, not rewritten; no truth verdict."
exit 0

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok == 1 | ok == .true then do; say "PASS" label; return; end
  say "FAIL" label
  exit 1
onSyntax:
  co = condition("O")
  say "SYNTAX rc=" || rc "line" sigl":" condition("D")
  if co \== .nil, co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say "  A=" || e; end
  exit 1
::requires "PremiseTyping.cls"
