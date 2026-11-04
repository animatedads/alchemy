import hashlib
import hmac
import pathlib
import sys
import tempfile
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent.parent/'ops'))
from verify_guest_rto2 import inspect,newc_files


def archive(files):
    out=bytearray();index=1
    for name,value in list(files.items())+[('TRAILER!!!',b'')]:
        rawname=name.encode()+b'\0'
        header=b'070701'+b''.join((f'{v:08x}').encode() for v in (index,0o100600,0,0,1,0,len(value),0,0,0,0,len(rawname),0))
        assert len(header)==110
        out+=header+rawname
        out+=b'\0'*((-len(out))%4)
        out+=value
        out+=b'\0'*((-len(out))%4)
        index+=1
    return bytes(out)


class ImageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=pathlib.Path(self.temp.name)
        self.authority=self.root/'authority'; self.mi='MN1-ED209F';self.mu='MU-ED209F'
        (self.authority/'nodes'/self.mi).mkdir(parents=True)
        (self.authority/'mus'/self.mu).mkdir(parents=True)
        self.key='ab'*32
        (self.authority/'nodes'/self.mi/'node.env').write_text(f'GRID_NODE_ID={self.mi}\nGRID_MU_ID={self.mu}\nGRID_ROUTE_ID=17\nGRID_MU_KEY_HEX={self.key}\n')
        (self.authority/'mus'/self.mu/'mu.env').write_text('GRID_MU_MAC=02:52:00:09:00:01\n')
        derived=hmac.new(bytes.fromhex(self.key),f'ed209.rto2.smoke.job.key.v1|{self.mu}|{self.mi}|l2'.encode(),hashlib.sha256).hexdigest()
        self.row=f'GRID.MU.{self.mu}|grid-controller|k1|{derived}|l2|02:52:00:09:00:01|RTO2.{self.mi}|GRID.RTO2.{self.mi}|GRID\n'
        self.files={
          'etc/grid/node':(self.mi+'\n').encode(),'etc/grid/mu':(self.mu+'\n').encode(),
          'etc/grid/route-id':b'17\n','etc/grid/mu-mac':b'02:52:00:09:00:01\n',
          'boot/qf-xtp-handler.rex':b'RTO2_WORK_RESULT RTO2_WORK_DISABLED',
          'boot/qf-xtp-handler.sh':b'#!/bin/sh\n',
          'usr/local/bin/qf-xtp-rpc':b'elfmock',
          'opt/rexxos/lib/QueueXTPTransport.cls':b'present',
          'opt/rexxos/lib/RTO2CountJob.cls':b'present',
          'opt/rexxos/lib/AlchemyRTO.cls':b'present',
          'opt/rexxos/lib/AlchemyClusteredApp.cls':b'present',
          'etc/grid/xtp.routes.tsv':b'GRID.MU.MU-ED209F\t2\tl2\t02:52:00:09:00:01\teth0\t5\t1\n',
          'etc/grid/peers.manifest':self.row.encode(),
          'init':b'QF_XTP_RTO2_ENABLED\x00GRID_NODE_ID\x00GRID_MU_ID\x00'}
        self.image=self.root/'mi.cpio'
    def probe(self):
        self.image.write_bytes(archive(self.files));return inspect(self.image,self.authority,self.mi)
    def test_valid_and_full_receipt(self):
        r=self.probe();self.assertEqual('READY_FOR_ISOLATED_RTO2_TEST',r['result']);self.assertEqual(17,r['route_id'])
        self.assertEqual(len(self.files),len(newc_files(self.image.read_bytes())))
    def test_missing_or_wrong_grants(self):
        for contents in [b'',self.row.encode()*2,self.row.replace('k1','k9').encode(),self.row.replace('09:00:01','0a:00:01').encode()]:
            self.files['etc/grid/peers.manifest']=contents
            with self.subTest(contents=contents[:18]),self.assertRaisesRegex(ValueError,'grant|missing'):
                self.probe()
    def test_old_handler_rejected(self):
        self.files['boot/qf-xtp-handler.rex']=b'PROBE DELIVER'
        with self.assertRaisesRegex(ValueError,'non-RTO2'):self.probe()
    def test_wrong_route_rejected(self):
        self.files['etc/grid/xtp.routes.tsv']=b'GRID.MU.MU-ED209F\t2\tl2\t02:52:00:09:00:02\teth0\n'
        with self.assertRaisesRegex(ValueError,'route'):self.probe()
    def test_stale_image_identity_rejected(self):
        self.files['etc/grid/node']=b'MN2-ED209F\n'
        with self.assertRaisesRegex(ValueError,'identity'):self.probe()
    def test_newc_truncated_rejected(self):
        with self.assertRaisesRegex(ValueError,'truncated|missing'):newc_files(archive(self.files)[:-120])

if __name__=='__main__':unittest.main()
