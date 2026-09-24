#!/usr/bin/env python3
from mas_wire_reference import *

def fail(fn, *args):
    try: fn(*args)
    except ValueError: return
    raise AssertionError('malformed input accepted')

def main():
    # ordinary and binary round trips, including every byte value
    for payload in (b'MASIVP1', bytes(range(256)), bytes.fromhex('00FFC100')):
        f=Frame(0x0102030405060708, 0x1112131415161718, 7, 3, payload=payload)
        assert decode(encode(f)) == f
    fail(decode, b'ALCH')
    b=bytearray(encode(Frame(op=3))); b[0:4]=b'NOPE'; fail(decode, bytes(b))
    b=bytearray(encode(Frame(op=3))); b[4]=2; fail(decode, bytes(b))
    b=bytearray(encode(Frame(op=3))); b[8:12]=(32769).to_bytes(4,'big'); fail(decode, bytes(b))
    assert len(encode(Frame(op=3,payload=b'x'*(MAX_FRAME-HLEN)))) == MAX_FRAME
    print('MAS dev3-pre1 wire reference: PASS')
if __name__ == '__main__': main()
