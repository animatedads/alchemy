/* Validate candidate mobility snapshot without claiming authority. */
parse arg folder
jobs=.CloudEconomicIO~read(folder||'/running.tsv')
routes=.CloudEconomicIO~read(folder||'/routes.tsv')
valid=.CloudMigrationEconomics~new~validateMobilityInputs(jobs,routes)
say 'MOBILITY_SCHEMA_VALID'
exit 0
::requires 'CloudEconomics.cls'
::requires 'CloudMigrationEconomics.cls'
