v=.VectorMeridianMarkets~new
root="./tmp_queue_arm_acl_"||.DateTime~new~microseconds
svc=.VMMArmLengthFlowService~new(v,root)
m=svc~manager
fed=.VMMArmLengthBuild~federationPrincipal
vmm=.VMMArmLengthBuild~vmmPrincipal
call assertTrue m~accessAllowed(.VMMArmLengthBuild~rfqQueue,fed,.QueueAccess~PUT),"Federation may submit RFQ"
call assertTrue \m~accessAllowed(.VMMArmLengthBuild~rfqQueue,fed,.QueueAccess~GET),"Federation cannot consume its own RFQ as VMM"
call assertTrue m~accessAllowed(.VMMArmLengthBuild~quoteQueue,fed,.QueueAccess~GET),"Federation may receive quote"
call assertTrue \m~accessAllowed(.VMMArmLengthBuild~quoteQueue,fed,.QueueAccess~PUT),"Federation cannot forge VMM quote"
call assertTrue m~accessAllowed(.VMMArmLengthBuild~executeQueue,fed,.QueueAccess~PUT),"Federation may submit accepted quote"
call assertTrue \m~accessAllowed(.VMMArmLengthBuild~executeQueue,fed,.QueueAccess~GET),"Federation cannot consume execution as VMM"
call assertTrue m~accessAllowed(.VMMArmLengthBuild~confirmQueue,fed,.QueueAccess~GET),"Federation may receive confirmation"
call assertTrue \m~accessAllowed(.VMMArmLengthBuild~confirmQueue,fed,.QueueAccess~PUT),"Federation cannot forge VMM trade confirmation"
call assertTrue m~accessAllowed(.VMMArmLengthBuild~rfqQueue,vmm,.QueueAccess~GET),"VMM may consume RFQ"
call assertTrue \m~accessAllowed(.VMMArmLengthBuild~rfqQueue,vmm,.QueueAccess~PUT),"VMM cannot impersonate Federation RFQ producer"
client=.FederationMerchantVMMQueueClient~new(m)
call assertTrue \client~hasMethod("engine"),"Federation queue client exposes no VMM engine reference"
say "PASS test_arm_length_queue_acl"
exit 0

::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VectorMeridianFederationQueue.cls"
