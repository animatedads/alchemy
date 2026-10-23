from pathlib import Path
root=Path(__file__).resolve().parents[1]
svc=(root/'demo/email/EmailRuleService.cls').read_text()
rules=(root/'demo/email/email_rules.pl').read_text()
gtk=(root/'demo/email/GTK_INTEGRATION.md').read_text()
checks={
 'service route API':'::method route' in svc,
 'live object projection':'runtime~rexxObject(mail)' in svc,
 'compiled rule loading':'"consult"' in svc and 'rulesPath' in svc,
 'module query':'"email_rules", "route_email"' in svc,
 'deterministic cleanup':'q~cut' in svc and 'q~close' in svc,
 'live callback rule':'rexx_send(Mail, senderForProlog' in rules,
 'no DTO instruction':'do not convert the mail to JSON' in gtk,
}
for name,ok in checks.items():
 print(('PASS' if ok else 'FAIL'), name)
assert all(checks.values())
