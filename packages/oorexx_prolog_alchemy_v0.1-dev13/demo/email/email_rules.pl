:- module(email_rules, [needs_attention/1, route_email/2]).

important_sender('boss@example.com').
important_sender('operations@example.com').
subject_requires_action('ACTION REQUIRED').
subject_requires_action('PRODUCTION ALERT').

% Mail remains a retained ooRexx object.  rexx_send/4 performs live callbacks;
% the rule does not require a copied JSON/DTO representation of the message.
needs_attention(Mail) :-
    rexx_send(Mail, senderForProlog, [], Sender),
    rexx_send(Mail, subjectForProlog, [], Subject),
    important_sender(Sender),
    subject_requires_action(Subject).

route_email(Mail, attention) :- needs_attention(Mail), !.
route_email(_Mail, normal).
