stamp=.DateTime~new~microseconds
root='./tmp_rep_queue_demo_' || stamp
codec=.ReputationFeedQueuePersistenceSupport~newCodec
manager=.ObjectQueueManager~new(root,codec,'admin')
ignore=manager~createQueue('REP.DEMO','PERMANENT','REP',10,'admin')
topics=.QueueTopicFabric~new(manager)
ignore=topics~defineTopic('REPUTATION_FEED','reputation/feed','PERMANENT','REP','admin')
ignore=topics~subscribe('REP.DEMO.SUB','REPUTATION_FEED','claims/#','REP.DEMO','PERMANENT','admin')
bridge=.ReputationFeedQueueBridge~new(topics,'REPUTATION_FEED','admin')
now=.DateTime~new
claim=.ReputationFeedClaim~new('DEMO-PERSIST','ARTICLE-1','FAMILY-1','AVIATION_INCIDENT','Synthetic durable queue demo',now,now,'GB',82,'ASSERTS','ACTIVE','NEWS-1','demo://claim')
claim~addConcept('CABIN_OPENING')
claim~seal
opts=.table~new; opts['persistent']=.true; opts['retain']=.true
pub=bridge~publishClaim(claim,opts)
if \pub~ok then do; say 'FAIL publish' pub~code pub~detail; exit 1; end

codec2=.ReputationFeedQueuePersistenceSupport~newCodec
manager2=.ObjectQueueManager~new(root,codec2,'admin')
topics2=.QueueTopicFabric~new(manager2)
package=manager2~browse('REP.DEMO','admin')~value
say 'api=' || package~headers['reputation.feed.api']
say 'persistent_type=' || package~payload~queuePersistentType
say 'payload_class=' || package~payload~class~id
say 'payload_restored=' || (package~payload \== claim)
say 'canonical_equal=' || (package~payload~canonicalText == claim~canonicalText)
say 'authority_boundary=' || package~headers['reputation.feed.authority_boundary']
say 'retained_after_restart=' || topics2~retainedPublications~items
call cleanup root
exit 0

cleanup: procedure
  use arg root
  /* Demo-only transient state; root is generated locally from a numeric timestamp. */
  address system 'rm -rf -- ' || root
  return

::requires 'ReputationFeedQueueBridge.cls'
