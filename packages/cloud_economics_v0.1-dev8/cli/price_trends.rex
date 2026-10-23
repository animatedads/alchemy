/* Unified paper-only price-movement observations. A pricing component is not
 * a VM, and a predicted price is never an entitlement to buy or dispatch.
 * The estimator is the existing versioned CloudPriceForecast; this command
 * does not invent or duplicate a forecasting algorithm.
 */
parse arg root now
if root=='' then do
  say 'Usage: rexx price_trends.rex STATE_DIRECTORY EPOCH'
  exit 2
end
if now=='' then now=0
numeric digits 20
history=.CloudEconomicIO~read(root||'/history.tsv')
offers=.CloudEconomicIO~read(root||'/offers.tsv')
providerStatus=.CloudEconomicIO~read(root||'/providers.tsv')
statusMap=.directory~new
do p over providerStatus
  statusMap[p['provider']]=p['status']
end
say 'kind' || '09'x || 'identity' || '09'x || 'unit' || '09'x || 'last_observed_price' || ,
  '09'x || 'predicted_price_1h' || '09'x || 'confidence' || '09'x || ,
  'samples' || '09'x || 'model' || '09'x || 'observation_status'
predictor=.CloudPriceForecast~new
do offer over offers
  id=offer['id']
  forecast=predictor~estimate(id,history,3600,now)
  estimate='INSUFFICIENT_HISTORY'
  if forecast['count']>=4 & forecast['confidence']>0 then estimate=forecast['price']
  observation='UNKNOWN'
  if statusMap~hasIndex(offer['provider']) then observation=statusMap[offer['provider']]
  say 'VM_TARIFF' || '09'x || id || '09'x || 'USD/hour' || '09'x || ,
    offer['rate'] || '09'x || estimate || '09'x || forecast['confidence'] || ,
    '09'x || forecast['count'] || '09'x || forecast['model'] || '09'x || observation
end
/* Explicit identity and billing unit for individual GCP SKU components;
 * RAM per GiB-hour must not be compared directly to a VM per hour. */
components=.CloudEconomicIO~read(root||'/components/GCP.tsv')
componentHistory=.CloudEconomicIO~read(root||'/components/history.tsv')
do component over components
  id='GCP:'||component['sku_id']||':'||component['region']||':'||component['usage_unit']
  samples=.array~new
  do sample over componentHistory
    if sample['provider']\='GCP' then iterate
    if sample['sku_id']\=component['sku_id'] then iterate
    if sample['region']\=component['region'] then iterate
    if sample['usage_unit']\=component['usage_unit'] then iterate
    row=.directory~new
    row['id']=id
    row['rate']=sample['unit_price_usd']
    row['ts']=sample['observed_epoch']
    samples~append(row)
  end
  forecast=predictor~estimate(id,samples,3600,now)
  estimate='INSUFFICIENT_HISTORY'
  if forecast['count']>=4 & forecast['confidence']>0 then estimate=forecast['price']
  observation='UNKNOWN'
  if statusMap~hasIndex('GCP') then observation=statusMap['GCP']
  say 'BILLING_COMPONENT' || '09'x || id || '09'x || ,
    component['usage_unit'] || '09'x || component['unit_price_usd'] || '09'x || ,
    estimate || '09'x || forecast['confidence'] || '09'x || ,
    forecast['count'] || '09'x || forecast['model'] || '09'x || observation
end
exit 0
::requires 'CloudEconomics.cls'
