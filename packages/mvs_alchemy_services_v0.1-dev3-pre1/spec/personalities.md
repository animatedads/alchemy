# MAS compatibility personalities

MAS personalities sit above MAS BASE and use the same local request and wire machinery. They do not create independent transports.

Reserved wire ranges: 1000-10FF MAS/MQ; 1100-11FF MAS/DB2; 1200-12FF MAS/CICS; 1300-13FF MAS/LDAP.

The personalities are deliberately limited compatibility surfaces for learning and application portability. They do not claim to contain or reproduce IBM MQSeries, DB2, CICS, LDAP server products, RACF, RRS, or z/OS.
