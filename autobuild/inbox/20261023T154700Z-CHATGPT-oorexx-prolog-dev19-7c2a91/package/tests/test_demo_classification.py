from pathlib import Path
root=Path(__file__).resolve().parents[1]
svc=(root/'demo/email/EmailRuleService.cls').read_text()
rules=(root/'demo/email/email_rules.pl').read_text()
gtk=(root/'demo/email/GTK_INTEGRATION.md').read_text()
checks={
 'classification API':'::method classify' in svc,
 'live mail identity':'runtime~rexxObject(mail)' in svc,
 'three-argument predicate':'"email_rules", "classify_email"' in svc,
 'category plus evidence':'.array~of(category~text, evidence~text)' in svc,
 'four categories':all(x in rules for x in ['security,','operations,','customer,','personal,']),
 'live sender callback':'rexx_send(Mail, senderForProlog' in rules,
 'live subject callback':'rexx_send(Mail, subjectForProlog' in rules,
 'no json handoff':'do not convert the mail to JSON' in gtk,
 'legacy route retained':'::method route' in svc and 'route_email' in rules,
}
for name,ok in checks.items(): print(('PASS' if ok else 'FAIL'), name)
assert all(checks.values())
