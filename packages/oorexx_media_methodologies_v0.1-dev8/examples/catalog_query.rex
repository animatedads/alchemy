catalogue = .MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalogue)

say "Total methodologies:" catalogue~count
say "Video:" catalogue~byDomain("VIDEO")~items
say "Audio:" catalogue~byDomain("AUDIO")~items
say "Experimental:" catalogue~experimental~items
say "Reconstructive:" catalogue~reconstructive~items

say
say "Experimental video reconstruction candidates:"
policy = .MediaMethodologyPolicy~new(.true, .true)
items = catalogue~candidates("VIDEO", "RECONSTRUCTION", policy)
do i = 1 to items~items
  spec = items~at(i)
  if spec~experimental then say " " spec~id "-" spec~name
end

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
