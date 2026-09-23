:- module(wire_mail_rules, [needs_attention/1]).
important_sender('boss@example.com').
important_sender('operations@example.com').
subject_requires_action('ACTION REQUIRED').
subject_requires_action('PRODUCTION ALERT').
needs_attention(Mail) :-
    rexx_send(Mail, senderForProlog, [], Sender),
    rexx_send(Mail, subjectForProlog, [], Subject),
    important_sender(Sender),
    subject_requires_action(Subject).
