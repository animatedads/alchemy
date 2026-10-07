import socket,sys
s=socket.create_connection(("127.0.0.1",25252),5)
f=s.makefile("rwb",buffering=0)
def recv():
    return f.readline().decode("ascii","replace").rstrip("\r\n")
def send(x):
    f.write((x+"\r\n").encode())
assert recv().startswith("220 ")
send("EHLO test")
lines=[]
while True:
    x=recv(); lines.append(x)
    if x.startswith("250 "): break
assert any("SIZE" in x for x in lines)
send("AUTH PLAIN AGEsaWNlAHNlY3JldA=="); assert recv().startswith("538")
send("MAIL FROM:<outside@example.net>"); assert recv().startswith("250")
send("RCPT TO:<local@example.org>"); assert recv().startswith("250")
send("DATA"); assert recv().startswith("354")
send("Subject: fixture"); send(""); send("hello"); send(".")
assert recv().startswith("250")
send("QUIT"); assert recv().startswith("221")
s.close(); print("wire smoke PASS")
