/* Derived from Claude's five public test-16 vectors, with two cutoff-specific additions.
 * A separate owner-side compatibility probe; does not modify Claude's fixture. */
signal on syntax name onSyntax
checks=0
m1=.StandardApplicationAudit~new; m1~standard('S','DISQUALIFY','problem')
m1~applied('S','A',2,'REJECTED'); m1~applied('S','B',2,'ACCEPTED')
m2=.StandardApplicationAudit~new; m2~standard('S','DISQUALIFY','problem')
m2~applied('S','B',2,'ACCEPTED'); m2~applied('S','A',2,'REJECTED')
call check m1~audit('S')['classification']=m2~audit('S')['classification'] & m1~audit('S')['classification']='DISPARATE_TREATMENT', 'order invariance on disparity'
c1=.StandardApplicationAudit~new; c1~standard('S','DISQUALIFY','problem')
c1~applied('S','A',2,'REJECTED'); c1~applied('S','B',2,'REJECTED')
c2=.StandardApplicationAudit~new; c2~standard('S','DISQUALIFY','problem')
c2~applied('S','B',2,'REJECTED'); c2~applied('S','A',2,'REJECTED')
call check c1~audit('S')['classification']=c2~audit('S')['classification'] & c1~audit('S')['classification']='CONSISTENT_APPLICATION', 'order invariance on consistent comparison'
a=.StandardApplicationAudit~new; a~standard('S','DISQUALIFY','problem')
a~applied('S','OWN_SYSTEM',2,'REJECTED'); a~applied('S','COMPETITOR',2,'ACCEPTED')
b=.StandardApplicationAudit~new; b~standard('S','DISQUALIFY','problem')
b~applied('S','COMPETITOR',2,'REJECTED'); b~applied('S','OWN_SYSTEM',2,'ACCEPTED')
call check a~audit('S')['classification']=b~audit('S')['classification'] & a~audit('S')['classification']='DISPARATE_TREATMENT', 'label swap disparity'
c=.StandardApplicationAudit~new; c~standard('S','DISQUALIFY','problem')
c~applied('S','P',3,'REJECTED'); c~applied('S','Q',1,'ACCEPTED')
d=.StandardApplicationAudit~new; d~standard('S','DISQUALIFY','problem')
d~applied('S','Q',3,'REJECTED'); d~applied('S','P',1,'ACCEPTED')
call check c~audit('S')['classification']=d~audit('S')['classification'] & c~audit('S')['classification']='CONSISTENT_APPLICATION', 'label swap justified differences'
e=.StandardApplicationAudit~new; e~standard('S','DISQUALIFY','problem')
e~applied('S','A',2,'REJECTED'); e~applied('S','B',5,'REJECTED'); e~applied('S','C',3,'ACCEPTED')
f=.StandardApplicationAudit~new; f~standard('S','DISQUALIFY','problem')
f~applied('S','C',3,'ACCEPTED'); f~applied('S','B',5,'REJECTED'); f~applied('S','A',2,'REJECTED')
call check e~audit('S')['classification']=f~audit('S')['classification'] & e~audit('S')['classification']='DISPARATE_TREATMENT', 'nonadjacent violating pair regardless of order'
/* New explicit-cutoff conditional path: identity and order invariant as well. */
g=.StandardApplicationAudit~new; g~standard('S','DISQUALIFY','problem',3)
g~applied('S','A',4,'ACCEPTED'); g~applied('S','B',5,'ACCEPTED')
h=.StandardApplicationAudit~new; h~standard('S','DISQUALIFY','problem',3)
h~applied('S','B',5,'ACCEPTED'); h~applied('S','A',4,'ACCEPTED')
call check g~audit('S')['classification']=h~audit('S')['classification'] & g~audit('S')['ruleViolations']~items=2 & h~audit('S')['ruleViolations']~items=2, 'new absolute boundary order invariant'
i=.StandardApplicationAudit~new; i~standard('S','DISQUALIFY','problem',3)
i~applied('S','COMPETITOR',4,'ACCEPTED'); i~applied('S','OWN_SYSTEM',5,'ACCEPTED')
call check i~audit('S')['classification']=g~audit('S')['classification'] & i~audit('S')['ruleViolations']~items=2, 'new boundary label invariant'
say 'LABEL/ORDER COMPATIBILITY PASS:' checks 'checks'
exit 0
check: procedure expose checks
  use arg ok,label
  checks+=1
  if ok==1 | ok==.true then do
    say 'PASS:' label
    return
  end
  say 'FAIL:' label
  exit 1
onSyntax: say 'SYNTAX line' sigl':' condition('D'); exit 2
::requires 'StandardApplicationAudit.cls'
