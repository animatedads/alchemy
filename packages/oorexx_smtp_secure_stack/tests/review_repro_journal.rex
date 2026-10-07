root=value('SMTP_REPRO_ROOT',,'ENVIRONMENT')
if root='' then root='/proc/oorexx-smtp-review-no-write'
cat=.StorageCatalogue~new
store=.StorageFabricSmtpStore~new(root,cat)
signal on syntax name syn
signal on notready name nr
r=store~transitionSpool('s1',.SmtpSpoolState~DELIVERED,1,'250','ok','')
signal off syntax
signal off notready
say 'JOURNAL_RESULT ok='||r~ok||' code='||r~code||' detail='||r~detail
exit 0
syn:
say "review journal syntax rc=" rc "sigl=" sigl "condition=" condition("C") "detail=" condition("D")
say 'JOURNAL_SYNTAX' condition('D'); exit 0
nr:
say "review journal notready rc=" rc "sigl=" sigl "condition=" condition("C") "detail=" condition("D")
say 'JOURNAL_NOTREADY' condition('D'); exit 0
::requires 'src/SmtpDurableDelivery.cls'
