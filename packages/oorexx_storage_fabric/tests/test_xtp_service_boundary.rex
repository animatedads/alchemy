/* Test genuine XTP dev22 named selector with the real dev2 registry;
 * no network traffic is sent by this test. */
registry=.ServiceRegistry~new('/tmp/storage-xtp-integration5.tsv')
registry~register(.ServiceDescriptor~new('storage.search.ed209c','normal.storage','ed209c'))
planner=.FakePlanner~new
manager=.XtpNamedServiceManager~new(registry,.XtpSocketBackend~new,planner)
routes=.StorageNamedServiceRoutes~new
routes~bind('ed209c','CATALOGUE_LIST','storage.search.ed209c','ed209c')
port=.StorageServiceNetworkPort~new(.FakeFallback~new,registry,manager,routes,planner)
s=port~sender('ed209c','CATALOGUE_LIST')
if s==.nil then do; say 'FAIL named XTP manager selection'; exit 1; end
if \s~isA(.XtpOperationalSocket) then do; say 'FAIL planner wrapper missing'; exit 2; end
if planner~lastClass<>'normal.storage' then do; say 'FAIL registered class'; exit 3; end
call SysFileDelete registry~path
say 'PASS real XTP dev22 manager chooses registry service, without sending carrier bytes'
exit 0
::class FakeFallback public
::method sender
  use strict arg node
  return .nil
::method listener
  return .nil
::class FakePlanner public
::attribute lastClass get
::method decide
  expose lastClass
  use strict arg className,state
  lastClass=className
  d=.directory~new
  d['TRANSMIT']='1'; d['TRANSFORM']='0'
  d['MAX_PARALLEL_CONTEXTS']='0'; d['PER_CONTEXT_CAP_PERCENT']='0'; d['AGGREGATE_CAP_PERCENT']='0'
  return d
::requires "StorageNetworkServices.cls"
::requires "XtpNamedServices.cls"
::requires "ServiceDescriptors.cls"
