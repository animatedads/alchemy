# MAS compatibility personalities

MAS personalities sit above MAS BASE and use the same local request and wire machinery. They do not create independent transports.

Reserved wire ranges: 1000-10FF MAS/MQ; 1100-11FF MAS/DB2; 1200-12FF MAS/CICS; 1300-13FF MAS/LDAP.

The personalities are deliberately limited compatibility surfaces for learning and application portability. They do not claim to contain or reproduce IBM MQSeries, DB2, CICS, LDAP server products, RACF, RRS, or z/OS.

- MAS/MAIL — bounded mail/message personality over ooRexx IMAP + secure SMTP (`1400-14FF`).

## dev3-pre6 status

The reserved MAS/DB2 range now has executable generic database semantics through the host `DatabaseProvider`; it does not reproduce DB2.  MAS/MAIL now has an explicit `ImapProvider` / `SmtpProvider` dispatch boundary, so its MVS-visible service can be exercised end-to-end against qualification providers and replaced with the real ooRexx protocol packages without changing the MVS ABI.
