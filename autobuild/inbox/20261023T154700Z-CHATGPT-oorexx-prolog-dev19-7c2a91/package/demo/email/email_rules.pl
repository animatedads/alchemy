:- module(email_rules, [needs_attention/1, route_email/2, classify_email/3]).

important_sender('boss@example.com').
important_sender('operations@example.com').
security_sender('security@example.com').
customer_sender('customer@example.com').

subject_requires_action('ACTION REQUIRED').
subject_requires_action('PRODUCTION ALERT').
security_subject('SECURITY ALERT').
customer_subject('CUSTOMER ESCALATION').

% Mail remains a retained ooRexx object. rexx_send/4 performs live callbacks;
% no copied JSON/DTO representation is required.
mail_sender(Mail, Sender) :- rexx_send(Mail, senderForProlog, [], Sender).
mail_subject(Mail, Subject) :- rexx_send(Mail, subjectForProlog, [], Subject).

needs_attention(Mail) :-
    mail_sender(Mail, Sender),
    mail_subject(Mail, Subject),
    important_sender(Sender),
    subject_requires_action(Subject).

% classify_email(+LiveMail, -Category, -Evidence)
% Evidence is intentionally a stable atom suitable for a first GTK handoff;
% it describes which rule fired without serialising the mail object.
classify_email(Mail, security, security_sender) :-
    mail_sender(Mail, Sender), security_sender(Sender), !.
classify_email(Mail, security, security_subject) :-
    mail_subject(Mail, Subject), security_subject(Subject), !.
classify_email(Mail, operations, important_sender_action_subject) :-
    mail_sender(Mail, Sender), important_sender(Sender),
    mail_subject(Mail, Subject), subject_requires_action(Subject), !.
classify_email(Mail, customer, customer_escalation) :-
    mail_sender(Mail, Sender), customer_sender(Sender),
    mail_subject(Mail, Subject), customer_subject(Subject), !.
classify_email(_Mail, personal, no_priority_rule_matched).

route_email(Mail, attention) :-
    classify_email(Mail, Category, _),
    memberchk(Category, [security, operations, customer]), !.
route_email(_Mail, normal).
