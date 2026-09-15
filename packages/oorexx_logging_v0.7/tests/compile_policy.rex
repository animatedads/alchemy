spec = .LogRuleSpec~new("r","c","WebsiteUI","generateCustomerPanel",.Log~INTERNAL,.Log~INTERNAL,.Log~WARN)
p = .LogRuleSetPolicy~new("LOGGING","1",.array~of(spec),.nil,.nil,"AUTHOR","BOARD")~seal
say p~policyId p~version p~publicationEligible
::requires "LoggingPolicy.cls"
