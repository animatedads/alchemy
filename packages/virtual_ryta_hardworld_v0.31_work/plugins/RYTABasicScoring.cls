/* Deliberately simple commercial / interaction scoring plugin. */
::class RYTABasicScoringPlugin public

::method pluginVersion
  return '0.2'

::method pluginKind
  return 'SCORE'

::method pluginId
  return 'BASIC_SCORING'

::method canonicalConfiguration
  return 'BASIC_SCORING|version=' || self~pluginVersion

::method score
  use arg world, actionCode

  select
    when actionCode == 'ANSWER_QUERY' then do
      if world~isKnownTrue('HAS_QUERY') then return 10
      return 0
    end

    when actionCode == 'SELL_PRODUCT' then do
      scoreValue = 0
      if world~isKnownTrue('PRODUCT_RELEVANT') then scoreValue = scoreValue + 5
      if world~isKnownFalse('CUSTOMER_ELIGIBLE') then scoreValue = scoreValue - 10
      return scoreValue
    end

    when actionCode == 'WARNING' then return -2

    when actionCode == 'UPSELL' then do
      if world~isKnownTrue('UPSELL_OPPORTUNITY') then return 3
      return 0
    end

    when actionCode == 'BIG_UPSELL' then do
      if world~isKnownTrue('PRODUCT_VALUE_HIGH') then return 8
      return 0
    end

    otherwise return 0
  end
