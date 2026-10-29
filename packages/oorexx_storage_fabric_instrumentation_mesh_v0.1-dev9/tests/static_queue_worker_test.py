from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src'/'StorageRepairQueue.cls').read_text()
required=[
 '::class StorageRepairQueueWorker public',
 'manager~claim(queueName,workerPrincipal)',
 'manager~ack(queueName,package~packageId,package~claimToken,workerPrincipal)',
 'manager~nack(queueName,package~packageId,package~claimToken,workerPrincipal)',
 'ACK_FAILED_AFTER_REPAIR',
 'NACK_FAILED_AFTER_REPAIR_FAILURE',
 'execution~execute(package~payload)',
]
missing=[x for x in required if x not in s]
if missing: raise SystemExit('FAIL Queue Fabric worker contract missing: '+repr(missing))
forbidden=['claimToken=work~repairId','claimToken=package~correlationId','manager~ack(queueName,work~repairId']
found=[x for x in forbidden if x in s]
if found: raise SystemExit('FAIL fabricated claim-token path: '+repr(found))
print('PASS exact Queue Fabric CLAIM/ACK/NACK Storage repair worker contract')
