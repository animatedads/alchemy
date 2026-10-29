/* Validate every pricing/profile record before atomically activating it. */
parse arg folder
if folder='' then exit 2
terms=.CloudEconomicIO~read(folder||'/terms.tsv')
profiles=.CloudEconomicIO~read(folder||'/profiles.tsv')
ok=.CloudWholeJobEconomics~new~validateSnapshot(terms,profiles)
if ok then say 'VALID_ECONOMICS_SNAPSHOT' terms~items profiles~items
else exit 3
::requires 'CloudWholeJobEconomics.cls'
