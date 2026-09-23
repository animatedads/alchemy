# Supplied Police Archive Profile

Source SHA-256: `9e65357c919c4ccfa5c9103feab0ab4f97af66db013edace617c79a15b290813`

The attached archive contains two monthly partitions rather than one:

| Period | Street crime | Outcomes | Stop/search | Street LSOAs | With point | Without point | With LSOA | Without LSOA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2025-08 | 521,152 | 405,925 | 46,133 | 33,555 | 512,889 | 8,263 | 500,809 | 20,343 |
| 2025-09 | 479,936 | 427,896 | 38,837 | 33,532 | 473,672 | 6,264 | 462,904 | 17,032 |

## Street crime categories

- Anti-social behaviour: 171,324
- Bicycle theft: 9,114
- Burglary: 34,947
- Criminal damage and arson: 73,281
- Drugs: 34,556
- Other crime: 20,864
- Other theft: 65,632
- Possession of weapons: 10,215
- Public order: 70,988
- Robbery: 13,461
- Shoplifting: 79,493
- Theft from the person: 16,721
- Vehicle crime: 49,656
- Violence and sexual offences: 350,836

## Filter dimensions present in the archive

- `crimeType`: 14 values
- `lastOutcome`: 15 values
- `outcomeType`: 12 values
- `reportedBy`: 43 values
- `fallsWithin`: 43 values
- `stopType`: 3 values
- `stopAge`: 6 values
- `stopGender`: 4 values
- `stopOfficerDefinedEthnicity`: 6 values
- `stopObject`: 19 values
- `stopOutcome`: 8 values

The full values and source counts are in `data/police_uk_filter_catalog_2025-08_2025-09.json`.

## v0.3 actual-source release probe

The v0.3 release pass used the real City of London files from both supplied periods while
seeding the complete 35,672-LSOA reference universe.  It ingested 1,477 street rows, 1,450
outcome rows and 473 stop/search rows, produced 62 populated LSOA/month frames and 101 outcome
cells, wrote a complete snapshot with sparse category shards, reopened it, and produced a
35,672-entry COMPACT map layer.

This probe deliberately preserves the distinction between source-scale inventory and release
qualification: the table above describes the complete supplied archive; the v0.3 debug-runtime
release probe is a real subset plus the full national area universe.
