# GTK integration boundary — dev15

The GTK/Wire layer should keep the email as its ordinary ooRexx application object. do not convert the mail to JSON and do not expose SWI query handles to the renderer.

Create one `EmailRuleService` for the compiled `email_rules.qlf`. For each displayed mail call `service~classify(mail)`. The returned array is `[category, evidence]`; category is presentation input and evidence is a human-readable/stable rule identifier. The existing `service~route(mail)` remains available for an `attention|normal` presentation.

The current demo rules classify security, operations, customer and personal mail. They deliberately use only sender and subject so the GTK handoff remains small. The rule boundary is live: changing the ooRexx object's state before a new query changes what Prolog observes.
