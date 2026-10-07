parse source . . here
root=filespec('location',here)'..'; call directory root
/* Local survey-frame topology invariant from supplied aerial evidence. */
aldiY=275; neilstonY=240; morrisonsY=205; petrolX=275; morrisonsX=320
if \(aldiY>neilstonY) then do; say 'FAIL ALDI must be north of Neilston Road'; exit 1; end
if \(morrisonsY<neilstonY) then do; say 'FAIL Morrisons must be south of Neilston Road'; exit 2; end
if \(petrolX<morrisonsX) then do; say 'FAIL petrol station must be west of Morrisons'; exit 3; end
say 'PASS Neilston retail topology'; exit 0
