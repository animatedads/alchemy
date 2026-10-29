import json, pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
PACK=ROOT/'packs'/'relationship-crm-odoo'
ART=PACK/'articles'
READ=lambda p:json.loads(p.read_text(encoding='utf-8'))
class SphereQualification(unittest.TestCase):
  @classmethod
  def setUpClass(cls):
    cls.meta=READ(PACK/'00-sphere.json')
    cls.policy=READ(PACK/'01-access-policy.json')
    cls.profile=READ(ROOT/'profiles'/'relationship-crm-odoo.json')
    cls.articles=[READ(p) for p in sorted(ART.glob('*.json'))]
  def test_identity(self):
    self.assertEqual('relationship-crm-odoo',self.meta['id'])
    self.assertEqual(self.meta['access_policy'],self.policy['id'])
  def test_articles(self):
    ids=[a['id'] for a in self.articles]
    self.assertEqual(len(ids),6); self.assertEqual(len(ids),len(set(ids)))
    self.assertTrue(set(self.meta['start_here'])<=set(ids))
    for a in self.articles:
      self.assertEqual(a['sphere'],self.meta['id'])
      self.assertTrue(a['summary'] and a['invariants'] and a['procedure'])
      for p in a['provenance']:
        self.assertRegex(p['sha256'],r'^[0-9a-f]{64}$')
  def test_authority_boundaries(self):
    text=' '.join(x for a in self.articles for x in a['invariants'])
    for term in ('SIP Call-ID','Relationship CRM','Odoo','mutation authority','Queue Fabric','LDAP'):
      self.assertIn(term,text)
  def test_qualification_honesty(self):
    q=READ(ROOT/'qualification'/'QUALIFICATION.json')
    self.assertIn('dev12 LDAP actor/service regression on r13196',q['unqualified'])
    self.assertIn('outbound SIP originating INVITE/UAC',q['unqualified'])
    a=next(a for a in self.articles if a['id']=='qual.crm-odoo.current')
    self.assertIn('HTTP1_ONLY',' '.join(a['invariants']+a['procedure']))
  def test_service_order_documented(self):
    a=next(a for a in self.articles if a['id']=='arch.crm-odoo.service')
    s=' '.join(a['invariants']+a['procedure'])
    self.assertLess(s.index('CRM.RELATIONSHIP.OPEN'),s.index('CRM.INTERACTION.RECORD'))
  def test_ldap_fail_closed(self):
    a=next(a for a in self.articles if a['id']=='arch.crm-odoo.ldap-actor')
    s=' '.join(a['invariants'])
    for term in ('authenticated LdapSession','ACTIVE LDAP principal','explicit local principal/group bindings','fail closed'):
      self.assertIn(term,s)
if __name__=='__main__': unittest.main()
