# Authority separation

- Teller Till owns an individual drawer's physical expected/count truth.
- Branch Cash owns vault/internal-transfer/in-transit truth.
- Teller Cash owns customer counter-cash orchestration evidence.
- External cash logistics will own cash delivered to/from the branch from outside branch custody.
- Branch Day owns only the certification that the evidence set is sufficient and reconciled for the business-day transition.
- Core Banking and Ledger are not rewritten by Branch Day.

A balancing adjustment is evidence of an authorised correction, never a magic number entered merely to make the day close.
