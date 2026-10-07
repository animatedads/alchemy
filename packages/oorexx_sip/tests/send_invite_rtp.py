import socket,sys,re,time,struct
sip_port=int(sys.argv[1])  # target SIP UDP port
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('127.0.0.1',0)); s.settimeout(2)
call='media-test@localhost'
branch='z9hG4bKmedia1'
local=s.getsockname()[1]
sdp='v=0\r\no=test 1 1 IN IP4 127.0.0.1\r\ns=test\r\nc=IN IP4 127.0.0.1\r\nt=0 0\r\nm=audio 40000 RTP/AVP 0 8\r\na=rtpmap:0 PCMU/8000\r\n'
msg=(f'INVITE sip:oorexx@127.0.0.1 SIP/2.0\r\nVia: SIP/2.0/UDP 127.0.0.1:{local};branch={branch}\r\nMax-Forwards: 70\r\nTo: <sip:oorexx@127.0.0.1>\r\nFrom: <sip:test@127.0.0.1>;tag=abc\r\nCall-ID: {call}\r\nCSeq: 1 INVITE\r\nContact: <sip:test@127.0.0.1:{local}>\r\nContent-Type: application/sdp\r\nContent-Length: {len(sdp)}\r\n\r\n{sdp}').encode()
s.sendto(msg,('127.0.0.1',sip_port))
resp=[]
for _ in range(2):
    data,_=s.recvfrom(65535); resp.append(data.decode('latin1'))
ok=next(x for x in resp if x.startswith('SIP/2.0 200'))
m=re.search(r'(?m)^m=audio (\d+) RTP/AVP (\d+)\r?$',ok); assert m,ok
rtp_port=int(m.group(1)); pt=int(m.group(2)); assert pt==0
r=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
# 160 samples of PCMU 0xff -> near zero PCM
packet=struct.pack('!BBHII',0x80,pt,1,160,0x12345678)+bytes([0xff])*160
r.sendto(packet,('127.0.0.1',rtp_port))
print('200',rtp_port,pt)
