# GTK email-rule handoff — dev15

`email_rules.pl` is the readable rule source and `email_rules.qlf` is its compiled SWI-Prolog 10.0.2 form.

GTK owns presentation, ooRexx owns the live email object, and Prolog owns the rules. `EmailRuleService~classify(mail)` returns a two-item array: category and evidence. Current categories are `security`, `operations`, `customer`, and `personal`; evidence identifies the rule that fired. `route(mail)` remains for the dev14 `attention|normal` UI contract.

The mail is not converted to JSON or copied into a Prolog DTO. Prolog receives the retained object and calls its current `senderForProlog` and `subjectForProlog` methods through `rexx_send/4`.
