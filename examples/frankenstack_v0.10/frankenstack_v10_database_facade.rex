/* Database Core v0.39 -> mysql-compatible CLI -> v0.10 retained authority */
parse arg host port databaseName userName executable
if host=='' then host='127.0.0.1'
if port=='' then port=3499
if databaseName=='' then databaseName='nosqlserver'
if userName=='' then userName='tribunal'
if executable=='' then do; say 'mysql-compatible executable required'; exit 64; end
conn=.DatabaseConnection~new(host,port,databaseName,userName,.nil,'mysql')
engine=.MySQLEngine~new
resolver=.DatabaseExecutableResolver~new
ignore=resolver~setOverride('mysql',executable)
db=.Database~new(conn,engine,.DatabaseProcessCommandExecutor~new,resolver)
identity=db~endpointIdentity
say 'DATABASE CORE V0.39 -> MYSQL WIRE IDENTITY'
say ' protocol=' || identity~protocol || ' product=' || identity~product
say ' raw=' || identity~rawVersion
q1=db~query("SELECT evidence_id,group_ref,message_ref,surname,service_code,service_value,source_path,source_identity_preserved FROM structured_offer_evidence ORDER BY message_ref")
if \q1~isA(.DatabaseQueryResult) then exit 9
say 'DATABASE CORE -> NATIVE G07 EVIDENCE rows=' || q1~rowCount
do row over q1~rows
 say row~rawAt('message_ref') || ' | ' || row~rawAt('surname') || ' | ' || row~rawAt('service_code') || ' | ' || row~rawAt('service_value') || ' | ' || row~rawAt('source_path') || ' | identity=' || row~rawAt('source_identity_preserved')
end
q2=db~query("SELECT phase,generation_id,artifact_id,generation_state,captured_state FROM runtime_execution_evidence ORDER BY phase")
if \q2~isA(.DatabaseQueryResult) then exit 9
say 'DATABASE CORE -> RUNTIME EVIDENCE rows=' || q2~rowCount
do row over q2~rows
 say row~rawAt('phase') || ' | ' || row~rawAt('generation_id') || ' | ' || row~rawAt('artifact_id') || ' | state=' || row~rawAt('generation_state') || ' | captured=' || row~rawAt('captured_state')
end
q3=db~query("SELECT phase,event_time,assessment_status,dispositions,runtime_generation_id FROM legal_time_assessments ORDER BY phase")
if \q3~isA(.DatabaseQueryResult) then exit 9
say 'DATABASE CORE -> LEGAL TIME rows=' || q3~rowCount
do row over q3~rows
 say row~rawAt('phase') || ' | event=' || row~rawAt('event_time') || ' | ' || row~rawAt('assessment_status') || ' | ' || row~rawAt('dispositions') || ' | runtime=' || row~rawAt('runtime_generation_id')
end
q4=db~query("SELECT case_id,publication_id,publisher_remote_count,retained_at_a,consumer_depth,publisher_legal_status,consumer_legal_status,receipt_count,duplicate_suppressed,provenance_preserved FROM retained_authority_case")
if \q4~isA(.DatabaseQueryResult) then exit 9
say 'DATABASE CORE -> RETAINED AUTHORITY CASE rows=' || q4~rowCount
do row over q4~rows
 say row~rawAt('case_id') || ' | pub=' || row~rawAt('publication_id') || ' | remote_at_publish=' || row~rawAt('publisher_remote_count') || ' | retained=' || row~rawAt('retained_at_a') || ' | consumer_depth=' || row~rawAt('consumer_depth') || ' | legal=' || row~rawAt('publisher_legal_status') || '->' || row~rawAt('consumer_legal_status') || ' | receipts=' || row~rawAt('receipt_count') || ' | duplicate_suppressed=' || row~rawAt('duplicate_suppressed')
end
q5=db~query("SELECT receipt_id,origin_manager,publication_id,destination_topic,source_manager FROM mqb_topic_distribution_receipts")
if \q5~isA(.DatabaseQueryResult) then exit 9
say 'DATABASE CORE -> QUEUE DISTRIBUTION RECEIPTS rows=' || q5~rowCount
do row over q5~rows
 say row~rawAt('receipt_id') || ' | origin=' || row~rawAt('origin_manager') || ' | publication=' || row~rawAt('publication_id') || ' | topic=' || row~rawAt('destination_topic')
end
q6=db~query("SELECT row_id,preference_score,disposition,final_selected,reason FROM retained_authority_decisions ORDER BY row_id")
if \q6~isA(.DatabaseQueryResult) then exit 9
say 'DATABASE CORE -> RETAINED AUTHORITY TRIBUNAL rows=' || q6~rowCount
do row over q6~rows
 say row~rawAt('row_id') || ' | score=' || row~rawAt('preference_score') || ' | ' || row~rawAt('disposition') || ' | selected=' || row~rawAt('final_selected') || ' | ' || row~rawAt('reason')
end
if q1~rowCount\=3 | q2~rowCount\=3 | q3~rowCount\=2 | q4~rowCount\=1 | q5~rowCount\=1 | q6~rowCount\=6 then exit 9
say 'DATABASE CORE FRANKENSTACK V0.10 FACADE: OK'
exit 0
::requires 'database_core.cls'
