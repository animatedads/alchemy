/* Headless version of the GTK handoff. GTK can call the same service methods. */
parse source . . here
rules = here~left(here~lastpos('/')) || 'email_rules.qlf'
service = .EmailRuleService~new(rules)

samples = .array~new
samples~append(.DemoEmail~new(service, 'operations@example.com', 'PRODUCTION ALERT', 'db latency'))
samples~append(.DemoEmail~new(service, 'security@example.com', 'FYI', 'certificate event'))
samples~append(.DemoEmail~new(service, 'customer@example.com', 'CUSTOMER ESCALATION', 'please call'))
samples~append(.DemoEmail~new(service, 'friend@example.com', 'Lunch?', '12:30?'))

do mail over samples
  result = service~classify(mail)
  say mail~subject ':' result[1] '('result[2]') route='service~route(mail)
end
service~close

::requires 'EmailRuleService.cls'
::requires 'EmailDemoObjects.cls'
