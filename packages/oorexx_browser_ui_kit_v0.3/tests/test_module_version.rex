/* test_module_version.rex -- every class of the kit answers ~module_version and ~module_lastChanged (Tom's rule,
 * Nov 2026), as a class and on its instances, with its own value (not one inherited from another class).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 15 November 2026.
 *   bin/kit.sh rexx tests/test_module_version.rex
 */
kit=value('KIT',, 'ENVIRONMENT')
pass=0
fail=0
files=.array~of('src/BostonCrabReader.cls', 'src/CdpBrowser.cls', 'src/FetchForMe.cls', 'src/FetchOrders.cls', -
  'src/MailNudger.cls', 'src/MailboxClient.cls', 'src/OrderGate.cls', 'src/UiKit.cls', 'fixtures/FixtureApps.cls')
do f over files
  pkg=.context~package~loadPackage(kit'/'f)
  classes=pkg~classes
  do name over classes~allIndexes~sort
    c=classes[name]
    v=c~module_version
    d=c~module_lastChanged
    own=(c~instanceMethods(c)~allIndexes~hasItem('MODULE_VERSION'))
    ok=(v=='0.3.0') & datatype(d~changeStr('-', ''), 'W') & d~length==10 & own
    if ok then pass=pass+1
    else do
      fail=fail+1
      say 'FAIL' f name 'module_version='v 'module_lastChanged='d 'own instance method='own
    end
  end
end
say 'module version tests:' pass 'passed,' fail 'failed'
exit (fail>0)
