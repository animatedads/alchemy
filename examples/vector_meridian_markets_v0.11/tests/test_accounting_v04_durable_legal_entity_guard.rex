numeric digits 50
otherEntityPath="./tests/tmp_vmm_accounting_other_entity_v010.jsonl"
wrongBookPath="./tests/tmp_vmm_accounting_wrong_book_v010.jsonl"

s1=.AccountingFileStore~new(otherEntityPath)
s1~createBook("FEDERATIONBANK_MERCHANT_BANK","VMM-STAT","ENTITY_GAAP")
blockedEntity=.false
signal on syntax name wrongEntity
.VMMAccountingStore~recoverEngine(otherEntityPath)
signal off syntax
raise syntax 88.900 array("ASSERT_DURABLE_FOREIGN_ENTITY_ACCEPTED")
wrongEntity:
  blockedEntity=.true
  signal off syntax
if \blockedEntity then raise syntax 88.900 array("ASSERT_DURABLE_FOREIGN_ENTITY_NOT_BLOCKED")

s2=.AccountingFileStore~new(wrongBookPath)
s2~createBook("VECTOR_MERIDIAN_MARKETS_LTD","FEDERATION-SHADOW-BOOK","ENTITY_GAAP")
blockedBook=.false
signal on syntax name wrongBook
.VMMAccountingStore~recoverEngine(wrongBookPath)
signal off syntax
raise syntax 88.900 array("ASSERT_DURABLE_WRONG_BOOK_ACCEPTED")
wrongBook:
  blockedBook=.true
  signal off syntax
if \blockedBook then raise syntax 88.900 array("ASSERT_DURABLE_WRONG_BOOK_NOT_BLOCKED")

say "PASS test_accounting_v04_durable_legal_entity_guard"
exit 0

::requires "VMMAccountingPersistence.cls"
