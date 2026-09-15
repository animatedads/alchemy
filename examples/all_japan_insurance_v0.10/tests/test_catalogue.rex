c=.AllJapanInsuranceCatalogue~new
codes=c~productCodes
ignored=.AJITestSupport~assert(codes~items=3,"three acquired direct products")
ignored=.AJITestSupport~assert(c~contains("PI"),"PI present")
ignored=.AJITestSupport~assert(c~contains("HOME"),"HOME present")
ignored=.AJITestSupport~assert(c~contains("CAR"),"CAR present")
ignored=.AJITestSupport~assert(\c~contains("INTERMEDIARIES"),"intermediaries excluded")
say "PASS acquired product catalogue"
::requires "TestSupport.cls"
