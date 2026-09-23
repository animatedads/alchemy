from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
def test_generic_analytics_frontend():
    js=(R/'web/wire-analytics.js').read_text()
    html=(R/'web/analytics.html').read_text()
    assert 'WireAnalyticsRenderer' in js
    assert 'wire-object-selection' in js and 'wire-time-selection' in js
    assert 'CrimeTrendSeries example fixture' in html
    assert 'crimeType' not in js and 'LSOA21CD' not in js
def test_real_geometry_fixture():
    g=json.loads((R/'web/lsoa-demo.geojson').read_text())
    assert len(g['features']) == 32
    assert any(f['properties']['LSOA21CD']=='E01000001' for f in g['features'])
    assert all(f['geometry']['type'] in ('Polygon','MultiPolygon') for f in g['features'])
