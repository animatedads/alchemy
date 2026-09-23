# GTK email-rule handoff

`email_rules.pl` is the readable rule source and `email_rules.qlf` is its SWI-Prolog 10.0.2 compiled form.
The GTK application owns/presents the email.  ooRexx owns the `DemoEmail` object.  Prolog receives that same retained object through `runtime~rexxObject(mail)` and asks it for live fields through `rexx_send/4`.

Load the rule once by querying SWI `consult/1` with the `.qlf` path (or the `.pl` source while developing).  For an email, query `email_rules:route_email/2` with `[runtime~rexxObject(mail), RouteVariable]`.  The first solution binds RouteVariable to `attention` or `normal`.

The rule intentionally performs no GTK work.  The UI consumes the returned route and decides how to render it.
