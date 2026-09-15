/* Test-only fact plugin demonstrating the external .cls adapter boundary. */
::class RYTATestFactPlugin public

::method pluginVersion
  return '0.2'

::method pluginKind
  return 'FACT'

::method pluginId
  return 'TEST_FACT_PLUGIN'

::method canonicalConfiguration
  return 'TEST_FACT_PLUGIN|version=' || self~pluginVersion

::method contributeFacts
  use arg world
  world~putKnown('PRODUCT_VALUE_HIGH', .true, 'TEST_FACT_PLUGIN', 'PLUGIN')
  world~putKnown('UPSELL_OPPORTUNITY', .true, 'TEST_FACT_PLUGIN', 'PLUGIN')
  return 2
