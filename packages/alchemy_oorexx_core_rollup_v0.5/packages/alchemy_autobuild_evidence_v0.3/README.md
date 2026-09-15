# Alchemy Autobuild Evidence v0.2

Terminal result/log/receipt persistence for the resident ooRexx Autobuild service.

Receipt lookup now participates in the shared repository lease while fetching
accepted main. Evidence recording remains one atomic leased accepted-main
transaction. Existing terminal receipts are immutable and are never replaced.
