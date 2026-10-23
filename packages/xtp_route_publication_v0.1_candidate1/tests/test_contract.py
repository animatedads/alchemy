"""Independent offline verifier tests. Run: python -m unittest discover -s tests -v"""
import copy
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'reference'))
from provision_contract import (NodePolicy, AuthorityPolicy, Rejected, sign_envelope,
                                add_signature, verify_announcement, verify_allocation,
                                strict_load_json, canonical_body)

NOW = datetime(2026, 10, 22, 15, 0, 0, tzinfo=timezone.utc)
LEASING = {'not_before': '2026-10-22T14:00:00Z', 'expires_at': '2026-10-22T18:00:00Z'}
ROUTE = {'peer':'ed209h.mi1','layer':4,'carrier':'udp','destination':'192.0.2.42:62801',
         'interface':'','metric':20,'wire_filters':'','multicast':False,'enabled':True}

class Contract(unittest.TestCase):
    def setUp(self):
        self.keys = {x: Ed25519PrivateKey.generate() for x in ('mi.h','ctl.a','ctl.b','ctl.c','enemy')}
        self.pub = {x: k.public_key() for x,k in self.keys.items()}
        self.np = NodePolicy('ed209','ed209h.mi1','mi.h',frozenset({'ssh.management'}),frozenset({'ed209h.mi1'}))
        self.ap = AuthorityPolicy('ed209','ed209b.mi1',frozenset({'ctl.a','ctl.b','ctl.c'}),2,
                                  {'ssh.management':'management.critical'},frozenset({'bootstrap.controller'}))
        self.announce = {'protocol':'xtp.provision/1','kind':'node.announce','domain':'ed209',
                         'origin_mi':'ed209h.mi1','sequence':1,'service_points':[
                            {'name':'ssh.management','route_peer':'ed209h.mi1','service_point':'ssh.management'}],
                         'route_candidates':[copy.deepcopy(ROUTE)], **LEASING}
        self.alloc = {'protocol':'xtp.provision/1','kind':'authority.allocation','domain':'ed209',
                      'target_mi':'ed209b.mi1','authority_epoch':12,'revision':18,
                      'services':[{'name':'ssh.management','route_peer':'ed209h.mi1',
                                   'service_point':'ssh.management','operational_class':'management.critical'}],
                      'routes':[copy.deepcopy(ROUTE)],'revocations':[],**LEASING}

    def signed_announce(self):
        return sign_envelope(copy.deepcopy(self.announce),'mi.h',self.keys['mi.h'])

    def signed_allocation(self):
        env=sign_envelope(copy.deepcopy(self.alloc),'ctl.a',self.keys['ctl.a'])
        add_signature(env,'ctl.b',self.keys['ctl.b'])
        return env

    def test_node_announcement(self):
        self.assertEqual(len(verify_announcement(self.signed_announce(),self.pub,self.np,0,NOW)),64)

    def test_node_replay(self):
        with self.assertRaisesRegex(Rejected,'STALE_SEQUENCE'):
            verify_announcement(self.signed_announce(),self.pub,self.np,1,NOW)

    def test_no_operational_class_from_publisher(self):
        e=self.signed_announce(); e['body']['service_points'][0]['operational_class']='emergency'
        with self.assertRaises(Rejected): verify_announcement(e,self.pub,self.np,0,NOW)

    def test_node_scope_rejection(self):
        for f in [lambda b:b['service_points'][0].update(name='fire-control.primary'),
                  lambda b:b['route_candidates'][0].update(peer='ed209f.mi2')]:
            b=copy.deepcopy(self.announce);f(b)
            e=sign_envelope(b,'mi.h',self.keys['mi.h'])
            with self.assertRaisesRegex(Rejected,'OUTSIDE_'):
                verify_announcement(e,self.pub,self.np,0,NOW)

    def test_announcement_forged(self):
        e=sign_envelope(copy.deepcopy(self.announce),'enemy',self.keys['enemy'])
        with self.assertRaisesRegex(Rejected,'ORIGIN_SIGNER_MISMATCH'):
            verify_announcement(e,self.pub,self.np,0,NOW)

    def test_allocation_two_of_three(self):
        self.assertEqual(len(verify_allocation(self.signed_allocation(),self.pub,self.ap,12,17,NOW)),64)

    def test_allocation_one_of_three_denied(self):
        e=sign_envelope(copy.deepcopy(self.alloc),'ctl.a',self.keys['ctl.a'])
        with self.assertRaisesRegex(Rejected,'INSUFFICIENT_CONTROLLER_QUORUM'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_duplicate_signature_denied(self):
        e=self.signed_allocation(); e['signatures'][1]=copy.deepcopy(e['signatures'][0])
        with self.assertRaisesRegex(Rejected,'DUPLICATE_SIGNER'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_signature_tampering(self):
        e=self.signed_allocation(); e['body']['routes'][0]['metric']=1
        with self.assertRaisesRegex(Rejected,'BAD_SIGNATURE'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_stale_and_future_rejected(self):
        e=self.signed_allocation()
        with self.assertRaisesRegex(Rejected,'STALE_REVISION'):
            verify_allocation(e,self.pub,self.ap,12,18,NOW)
        with self.assertRaisesRegex(Rejected,'STALE_EPOCH'):
            verify_allocation(e,self.pub,self.ap,13,0,NOW)

    def test_expired_lease_rejected(self):
        e=self.signed_allocation()
        with self.assertRaisesRegex(Rejected,'LEASE_NOT_CURRENT'):
            verify_allocation(e,self.pub,self.ap,12,17,datetime(2026,10,24,tzinfo=timezone.utc))

    def test_class_self_promotion_blocked(self):
        b=copy.deepcopy(self.alloc);b['services'][0]['operational_class']='emergency'
        e=sign_envelope(b,'ctl.a',self.keys['ctl.a']);add_signature(e,'ctl.b',self.keys['ctl.b'])
        with self.assertRaisesRegex(Rejected,'OPERATIONAL_CLASS_NOT_AUTHORISED'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_bootstrap_route_cannot_be_replaced(self):
        b=copy.deepcopy(self.alloc);b['routes'][0]['peer']='bootstrap.controller'
        e=sign_envelope(b,'ctl.a',self.keys['ctl.a']);add_signature(e,'ctl.b',self.keys['ctl.b'])
        with self.assertRaisesRegex(Rejected,'BOOTSTRAP_ROUTE_IMMUTABLE'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_wrong_target_rejected(self):
        b=copy.deepcopy(self.alloc);b['target_mi']='ed209g.mi1'
        e=sign_envelope(b,'ctl.a',self.keys['ctl.a']);add_signature(e,'ctl.b',self.keys['ctl.b'])
        with self.assertRaisesRegex(Rejected,'WRONG_TARGET'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_bad_route_carrier(self):
        b=copy.deepcopy(self.alloc);b['routes'][0]['carrier']='raw36'
        e=sign_envelope(b,'ctl.a',self.keys['ctl.a']);add_signature(e,'ctl.b',self.keys['ctl.b'])
        with self.assertRaisesRegex(Rejected,'UNSUPPORTED_CARRIER'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_conflicting_revoke(self):
        b=copy.deepcopy(self.alloc);b['revocations']=['ed209h.mi1']
        e=sign_envelope(b,'ctl.a',self.keys['ctl.a']);add_signature(e,'ctl.b',self.keys['ctl.b'])
        with self.assertRaisesRegex(Rejected,'CONFLICTING_ROUTE_STATE'):
            verify_allocation(e,self.pub,self.ap,12,17,NOW)

    def test_duplicate_json_keys(self):
        with self.assertRaisesRegex(Rejected,'DUPLICATE_JSON_KEY'):
            strict_load_json(b'{"protocol":"a","protocol":"b"}')

    def test_float_rejected(self):
        with self.assertRaisesRegex(Rejected,'UNSUPPORTED_TYPE'):
            canonical_body({'fraction':1.2})

    def test_two_of_two_commit(self):
        pair=AuthorityPolicy('ed209','ed209b.mi1',frozenset({'ctl.a','ctl.b'}),2,
                             {'ssh.management':'management.critical'},frozenset({'bootstrap.controller'}))
        e=self.signed_allocation()
        self.assertEqual(len(verify_allocation(e,self.pub,pair,12,17,NOW)),64)
        e['signatures'].pop()
        with self.assertRaisesRegex(Rejected,'INSUFFICIENT_CONTROLLER_QUORUM'):
            verify_allocation(e,self.pub,pair,12,17,NOW)

if __name__ == '__main__': unittest.main()
